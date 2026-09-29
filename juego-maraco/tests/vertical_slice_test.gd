extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var game = load("res://scenes/battlefield.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.flow.stage == "INTRO" and game.presentation.intro.visible, "Fresh mission shows intro")
	game.select_squad(game.rangers)
	game.move_to(Vector2i(3, 6))
	game.attack_enemy()
	game.activate_overwatch()
	game.select_grenade()
	await game.next_turn()
	check(game.rangers.action_points == 2 and game.turn_number == 1 and not game.selected and not game.grenade_mode, "Intro blocks combat and turn advancement")
	game.begin_battle()
	check(game.flow.stage == "INTRO", "Cannot bypass deployment")
	var german_positions: Array = game.enemies.map(func(squad): return squad.cell)
	game.start_mission()
	check(game.flow.stage == "DEPLOYMENT" and game.presentation.deployment.visible and game.presentation.begin_button.disabled, "Start enters deployment before Turn 1")
	check(not game.place_deployment(game.rangers, game.rifle.cell), "Deployment prevents overlap, even with unconfirmed squad")
	check(not game.place_deployment(game.rangers, Vector2i(2, 8)), "Deployment rejects terrain")
	check(not game.place_deployment(game.rangers, Vector2i(6, 7)), "Deployment rejects outside zone")
	check(not game.place_deployment(game.enemy, Vector2i(0, 9)), "Germans cannot deploy")
	game.begin_battle()
	check(game.flow.stage == "DEPLOYMENT", "All three confirmations required")
	for squad in game.allies:
		game.select_squad(squad)
		check(game.place_deployment(squad, squad.cell), "Can confirm each legal deployment position")
	check(not game.presentation.begin_button.disabled, "Begin Battle enabled after all placements")
	check(game.place_deployment(game.rangers, Vector2i(3, 8)) and game.flow.placed.size() == 3, "Confirmed squad can be repositioned without duplicate counts")
	check(game.rangers.action_points == 2 and game.rangers.grenades_remaining == 1 and game.mission.capture_points == 0, "Deployment preserves resources and objective progress")
	check(game.enemies.map(func(squad): return squad.cell) == german_positions, "Deployment preserves German positions")
	game.begin_battle()
	check(game.combat_ready() and not game.presentation.deployment.visible and game.presentation.phase_label.text == "ALLIED PHASE", "Battle begins with Allied phase banner")
	game.rangers.action_points = 1
	game.begin_battle()
	check(game.rangers.action_points == 1, "Begin Battle cannot reset AP repeatedly")
	# Both existing approaches are traversable, have cover, and are not all
	# visible to the deployed MG42. No terrain rebalance is needed for this map.
	var west := [Vector2i(3, 7), Vector2i(3, 6), Vector2i(3, 5), Vector2i(4, 5)]
	var east := [Vector2i(5, 7), Vector2i(6, 7), Vector2i(6, 6), Vector2i(6, 5), Vector2i(5, 5)]
	for route in [west, east]:
		var has_cover := false
		for cell in route:
			check(not game.Terrain.blocks_movement(game.cover.get(cell)), "Both objective approaches remain open")
			has_cover = has_cover or game.Terrain.adjacent_cover(cell, game.cover) > 0
		check(has_cover, "Each route offers cover")
	check(not game.LOS.is_clear(game.mg42.cell, Vector2i(3, 7), game.cover), "Crates interrupt the MG's line of sight to the west approach")
	game.rangers.cell = game.Mission.ZONE[0]
	game.rangers.position = game.project_cell(game.rangers.cell)
	game.refresh_hud()
	check(game.presentation.notice_history.has("OBJECTIVE  ·  ALLIED CONTROL"), "Objective ownership creates notification")
	game.mission.end_allied_phase(1, game.allies, game.enemies)
	game.refresh_hud()
	check(game.presentation.notice_history.has("POSITION HELD  ·  CAPTURE 1 / 2"), "Capture progress creates notification")
	var notice_count: int = game.presentation.notice_history.size()
	game.refresh_hud()
	check(game.presentation.notice_history.size() == notice_count, "HUD refresh never duplicates notification")
	game.enemy.cell = game.Mission.ZONE[1]
	game.refresh_hud()
	check(game.presentation.notice_history.has("OBJECTIVE  ·  CONTESTED"), "Contested state creates notification")
	game.enemy.cell = german_positions[0]
	game.rangers.cell = Vector2i(3, 7)
	# Prevent actions without killing units so the full phase transition runs.
	game.cover.clear()
	for squad in game.enemies:
		for direction in game.DIRECTIONS: game.cover[squad.cell + direction] = "crate"
	game.ai_delay_scale = 0.01
	game.next_turn()
	check(game.enemy_turn and game.presentation.phase_label.text == "GERMAN PHASE" and game.end_button.disabled, "Enemy transition announces German phase and locks controls")
	while game.enemy_turn: await process_frame
	check(game.turn_number == 2 and game.presentation.phase_label.text == "ALLIED PHASE", "Enemy completion automatically announces next Allied phase")
	game.rangers.health = 0
	game.rifle.health = 260
	game.mg42.health = 0
	game.mission.finish("ALLIED", "Test result")
	game.refresh_hud()
	var report: Dictionary = game.MissionFlow.summary(game.mission, game.turn_number, game.allies, game.enemies)
	check(report.result == "VICTORY" and report.turns == 2 and report.survivors == 2 and report.casualties == 6 and report.destroyed == 1, "Victory summary counts squad-level outcomes and health-derived casualties")
	check(game.outcome_panel.visible and game.outcome_stats.text.contains("ALLIED CASUALTIES"), "Result panel presents mission summary")
	game.reset_demo()
	check(game.flow.stage == "INTRO" and game.flow.placed.is_empty() and game.rangers.health == 400 and game.presentation.notice_history.is_empty(), "Restart clears deployment, casualties and notifications")
	game.start_mission()
	for squad in game.allies: game.place_deployment(squad, squad.cell)
	game.begin_battle()
	game.turn_number = 8
	game.mission.finish("GERMAN", "Time expired")
	game.refresh_hud()
	check(game.outcome_values.text.contains("DEFEAT") and game.outcome_values.text.contains("8 / 8"), "Defeat uses the same accurate result summary")
	game.queue_free()
	await process_frame
	print("VERTICAL SLICE CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
