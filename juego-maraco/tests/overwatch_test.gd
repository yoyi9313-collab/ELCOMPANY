extends SceneTree
const Squad = preload("res://scripts/squad_data.gd")
var failures := 0
var reactions := 0
var reaction_tile := Vector2i(-1, -1)
var reaction_ap := -1
var reaction_hp := -1

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func prepare(game, player_cell: Vector2i, enemy_cell: Vector2i) -> void:
	game.reset_demo()
	game.cover.clear()
	game.rangers.overwatch_range = 3
	game.rangers.max_attacks_per_turn = 1
	game.squad_cell = player_cell
	game.squad_position = game.project_cell(player_cell)
	game.enemy.cell = enemy_cell
	game.enemy.position = game.project_cell(enemy_cell)
	game.rangers.face_cell(game.enemy.cell)
	game.enemy.face_cell(game.rangers.cell)
	game.selected = true
	game.rebuild_range()
	reactions = 0
	for candidate in 100:
		game.combat_rng.seed = candidate
		if game.combat_rng.randf_range(0.0, 100.0) <= 45:
			game.combat_rng.seed = candidate
			break

func run_checks() -> void:
	var squad := Squad.new()
	check(squad.spend_action("overwatch") and squad.action_points == 1 and squad.overwatch_active, "Activation costs one AP")
	check(not squad.spend_action("overwatch") and not squad.spend_action("fire"), "Cannot double-activate or use the reserved shot for normal fire")
	check(squad.spend_action("move") and squad.action_points == 0, "Overwatch does not consume the second AP")
	check(squad.consume_overwatch_shot() and squad.action_points == 0, "Reaction uses prepaid AP")
	check(not squad.consume_overwatch_shot() and not squad.overwatch_active, "Reaction fires once then removes state")
	squad.begin_turn()
	squad.spend_action("fire")
	check(not squad.spend_action("overwatch") and squad.action_points == 1, "Current one-attack limit blocks FIRE + OVERWATCH")
	squad.begin_turn()
	squad.max_attacks_per_turn = 2
	check(squad.spend_action("fire") and squad.spend_action("overwatch") and squad.consume_overwatch_shot(), "Future two-attack profile permits FIRE + OVERWATCH")
	squad.begin_turn()
	squad.spend_action("move")
	squad.spend_action("move")
	check(not squad.spend_action("overwatch"), "Zero AP cannot activate")
	squad.begin_turn()
	squad.spend_action("overwatch")
	squad.begin_turn()
	check(not squad.overwatch_active and not squad.overwatch_fired, "Unused overwatch expires at own turn start")
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.ai_delay_scale = 0.02
	game.overwatch_triggered.connect(func(watcher, target):
		reactions += 1
		reaction_tile = target.cell
		reaction_ap = watcher.action_points
		reaction_hp = target.health
	)
	prepare(game, Vector2i(1, 1), Vector2i(6, 1))
	check(game.shot_chance(game.rangers, game.enemy, 85 - game.rangers.overwatch_accuracy_penalty) == 70, "Open overwatch accuracy is 70 percent")
	game.cover[Vector2i(6, 0)] = "crate"
	check(game.shot_chance(game.rangers, game.enemy, 70) == 45, "Covered overwatch accuracy is 45 percent")
	game.rangers.apply_suppression()
	game.rangers.apply_suppression()
	check(game.shot_chance(game.rangers, game.enemy, 70) == 30, "Suppression penalty stacks on overwatch and cover")
	prepare(game, Vector2i(1, 1), Vector2i(6, 1))
	game.cover[Vector2i(3, 2)] = "sandbags"
	await game.move_to(Vector2i(1, 0))
	game.face_selected(game.enemy.cell)
	game.activate_overwatch()
	check(game.rangers.action_points == 0 and game.rangers.overwatch_active, "MOVE + OVERWATCH uses two AP")
	await game.next_turn()
	check(reactions == 1 and reaction_ap == 0, "Enemy movement triggers one prepaid reaction even with zero AP")
	check(reaction_hp < 400 and reaction_hp >= 290, "Overwatch uses normal squad damage variance")
	check(not game.rangers.overwatch_active and game.rangers.action_points == 2, "Reaction and turn reset restore clean player state")
	# A cover destination lies beyond the first tile entering range.
	prepare(game, Vector2i(1, 1), Vector2i(6, 1))
	game.cover[Vector2i(3, 2)] = "sandbags"
	game.activate_overwatch()
	await game.next_turn()
	check(reactions == 1 and reaction_tile == Vector2i(4, 1), "Reaction occurs on first entered tile in range, before the final destination")
	check(game.enemy.cell == Vector2i(3, 1), "Surviving enemy resumes its interrupted route")
	prepare(game, Vector2i(1, 1), Vector2i(6, 1))
	game.enemy.health = 10
	game.activate_overwatch()
	await game.next_turn()
	check(reactions == 1 and game.enemy.health == 0 and not game.enemy_attack_used, "Lethal reaction cancels remaining movement and attack")
	check(game.enemy.cell == reaction_tile and game.enemy.position == game.project_cell(reaction_tile), "Killed squad does not teleport to its route destination")
	prepare(game, Vector2i(1, 1), Vector2i(3, 1))
	game.activate_overwatch()
	await game.next_turn()
	check(reactions == 0 and not game.rangers.overwatch_active, "Stationary enemy shooting does not trigger movement overwatch; state expires")
	prepare(game, Vector2i(0, 0), Vector2i(9, 9))
	game.activate_overwatch()
	await game.next_turn()
	check(reactions == 0, "Movement outside range does not trigger")
	prepare(game, Vector2i(1, 1), Vector2i(6, 1))
	for candidate in 100:
		game.combat_rng.seed = candidate
		if game.combat_rng.randf_range(0.0, 100.0) > 70:
			game.combat_rng.seed = candidate
			break
	game.activate_overwatch()
	await game.next_turn()
	check(reactions == 1 and reaction_hp == 400, "A missed reaction still consumes the single overwatch shot")
	prepare(game, Vector2i(1, 1), Vector2i(8, 1))
	game.rangers.overwatch_range = 6
	game.activate_overwatch()
	await game.next_turn()
	check(reactions == 1 and reaction_tile == Vector2i(7, 1), "Reusable profile supports wider reaction range")
	game.reset_demo()
	check(not game.rangers.overwatch_active and not game.enemy.overwatch_active, "Reset clears both squads' overwatch")
	print("OVERWATCH CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
