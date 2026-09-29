extends SceneTree
const AI = preload("res://scripts/enemy_ai.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func setup(game, enemy_cell: Vector2i, player_cell: Vector2i) -> void:
	game.reset_demo()
	game.cover.clear()
	game.enemy.cell = enemy_cell
	game.enemy.position = game.project_cell(enemy_cell)
	game.rangers.cell = player_cell
	game.rangers.position = game.project_cell(player_cell)
	game.rangers.face_cell(game.enemy.cell)
	game.enemy.face_cell(game.rangers.cell)
	game.selected = true
	game.rebuild_range()
	for candidate in 100:
		game.combat_rng.seed = candidate
		if game.combat_rng.randf_range(0.0, 100.0) <= 55:
			game.combat_rng.seed = candidate
			break

func finish_enemy_turn(game) -> void:
	var frames := 0
	while game.enemy_turn and frames < 1000:
		frames += 1
		await process_frame
	check(not game.enemy_turn, "Enemy turn finishes without hanging")

func run_checks() -> void:
	var cover := {Vector2i(5, 0): "crate", Vector2i(3, 2): "sandbags"}
	var start := Vector2i(8, 1)
	var target := Vector2i(1, 1)
	var route := AI.plan(start, target, 5, 10, cover)
	check(not route.is_empty() and route.size() <= 5, "AI returns a reachable route within budget")
	check(AI.has_cover(route[-1], cover), "AI prefers useful cover")
	check(AI.distance(route[-1], target) <= 3, "Closer firing cover wins over distant cover")
	check(route == AI.plan(start, target, 5, 10, cover), "Planning is deterministic")
	var previous := start
	for cell in route:
		check(AI.distance(previous, cell) == 1 and not cover.has(cell) and cell != target, "Path avoids cover and occupied Ranger tile")
		previous = cell
	var empty_route := AI.plan(Vector2i(8, 1), Vector2i(3, 1), 5, 10, {})
	check(empty_route.size() == 2, "No-cover fallback takes shortest approach into attack range")
	var trapped := {Vector2i(7, 1): "crate", Vector2i(9, 1): "crate", Vector2i(8, 0): "crate", Vector2i(8, 2): "crate"}
	check(AI.plan(Vector2i(8, 1), Vector2i(3, 7), 5, 10, trapped).is_empty(), "Blocked squad safely stays put")
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.ai_delay_scale = 0.02
	setup(game, Vector2i(8, 1), Vector2i(6, 1))
	check(game.shot_chance(game.enemy, game.rangers, 80) == 80, "Enemy exposed hit chance is 80 percent")
	game.cover[Vector2i(6, 0)] = "crate"
	check(game.shot_chance(game.enemy, game.rangers, 80) == 55, "Enemy cover hit chance is 55 percent")
	game.enemy.apply_suppression()
	game.enemy.apply_suppression()
	game.next_turn()
	check(game.enemy_turn and game.enemy.suppression == 2 and game.turn_label.text == "ENEMY TURN", "Enemy turn locks controls and retains own suppression")
	check(game.end_button.disabled and game.reset_button.disabled and game.fire_button.disabled, "Player buttons disabled during enemy turn")
	game.next_turn()
	game.move_to(Vector2i(5, 1))
	game.attack_enemy()
	game.reset_demo()
	check(not game.moving and game.enemy.health == 400 and game.enemy_turn, "Direct player commands cannot interrupt AI turn")
	await finish_enemy_turn(game)
	check(game.enemy.cell == Vector2i(8, 1) and game.enemy_attack_used, "Already-in-range enemy shoots without moving")
	check(game.rangers.health >= 300 and game.rangers.health <= 330, "Enemy hit deals 70–100 total damage")
	check(game.rangers.suppression == 1 and game.rangers.action_points == 2 and not game.attack_used and game.turn_number == 2, "Next player turn restores actions and retains received suppression")
	check(game.combat_target == game.rangers and game.firing_squad == game.enemy, "Enemy volley targets Rangers with shared visual effects")
	setup(game, Vector2i(8, 1), Vector2i(3, 1))
	await game.next_turn()
	check(game.enemy.cell != Vector2i(8, 1) and game.enemy.action_points == 0, "Enemy spends movement following shortest approach")
	check(game.enemy_attack_used and game.rangers.health < 400, "Enemy attacks after entering range")
	game.reset_demo()
	check(game.enemy.cell == Vector2i(8, 1), "Reset restores enemy position after AI movement")
	setup(game, Vector2i(8, 1), Vector2i(3, 7))
	game.cover = trapped
	await game.next_turn()
	check(not game.enemy_attack_used and game.rangers.health == 400 and not game.enemy_turn, "Blocked enemy passes without damage or deadlock")
	setup(game, Vector2i(8, 1), Vector2i(6, 1))
	game.enemy.health = 0
	await game.next_turn()
	check(game.rangers.health == 400 and not game.enemy_attack_used, "Destroyed enemy cannot act")
	setup(game, Vector2i(8, 1), Vector2i(6, 1))
	game.rangers.health = 10
	await game.next_turn()
	check(game.rangers.health == 0 and not game.enemy_turn and not game.end_button.disabled and not game.reset_button.disabled, "Lethal attack on Rangers leaves Allied phase playable with Rifle Squad")
	game.rifle.health = 0
	game.machine_gun.health = 0
	game.refresh_hud()
	check(game.end_button.disabled and not game.reset_button.disabled, "All Allied squads eliminated ends safely and allows reset")
	print("ENEMY AI CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
