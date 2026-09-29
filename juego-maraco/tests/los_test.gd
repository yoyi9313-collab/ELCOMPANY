extends SceneTree
const LOS = preload("res://scripts/line_of_sight.gd")
const Terrain = preload("res://scripts/terrain_rules.gd")
const AI = preload("res://scripts/enemy_ai.gd")
var failures := 0
var reaction_cells: Array[Vector2i] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func place(game, squad, cell: Vector2i) -> void:
	squad.cell = cell
	squad.position = game.project_cell(cell)

func run_checks() -> void:
	var a := Vector2i(1, 1)
	var b := Vector2i(5, 1)
	check(LOS.is_clear(a, b, {}), "Empty horizontal lane is clear")
	check(not LOS.is_clear(a, b, {Vector2i(3, 1): "crate"}), "Intermediate crate blocks LOS")
	check(LOS.is_clear(a, b, {Vector2i(3, 1): "sandbags"}), "Sandbags never fully block LOS")
	check(LOS.is_clear(a, b, {Vector2i(3, 2): "crate"}), "Crate away from ray does not block")
	check(not LOS.is_clear(Vector2i(1, 1), Vector2i(1, 5), {Vector2i(1, 3): "crate"}), "Vertical ray checks all traversed tiles")
	check(not LOS.is_clear(Vector2i(0, 0), Vector2i(3, 3), {Vector2i(1, 0): "crate"}), "Supercover prevents shooting through blocked diagonal corners")
	check(LOS.is_clear(a, a, {}), "Same-tile trace terminates")
	var wall := {"kind": "future_wall", "blocks_los": true, "blocks_movement": true, "provides_cover": false, "cover_strength": 0}
	check(not LOS.is_clear(a, b, {Vector2i(3, 1): wall}), "Custom terrain can block LOS without providing cover")
	check(not AI.has_cover(Vector2i(3, 2), {Vector2i(3, 1): wall}), "Cover uses provides_cover property independently")
	check(Terrain.cover_name(Vector2i(3, 2), {Vector2i(3, 1): Terrain.properties("sandbags")}) == "HEAVY", "Reusable terrain reports heavy cover")
	for x in 7:
		for y in 7:
			var target := Vector2i(x, y)
			var obstacles := {Vector2i(3, 2): "crate", Vector2i(2, 3): "sandbags"}
			check(LOS.is_clear(a, target, obstacles) == LOS.is_clear(target, a, obstacles), "LOS is reciprocal in all octants")
	var game = load("res://scenes/battlefield.tscn").instantiate()
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.ai_delay_scale = 0.01
	game.cover.clear()
	place(game, game.rangers, Vector2i(2, 1))
	place(game, game.enemy, Vector2i(5, 1))
	game.rangers.face_cell(game.enemy.cell)
	game.enemy.face_cell(game.rangers.cell)
	game.select_squad(game.rangers)
	game.target_hostile(game.enemy, true)
	game.cover[Vector2i(3, 1)] = Terrain.properties("crate")
	game.refresh_hud()
	check(game.attack_block_reason() == "NO LINE OF SIGHT" and game.fire_button.disabled, "Blocked target reports NO LINE OF SIGHT and disables FIRE")
	check(game.target_arc_label.text == "ARC: FRONT" and game.target_los_label.text == "LOS: BLOCKED", "Target panel separately reports arc and LOS")
	var rng_before: int = game.combat_rng.state
	game.attack_enemy()
	check(game.rangers.action_points == 2 and game.enemy.health == 400 and game.combat_rng.state == rng_before, "Blocked fire spends neither AP nor hit rolls")
	game.resolve_squad_attack(game.rangers, game.enemy, 100, 100, 100)
	check(game.enemy.health == 400 and game.enemy.suppression == 0, "Shared resolver rejects blocked shots")
	game.activate_overwatch()
	check(not await game.try_overwatch(game.rangers, game.enemy) and game.rangers.overwatch_active, "Blocked LOS preserves unused Overwatch")
	game.cover[Vector2i(3, 1)] = Terrain.properties("sandbags")
	check(await game.try_overwatch(game.rangers, game.enemy), "Replacing crate with sandbags permits Overwatch")
	game.rangers.begin_turn()
	game.refresh_hud()
	check(game.target_los_label.text == "LOS: CLEAR", "LOS UI updates with terrain change")
	game.cover.clear()
	place(game, game.enemy, Vector2i(5, 1))
	place(game, game.rangers, Vector2i(2, 1))
	place(game, game.rifle, Vector2i(5, 3))
	place(game, game.machine_gun, Vector2i(0, 9))
	game.cover[Vector2i(3, 1)] = "crate"
	check(game.enemy_target(game.enemy) == game.rifle and not game.has_ai_shot(game.enemy, game.rangers), "Infantry AI prefers a visible valid target over a blocked one")
	var obstacles := {Vector2i(3, 1): "crate", Vector2i(4, 3): "sandbags"}
	var route := AI.plan(Vector2i(5, 1), Vector2i(2, 1), 4, 10, obstacles)
	check(not route.is_empty() and LOS.is_clear(route[-1], Vector2i(2, 1), obstacles) and AI.distance(route[-1], Vector2i(2, 1)) <= 3, "AI repositions into range and clear LOS instead of firing through cover")
	check(route == AI.plan(Vector2i(5, 1), Vector2i(2, 1), 4, 10, obstacles), "LOS-aware AI route is deterministic")
	# A moving squad is first hidden, then crosses a visible tile within the arc.
	game.reset_demo()
	game.cover.clear()
	game.enemy.health = 0
	place(game, game.mg42, Vector2i(5, 1))
	place(game, game.rangers, Vector2i(1, 1))
	game.cover[Vector2i(3, 1)] = "crate"
	game.mg42.face_cell(Vector2i(1, 2))
	game.mg42.spend_action("overwatch")
	check(not await game.try_overwatch(game.mg42, game.rangers) and game.mg42.overwatch_active, "Enemy watch holds while mover is hidden")
	game.overwatch_triggered.connect(func(_watcher, target): reaction_cells.append(target.cell))
	game.select_squad(game.rangers)
	await game.move_to(Vector2i(3, 2))
	check(reaction_cells.size() == 1 and reaction_cells[0] == Vector2i(3, 2), "Reaction checks LOS at each entered tile and fires at first visible tile")
	check(LOS.is_clear(game.mg42.cell, reaction_cells[0], game.cover), "Reaction tile has actual clear LOS")
	var event := InputEventKey.new()
	event.keycode = KEY_F3
	event.pressed = true
	game._unhandled_input(event)
	check(game.show_los_debug, "F3 enables optional LOS debugging")
	game._unhandled_input(event)
	check(not game.show_los_debug, "F3 disables LOS debugging")
	game.queue_free()
	await process_frame
	print("LOS CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
