extends SceneTree
const Mission = preload("res://scripts/mission_state.gd")
const Squad = preload("res://scripts/squad_data.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var ally := Squad.new()
	var other := Squad.new()
	var enemy := Squad.new(true)
	var allies := [ally, other]
	var enemies := [enemy]
	var mission := Mission.new()
	mission.update_status(allies, enemies)
	check(mission.objective_status == "NEUTRAL" and mission.capture_points == 0, "Mission begins neutral at zero capture")
	ally.cell = Mission.ZONE[0]
	other.cell = Mission.ZONE[1]
	mission.update_status(allies, enemies)
	check(mission.objective_status == "ALLIED CONTROL" and mission.capture_points == 0, "Entering alone changes control but does not instantly score")
	mission.end_allied_phase(1, allies, enemies)
	check(mission.capture_points == 1 and not mission.finished(), "Multiple Allies still earn only one point per Allied phase")
	mission.end_allied_phase(1, allies, enemies)
	check(mission.capture_points == 1, "A repeated phase-close call cannot double count")
	enemy.cell = Mission.ZONE[2]
	mission.end_allied_phase(2, allies, enemies)
	check(mission.objective_status == "CONTESTED" and mission.capture_points == 1, "Contested phase cannot gain capture")
	enemy.cell = Vector2i(9, 9)
	ally.cell = Vector2i(0, 0)
	other.cell = Vector2i(0, 1)
	mission.end_allied_phase(3, allies, enemies)
	check(mission.objective_status == "NEUTRAL" and mission.capture_points == 1, "Vacant objective preserves earned points without scoring")
	ally.cell = Mission.ZONE[0]
	mission.end_allied_phase(4, allies, enemies)
	check(mission.winner == "ALLIED" and mission.capture_points == 2, "Second capture point wins the mission")
	mission.end_german_phase(8, allies, enemies)
	check(mission.winner == "ALLIED", "Mission result cannot be overwritten")
	mission = Mission.new()
	ally.cell = Vector2i(0, 0)
	mission.end_allied_phase(8, allies, enemies)
	check(not mission.finished(), "Turn eight still includes German phase")
	mission.end_german_phase(8, allies, enemies)
	check(mission.winner == "GERMAN", "Missing capture deadline loses at end of turn eight")
	mission = Mission.new()
	mission.capture_points = 1
	ally.cell = Mission.ZONE[0]
	mission.end_allied_phase(8, allies, enemies)
	check(mission.winner == "ALLIED", "Capture on final Allied phase wins before deadline")
	mission = Mission.new()
	enemy.health = 0
	mission.check_elimination(allies, enemies)
	check(mission.winner == "ALLIED", "Eliminating all Germans wins")
	mission = Mission.new()
	enemy.restore()
	ally.health = 0
	other.health = 0
	mission.check_elimination(allies, enemies)
	check(mission.winner == "GERMAN", "Losing all Allies is defeat")
	mission = Mission.new()
	ally.restore()
	other.restore()
	other.cell = Vector2i(0, 1)
	ally.cell = Mission.ZONE[0]
	enemy.cell = Mission.ZONE[1]
	enemy.health = 0
	# Keep a living German outside: the dead member inside must not contest.
	var reserve := Squad.new(true)
	mission.end_allied_phase(1, allies, [enemy, reserve])
	check(mission.capture_points == 1, "Dead squads do not contest")
	var game = load("res://scenes/battlefield.tscn").instantiate()
	game.mission_start_flow = false # This suite exercises battle outcomes directly.
	root.add_child(game)
	await process_frame
	game.ai_delay_scale = 0.01
	for cell in Mission.ZONE:
		check(not game.Terrain.blocks_movement(game.cover.get(cell)), "Objective tiles are clear and occupiable")
	var route = game.objective_route_for(game.enemy)
	check(not route.is_empty() and route.size() <= game.enemy.effective_movement() and game.EnemyAI.distance(route[-1], Mission.ZONE[1]) < game.EnemyAI.distance(game.enemy.cell, Mission.ZONE[1]), "Grenadiers advance toward objective within movement allowance")
	check(game.objective_route_for(game.mg42).is_empty() and game.mg42.cell not in Mission.ZONE, "Covered MG42 overlooks objective instead of rushing in")
	game.rangers.cell = Mission.ZONE[0]
	game.rangers.position = game.project_cell(game.rangers.cell)
	game.rangers.action_points = 0
	game.rifle.action_points = 0
	game.machine_gun.action_points = 0
	game.refresh_hud()
	check(game.mission.capture_points == 0, "Spending all Allied AP does not auto-close phase")
	await game.next_turn()
	check(game.mission.capture_points == 1 and game.enemy.cell in Mission.ZONE and game.turn_number == 2, "End phase captures once, then German AI contests")
	game.refresh_hud()
	check(game.objective_label.text.contains("CONTESTED") and game.objective_label.text.contains("1/2"), "Objective HUD reflects live contest and progress")
	game.reset_demo()
	game.rangers.cell = Mission.ZONE[0]
	game.rangers.position = game.project_cell(game.rangers.cell)
	game.mission.capture_points = 1
	game.turn_number = 8
	game.select_squad(game.rangers)
	var enemy_hp: int = game.enemy.health
	await game.next_turn()
	check(game.mission.winner == "ALLIED" and not game.enemy_turn and game.turn_number == 8 and game.outcome_panel.visible, "Capture victory stops enemy phase and shows result")
	game.move_to(Mission.ZONE[1])
	game.attack_enemy()
	game.activate_overwatch()
	game.select_grenade()
	await game.next_turn()
	check(game.rangers.action_points == 2 and game.enemy.health == enemy_hp and not game.grenade_mode and game.turn_number == 8, "Mission completion locks movement, attacks and phase advancement")
	game.reset_demo()
	game.turn_number = 8
	game.cover.clear()
	# Block German movement without killing either side; test actual timeout flow.
	for squad in game.enemies:
		for direction in game.DIRECTIONS:
			game.cover[squad.cell + direction] = "crate"
	await game.next_turn()
	check(game.mission.winner == "GERMAN" and game.turn_number == 8 and game.outcome_title.text.contains("DEFEAT"), "End of eighth full turn displays defeat without creating turn nine")
	game.reset_demo()
	for squad in game.enemies:
		squad.health = 0
	game.check_mission()
	game.refresh_hud()
	check(game.mission.winner == "ALLIED" and game.outcome_panel.visible, "Elimination victory integrates with mission UI")
	game.reset_demo()
	for squad in game.allies:
		squad.health = 0
	game.check_mission()
	game.refresh_hud()
	check(game.mission.winner == "GERMAN" and game.outcome_panel.visible, "Allied elimination shows defeat")
	game.reset_demo()
	check(not game.mission.finished() and game.mission.capture_points == 0 and game.turn_number == 1 and not game.outcome_panel.visible, "Restart restores neutral mission and removes result panel")
	game.queue_free()
	await process_frame
	print("MISSION CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
