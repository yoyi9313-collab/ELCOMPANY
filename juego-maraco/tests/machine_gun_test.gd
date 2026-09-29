extends SceneTree
const Profiles = preload("res://scripts/squad_profiles.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func roll_for(game, hit: bool, chance: float) -> void:
	for seed_value in 1000:
		game.combat_rng.seed = seed_value
		if (game.combat_rng.randf_range(0, 100) < chance) == hit:
			game.combat_rng.seed = seed_value
			return

func run_checks() -> void:
	var unit = Profiles.machine_gun_team()
	check(unit.health == 320 and unit.members.size() == 3 and unit.movement == 2, "MG base profile")
	check(unit.is_deployed() and unit.effective_attack_range() == 6 and unit.effective_overwatch_range() == 6, "Stationary range bonus applies to fire and Overwatch")
	check(not unit.can_perform("grenade") and unit.grenades_remaining == 0, "MG cannot use grenades")
	for sample in [[320, 3], [214, 3], [213, 2], [107, 2], [106, 1], [1, 1], [0, 0]]:
		unit.health = sample[0]
		check(unit.living_members().size() == sample[1], "MG casualty threshold %d" % sample[0])
	unit.restore()
	unit.cell = Vector2i(4, 4)
	unit.face_direction(Vector2.RIGHT)
	check(unit.incoming_damage(100, Vector2i(6, 4)) == 100, "Frontal damage unchanged")
	check(unit.incoming_damage(100, Vector2i(4, 6)) == 110, "Flank damage plus ten percent")
	check(unit.incoming_damage(100, Vector2i(2, 4)) == 120, "Rear damage plus twenty percent")
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.ai_delay_scale = 0.01
	game.cover.clear()
	var mg = game.machine_gun
	mg.cell = Vector2i(2, 1)
	mg.position = game.project_cell(mg.cell)
	game.enemy.cell = Vector2i(8, 1)
	game.enemy.position = game.project_cell(game.enemy.cell)
	mg.face_cell(game.enemy.cell)
	game.enemy.face_cell(mg.cell)
	game.select_squad(mg)
	check(not game.grenade_button.visible and not game.grenade_status_label.visible and game.unit_label.text == "SUPPORT / 3 MEN · DEPLOYED", "MG selection hides grenade UI and displays deployed support role")
	check(game.attack_block_reason().is_empty() and game.target_hit_chance() == 85, "Deployed attack at range six has 85 percent accuracy")
	game.cover[Vector2i(8, 0)] = "crate"
	check(game.target_hit_chance() == 60, "Deployed bonus stacks with cover")
	game.cover.clear()
	game.move_to(Vector2i(9, 9))
	check(mg.is_deployed(), "Invalid move does not remove deployed bonus")
	await game.move_to(Vector2i(3, 1))
	check(mg.moved_this_turn and mg.effective_attack_range() == 5 and game.target_hit_chance() == 75, "Valid movement removes range and accuracy bonuses")
	check(mg.action_points == 1 and game.rangers.action_points == 2 and game.rifle.action_points == 2, "MG movement AP independent of both other squads")
	check(game.unit_label.text.ends_with("MOVED"), "UI reports moved state")
	game.enemy.cell = Vector2i(9, 1)
	check(game.attack_block_reason() == "OUT OF RANGE", "Moving makes a six-tile target invalid")
	game.enemy.cell = Vector2i(8, 1)
	check(game.shot_chance(mg, game.enemy, 70) == 70, "Moved Overwatch loses deployment bonus")
	game.rotate_selected(45)
	check(not mg.is_deployed(), "Free facing does not restore deployment")
	game.face_selected(game.enemy.cell)
	roll_for(game, true, 75)
	game.attack_enemy()
	check(game.enemy.health >= 325 and game.enemy.health <= 345 and game.enemy.suppression == 2, "Normal MG hit deals 55 to 75 and two suppression")
	await create_timer(0.6).timeout
	mg.begin_turn()
	game.enemy.restore()
	check(mg.is_deployed() and mg.action_points == 2, "Turn reset restores deployment and AP")
	roll_for(game, false, 85)
	game.attack_enemy()
	check(game.enemy.health == 400 and game.enemy.suppression == 1 and game.last_result == "MISS", "Normal miss suppresses without damage")
	await create_timer(0.6).timeout
	for hit in [true, false]:
		mg.begin_turn()
		game.enemy.restore()
		game.activate_overwatch()
		check(game.shot_chance(mg, game.enemy, mg.base_hit_chance - mg.overwatch_accuracy_penalty) == 80, "Deployed Overwatch uses only five-point penalty")
		roll_for(game, hit, 80)
		check(await game.try_overwatch(mg, game.enemy), "Enhanced Overwatch triggers")
		check(game.enemy.suppression == (2 if hit else 1), "Overwatch hit/miss suppression")
		check(not mg.overwatch_active and mg.attacks_this_turn == 1 and mg.action_points == 1, "Overwatch remains one prepaid attack")
	mg.begin_turn()
	mg.apply_suppression(2)
	check(game.shot_chance(mg, game.enemy, 70) == 55 and not mg.can_perform("overwatch"), "Pinned removes deployment bonus, applies accuracy penalty and blocks Overwatch")
	mg.begin_turn()
	game.enemy.restore()
	game.enemy.cell = Vector2i(9, 2)
	game.resolve_squad_attack(mg, game.enemy, 75, 55, 75)
	check(game.enemy.suppression == 0 and game.enemy.health == 400, "Out-of-range miss never suppresses")
	game.enemy.health = 0
	mg.spend_action("move")
	game.rangers.spend_action("move")
	game.rifle.spend_action("move")
	await game.next_turn()
	check(mg.is_pinned() and not mg.is_deployed() and mg.action_points == 2 and game.rangers.action_points == 2 and game.rifle.action_points == 2, "Allied phase resets AP for all squads while pinning still blocks deployment")
	game.reset_demo()
	check(mg.cell == game.MG_START and mg.health == 320 and mg.grenades_remaining == 0, "Battle reset restores MG without granting grenades")
	game.cover.clear()
	mg.cell = Vector2i(4, 4)
	mg.face_direction(Vector2.RIGHT)
	game.enemy.cell = Vector2i(4, 6)
	game.enemy.face_cell(mg.cell)
	game.resolve_squad_attack(game.enemy, mg, 100, 100, 100)
	check(mg.health == 210, "Shared combat resolver applies MG flank vulnerability")
	mg.restore()
	game.enemy.cell = Vector2i(2, 4)
	game.enemy.face_cell(mg.cell)
	game.resolve_squad_attack(game.enemy, mg, 100, 100, 100)
	check(mg.health == 200, "Shared combat resolver applies MG rear vulnerability")
	game.queue_free()
	await process_frame
	print("MACHINE GUN CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
