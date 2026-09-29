extends SceneTree
const Squad = preload("res://scripts/squad_data.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func setup(game, player_cell: Vector2i, enemy_cell: Vector2i) -> void:
	game.reset_demo()
	# Isolate this AP-budget scenario; multi_squad covers all Allied targets.
	game.rifle.health = 0
	game.machine_gun.health = 0
	game.cover.clear()
	game.squad_cell = player_cell
	game.squad_position = game.project_cell(player_cell)
	game.enemy.cell = enemy_cell
	game.enemy.position = game.project_cell(enemy_cell)
	game.rangers.face_cell(game.enemy.cell)
	game.enemy.face_cell(game.rangers.cell)
	game.selected = true
	game.rebuild_range()

func run_checks() -> void:
	var squad := Squad.new()
	check(squad.action_points == 2 and squad.movement == 4, "Squad starts with 2 AP and four tiles per move")
	check(not squad.spend_action("unknown") and squad.action_points == 2, "Unknown action cannot spend AP")
	squad.action_costs["future_action"] = 1
	check(squad.spend_action("future_action") and squad.action_points == 1, "Reusable action ledger accepts future action costs")
	squad.begin_turn()
	check(squad.spend_action("fire") and not squad.spend_action("fire") and squad.action_points == 1, "One attack per turn leaves AP available for movement")
	squad.begin_turn()
	squad.max_attacks_per_turn = 2
	check(squad.spend_action("fire") and squad.spend_action("fire") and squad.action_points == 0, "Future weapon profile can allow two attacks without bypassing AP")
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.ai_delay_scale = 0.02
	setup(game, Vector2i(0, 0), Vector2i(9, 9))
	game.move_to(Vector2i(0, 0))
	game.move_to(Vector2i(5, 0))
	check(game.rangers.action_points == 2 and not game.moving, "Zero-length and out-of-range moves cost no AP")
	await game.move_to(Vector2i(4, 0))
	check(game.rangers.action_points == 1 and game.squad_cell == Vector2i(4, 0), "Four-tile move costs one AP")
	await game.move_to(Vector2i(8, 0))
	check(game.rangers.action_points == 0 and game.squad_cell == Vector2i(8, 0), "Second move has a fresh four-tile allowance")
	game.move_to(Vector2i(9, 0))
	check(not game.moving and game.reachable.size() == 1, "Zero AP blocks further movement and clears range")
	game.refresh_hud()
	check(game.moves_label.text.contains("○ ○"), "UI displays two spent AP")
	setup(game, Vector2i(4, 1), Vector2i(8, 1))
	await game.move_to(Vector2i(6, 1))
	game.attack_enemy()
	check(game.rangers.action_points == 0 and game.attack_used and game.volley_left > 0.0, "Move then fire spends both AP")
	await create_timer(0.65).timeout
	setup(game, Vector2i(6, 2), Vector2i(8, 1))
	game.attack_enemy()
	check(game.rangers.action_points == 1, "Fire costs one AP")
	await create_timer(0.65).timeout
	var health_after_shot: int = game.enemy.health
	game.attack_enemy()
	check(game.rangers.action_points == 1 and game.enemy.health == health_after_shot, "Second attack rejected without spending remaining AP")
	await game.move_to(Vector2i(6, 1))
	check(game.rangers.action_points == 0 and game.squad_cell == Vector2i(6, 1), "Fire then move is permitted")
	setup(game, Vector2i(0, 0), Vector2i(9, 9))
	game.rangers.apply_suppression()
	check(game.rangers.action_points == 2 and game.rangers.effective_movement() == 3 and not game.reachable.has(Vector2i(4, 0)), "One suppression reduces move allowance without consuming AP")
	game.rangers.apply_suppression()
	check(game.rangers.effective_movement() == 2, "Two suppression points limit each move to two tiles")
	await game.move_to(Vector2i(2, 0))
	await game.move_to(Vector2i(4, 0))
	check(game.rangers.action_points == 0 and game.squad_cell == Vector2i(4, 0), "Suppressed squad can still make two shortened moves")
	setup(game, Vector2i(0, 0), Vector2i(9, 9))
	await game.next_turn()
	check(game.rangers.action_points == 2 and game.turn_number == 2, "Ending early forfeits unused actions and next player turn starts with two AP")
	check(game.enemy.action_points == 0 and not game.enemy_attack_used, "Distant AI spends two move actions")
	setup(game, Vector2i(3, 1), Vector2i(8, 1))
	await game.next_turn()
	check(game.enemy.action_points == 0 and game.enemy_attack_used, "AI move plus fire respects the two-AP budget")
	setup(game, Vector2i(0, 0), Vector2i(9, 0))
	await game.next_turn()
	check(game.enemy.action_points == 0 and not game.enemy_attack_used and game.target_distance() == 3, "AI cannot fire after using both AP to reach range")
	game.reset_demo()
	check(game.rangers.action_points == 2 and game.enemy.action_points == 2 and not game.attack_used, "Reset restores AP and attack limit")
	print("ACTION POINT CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
