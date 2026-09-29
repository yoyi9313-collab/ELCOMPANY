extends SceneTree
const AI = preload("res://scripts/enemy_ai.gd")
var failures := 0
var reactions := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func place(game, squad, cell: Vector2i) -> void:
	squad.cell = cell
	squad.position = game.project_cell(cell)

func setup(game) -> void:
	game.reset_demo()
	game.cover.clear()
	game.enemy.health = 0
	place(game, game.mg42, Vector2i(8, 1))
	place(game, game.rangers, Vector2i(4, 1))
	place(game, game.rifle, Vector2i(0, 8))
	place(game, game.machine_gun, Vector2i(0, 9))
	game.mg42.face_cell(game.rangers.cell)
	game.rangers.face_cell(game.mg42.cell)
	game.rebuild_range()

func roll_for(game, hit: bool, chance: float) -> void:
	for value in 1000:
		game.combat_rng.seed = value
		if (game.combat_rng.randf_range(0, 100) < chance) == hit:
			game.combat_rng.seed = value
			return

func run_checks() -> void:
	var game = load("res://scenes/battlefield.tscn").instantiate()
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.ai_delay_scale = 0.01
	var mg = game.mg42
	check(game.enemies.size() == 2 and mg.get_script() == game.enemy.get_script(), "Two enemies reuse shared squad architecture")
	check(game.squad_in_cover(mg) and AI.distance(mg.cell, game.enemy.cell) > 1 and not game.cover.has(mg.cell), "MG42 starts in defensive cover apart from Grenadiers")
	check(mg.health == 300 and mg.members.size() == 3 and mg.movement == 2 and mg.base_hit_chance == 80, "MG42 requested profile")
	check(not mg.player_controlled and not mg.can_perform("grenade"), "MG42 is hostile and has no grenade")
	setup(game)
	check(mg.is_deployed() and mg.effective_attack_range() == 6 and game.shot_chance(mg, game.rangers, 80) == 90, "Deployment grants range six and 90 percent accuracy")
	mg.spend_action("move")
	check(mg.effective_attack_range() == 5 and game.shot_chance(mg, game.rangers, 80) == 80, "Moving removes setup bonuses")
	mg.begin_turn()
	mg.apply_suppression(2)
	check(not mg.is_deployed() and not mg.can_perform("overwatch"), "PINNED cancels MG42 bonuses and Overwatch")
	mg.begin_turn()
	game.select_squad(game.rifle)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = mg.position
	game._unhandled_input(click)
	check(game.active_squad == game.rifle, "Clicking MG42 targets it without granting player control")
	check(game.target_enemy == mg and game.enemy_name_label.text.contains("MG42 TEAM") and game.enemy_info_label.text.contains("300/300") and game.target_name_label.text == "TARGET: MG42 TEAM", "Target panel switches to MG42 stats")
	game.select_squad(game.rangers)
	place(game, game.rangers, Vector2i(6, 1))
	game.rangers.face_cell(mg.cell)
	game.target_hostile(mg, true)
	check(not game.reachable.has(mg.cell) and game.enemy_occupies(mg.cell), "MG42 logical tile blocks Allied movement")
	roll_for(game, true, 85)
	game.attack_enemy()
	check(mg.health < 300 and game.enemy.health == 0, "Normal fire hits selected enemy rather than Grenadier singleton")
	await create_timer(0.65).timeout
	setup(game)
	place(game, game.rifle, Vector2i(3, 1))
	game.cover[Vector2i(4, 0)] = "crate"
	check(game.enemy_target(mg) == game.rifle, "Exposed squad preferred over closer covered squad")
	game.cover.clear()
	game.rangers.apply_suppression(1)
	check(game.enemy_target(mg) == game.rifle, "Lower suppression breaks equal-exposure priority")
	game.rangers.restore()
	check(game.enemy_target(mg) == game.rangers, "Closest target breaks equal exposure and suppression")
	game.cover[Vector2i(7, 1)] = "crate"
	check(not game.has_ai_shot(mg, game.rangers), "Support firing lane detects intermediate cover")
	game.cover.clear()
	game.cover[Vector2i(8, 0)] = "sandbags"
	var start: Vector2i = mg.cell
	roll_for(game, true, 90)
	game.enemy_turn = true
	await game.run_enemy_turn(mg)
	game.enemy_turn = false
	check(mg.cell == start and mg.is_deployed() and mg.attacks_this_turn == 1, "MG42 holds cover when a firing lane already exists")
	check(game.rangers.health >= 320 and game.rangers.health <= 340 and game.rangers.suppression == 2, "Normal hit deals 60–80 and pins")
	setup(game)
	roll_for(game, false, 90)
	game.enemy_turn = true
	await game.run_enemy_turn(mg)
	game.enemy_turn = false
	check(game.rangers.health == 400 and game.rangers.suppression == 1, "MG42 normal miss applies one suppression")
	setup(game)
	place(game, game.rangers, Vector2i(1, 1))
	game.cover[Vector2i(6, 0)] = "sandbags"
	game.enemy_turn = true
	await game.run_enemy_turn(mg)
	game.enemy_turn = false
	check(mg.cell == Vector2i(6, 1) and game.squad_in_cover(mg) and mg.moved_this_turn, "Out-of-range support moves to nearby useful firing cover")
	check(mg.attacks_this_turn == 1 and mg.action_points == 0, "Support can move then fire with two AP")
	setup(game)
	place(game, game.rangers, Vector2i(0, 1))
	place(game, game.rifle, Vector2i(0, 0))
	place(game, game.machine_gun, Vector2i(0, 9))
	game.cover[Vector2i(6, 0)] = "sandbags"
	game.enemy_turn = true
	await game.run_enemy_turn(mg)
	game.enemy_turn = false
	check(mg.moved_this_turn and mg.overwatch_active and mg.action_points == 0, "Support watches approach when no shot follows its move")
	game.overwatch_triggered.connect(func(watcher, _target):
		if watcher == mg:
			reactions += 1)
	for hit in [true, false]:
		setup(game)
		place(game, game.rangers, Vector2i(2, 1))
		game.select_squad(game.rangers)
		mg.face_cell(game.rangers.cell)
		mg.spend_action("overwatch")
		check(game.shot_chance(mg, game.rangers, 75) == 85, "MG42 deployed Overwatch uses five-point accuracy penalty")
		roll_for(game, hit, 85)
		var before := reactions
		await game.move_to(Vector2i(6, 1))
		check(reactions == before + 1 and not mg.overwatch_active and mg.attacks_this_turn == 1, "One reaction across all tiles in the movement event")
		check(game.rangers.suppression == (2 if hit else 1), "Enemy Overwatch hit/miss uses shared suppression")
		check(game.rangers.cell == (Vector2i(4, 1) if hit else Vector2i(5, 1)), "Suppression shortens remaining move without overlapping enemies")
	setup(game)
	game.enemy.restore()
	place(game, game.enemy, Vector2i(6, 3))
	mg.apply_suppression(2)
	game.enemy.apply_suppression(2)
	game.next_turn()
	check(mg.suppression == 2 and game.enemy.suppression == 2, "Enemy phase preserves suppression for both enemies together")
	while game.enemy_turn:
		await process_frame
	check(game.enemy.attacks_this_turn == 1 and mg.attacks_this_turn == 1 and not game.enemy_turn and game.turn_number == 2, "Both enemies act once before Allied phase begins")
	setup(game)
	game.rangers.health = 1
	game.select_squad(game.rangers)
	mg.spend_action("overwatch")
	roll_for(game, true, 85)
	await game.move_to(Vector2i(5, 1))
	check(game.rangers.health == 0 and not game.moving, "Lethal enemy reaction stops Allied route without hanging")
	setup(game)
	game.enemy.restore()
	place(game, game.enemy, mg.cell + Vector2i.DOWN)
	game.resolve_grenade(mg.cell)
	check(mg.health < 300 and mg.suppression == 2 and game.enemy.health < 400 and game.enemy.suppression == 1, "Shared grenade blast affects both enemy squads independently")
	game.reset_demo()
	check(mg.cell == game.MG42_START and mg.health == 300 and not mg.overwatch_active and game.enemies.size() == 2, "Battle reset restores both enemies")
	game.queue_free()
	await process_frame
	print("MG42 CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
