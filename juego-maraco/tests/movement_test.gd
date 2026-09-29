extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	check(game.rangers.action_points == 2, "Initial movement budget")
	check(game.members.size() == 4 and game.living_members().size() == 4, "Four Rangers in one roster")
	check(game.unit_label.text == "ASSAULT SQUAD / 4 MEN", "Squad subtitle")
	var identities: Array[String] = []
	for member in game.members:
		check(not identities.has(member.id), "Members have stable unique identities")
		identities.append(member.id)
		check(game.cell_at(game.member_position(member)) == game.squad_cell, "Every formation anchor stays on the squad tile")
	for y in game.BOARD:
		for x in game.BOARD:
			var cell := Vector2i(x, y)
			check(game.cell_at(game.project_cell(cell)) == cell, "Grid hit test round trip")
	for cell in game.reachable:
		check(not game.cover.has(cell), "Cover must not be reachable")
		var route = game.path_to(cell)
		check(route.size() <= game.rangers.effective_movement(), "Path stays within movement budget")
		var previous: Vector2i = game.squad_cell
		for step in route:
			check(absi(step.x - previous.x) + absi(step.y - previous.y) == 1, "Path must use adjacent cells")
			check(not game.cover.has(step), "Path must avoid cover")
			previous = step
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	for member in game.members:
		game.deselect()
		click.position = game.member_position(member) + Vector2(0, -20)
		game._unhandled_input(click)
		check(game.selected and not game.moving, "Click any member selects the entire squad")
	click.position = game.project_cell(game.squad_cell)
	game._unhandled_input(click)
	check(game.selected, "Click selects squad_cell")
	var destination := Vector2i(-1, -1)
	for cell in game.reachable:
		if game.reachable[cell] == 4:
			destination = cell
			break
	check(destination != Vector2i(-1, -1), "A full four-tile route exists")
	click.position = game.project_cell(destination)
	game._unhandled_input(click)
	check(game.moving, "Movement animation starts")
	check(game.rangers.action_points == 1, "Move costs one AP independent of distance")
	await game.next_turn()
	check(game.turn_number == 1, "Turn cannot change during movement")
	await create_timer(0.25).timeout
	check(game.squad_position != game.project_cell(game.START), "Squad anchor animates along the route")
	for member in game.members:
		check((game.member_position(member) - game.squad_position).is_equal_approx(member.offset), "All four soldiers follow the shared moving anchor")
	await game.movement_finished
	await process_frame
	check(game.squad_cell == destination, "Soldier arrives at destination")
	check(game.squad_position == game.project_cell(destination), "Sprite arrives at cell center")
	check(game.reachable.size() > 1, "One AP remains for a second move")
	await game.next_turn()
	check(game.rangers.action_points == 2 and game.turn_number == 2, "Next turn restores movement")
	var previous_reachable: Dictionary = game.reachable.duplicate()
	game.rangers.health = 300
	game.refresh_hud()
	check(game.living_members().size() == 3 and game.members.size() == 4, "Casualty hides one member but retains roster identity")
	check(game.unit_label.text == "ASSAULT SQUAD / 3 MEN", "UI follows live roster")
	check(game.squad_cell == destination and game.rangers.action_points == 2 and game.reachable == previous_reachable, "Roster change preserves tactical state")
	var next_cell: Vector2i = game.path_to(game.reachable.keys()[-1])[0]
	game.move_to(next_cell)
	await game.movement_finished
	check(game.squad_cell == next_cell and game.rangers.action_points == 1, "Squad with three survivors still moves as one unit")
	game.deselect()
	check(not game.selected, "Deselect works")
	game.reset_demo()
	check(game.squad_cell == game.START and game.rangers.action_points == 2 and game.turn_number == 1, "Reset restores initial state")
	check(game.living_members().size() == 4, "Reset restores all four members")
	check(game.enemy.get_script() == game.rangers.get_script(), "Both factions share the squad data implementation")
	check(game.enemy.name == "GRENADIERS" and game.enemy.type == "INFANTRY SQUAD", "Enemy identity")
	check(game.enemy.health == 400 and game.enemy.movement == 4 and game.enemy.members.size() == 4, "Enemy stats and roster")
	check(game.enemy.hostile and not game.enemy.player_controlled, "Enemy cannot be player controlled")
	var enemy_cell: Vector2i = game.enemy.cell
	var enemy_position: Vector2 = game.enemy.position
	check(not game.cover.has(enemy_cell), "Enemy starts on a clear tile")
	for member in game.enemy.members:
		check(game.cell_at(game.enemy.member_position(member)) == enemy_cell, "Enemy formation occupies one logical tile")
		click.position = game.enemy.member_position(member) + Vector2(0, -20)
		game._unhandled_input(click)
		check(not game.selected and not game.moving, "Clicking each enemy member cannot select or move a unit")
	# Bring the player close enough that enemy occupancy, not range, blocks entry.
	game.squad_cell = Vector2i(6, 1)
	game.squad_position = game.project_cell(game.squad_cell)
	game.selected = true
	game.rebuild_range()
	check(not game.reachable.has(enemy_cell) and game.path_to(enemy_cell).is_empty(), "Enemy tile is excluded from range and paths")
	for cell in game.reachable:
		check(not game.path_to(cell).has(enemy_cell), "Routes never pass through the enemy")
	click.position = enemy_position
	game._unhandled_input(click)
	check(game.selected and not game.moving and game.rangers.action_points == 2, "Enemy click preserves Ranger selection without issuing movement")
	game.move_to(enemy_cell)
	check(not game.moving, "Direct movement order cannot enter occupied enemy tile")
	await game.next_turn()
	check(game.enemy.cell == enemy_cell and game.enemy.position == enemy_position and game.enemy.action_points == 1, "Next turn leaves enemy stationary")
	game.reset_demo()
	print("MOVEMENT CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
