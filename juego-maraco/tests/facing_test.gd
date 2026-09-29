extends SceneTree
const Squad = preload("res://scripts/squad_data.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var squad := Squad.new()
	squad.cell = Vector2i(4, 4)
	squad.face_direction(Vector2.RIGHT)
	check(squad.in_firing_arc(Vector2i(6, 4)), "Forward target is inside arc")
	check(not squad.in_firing_arc(Vector2i(4, 6)) and not squad.in_firing_arc(Vector2i(2, 4)), "Side and rear targets are outside 120-degree arc")
	squad.face_direction(Vector2.RIGHT.rotated(deg_to_rad(60.0)))
	check(squad.in_firing_arc(Vector2i(6, 4)), "Exactly 60 degrees is included")
	squad.face_direction(Vector2.RIGHT.rotated(deg_to_rad(60.1)))
	check(not squad.in_firing_arc(Vector2i(6, 4)), "Beyond 60 degrees is excluded")
	squad.face_direction(Vector2.RIGHT)
	check(squad.incoming_sector(Vector2i(6, 4)) == "FRONT", "Front attack classification")
	check(squad.incoming_sector(Vector2i(4, 6)) == "FLANK", "Side attack classification")
	check(squad.incoming_sector(Vector2i(2, 4)) == "REAR", "Rear attack classification")
	squad.face_direction(Vector2.RIGHT.rotated(deg_to_rad(150.0)))
	check(squad.incoming_sector(Vector2i(6, 4)) == "REAR", "Rear cone includes its 150-degree boundary")
	squad.firing_arc_degrees = 360.0
	check(squad.in_firing_arc(Vector2i(6, 4)), "Future 360-degree arc is supported")
	squad.firing_arc_degrees = 60.0
	squad.face_direction(Vector2.RIGHT)
	check(not squad.in_firing_arc(Vector2i(6, 6)), "Narrower weapon arc is supported")
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.cover.clear()
	game.cover[Vector2i(4, 3)] = "crate"
	game.squad_cell = Vector2i(6, 4)
	game.squad_position = game.project_cell(game.squad_cell)
	game.enemy.cell = Vector2i(4, 4)
	game.enemy.position = game.project_cell(game.enemy.cell)
	game.rangers.face_cell(game.enemy.cell)
	game.enemy.face_cell(game.rangers.cell)
	game.selected = true
	game.rebuild_range()
	check(game.target_hit_chance() == 60.0, "Front cover keeps full 25-point penalty")
	game.enemy.face_direction(Vector2.UP)
	check(game.target_hit_chance() == 72.5, "Flank halves cover penalty exactly")
	check(game.shot_chance(game.rangers, game.enemy, 70) == 57.5, "Flanking applies to overwatch cover calculations")
	game.enemy.face_direction(Vector2.LEFT)
	check(game.target_hit_chance() == 85.0, "Rear attack ignores cover")
	game.rangers.apply_suppression()
	game.rangers.apply_suppression()
	check(game.target_hit_chance() == 70.0, "Suppression stacks with rear attack")
	game.rangers.begin_turn()
	game.rangers.face_direction(Vector2.RIGHT)
	game.refresh_hud()
	check(game.attack_block_reason() == "OUT OF ARC" and game.fire_button.disabled, "Out-of-arc target is marked and firing is disabled")
	game.attack_enemy()
	check(game.rangers.action_points == 2 and game.enemy.health == 400, "Invalid arc cannot spend AP or deal damage")
	game.rotate_selected(180.0)
	check(game.rangers.in_firing_arc(game.enemy.cell) and game.rangers.action_points == 2, "Rotation is free")
	game.refresh_hud()
	check(game.target_direction_label.text.contains("REAR"), "Target panel shows incoming attack direction")
	game.attack_enemy()
	check(game.flank_text == "REAR ATTACK", "Rear shot reports REAR ATTACK")
	await create_timer(0.65).timeout
	game.reset_demo()
	game.cover.clear()
	game.selected = true
	game.rebuild_range()
	await game.move_to(Vector2i(3, 5))
	check(game.rangers.facing.is_equal_approx(Vector2.UP), "Movement faces final direction of travel")
	var before_ap: int = game.rangers.action_points
	game.face_selected(game.enemy.cell)
	check(game.rangers.action_points == before_ap and game.rangers.in_firing_arc(game.enemy.cell), "Face-tile rotation costs no AP")
	game.rangers.action_points = 0
	game.rotate_selected(45.0)
	check(game.rangers.action_points == 0, "Can rotate with zero AP")
	game.reset_demo()
	game.cover.clear()
	game.squad_cell = Vector2i(3, 3)
	game.squad_position = game.project_cell(game.squad_cell)
	game.enemy.cell = Vector2i(4, 3)
	game.enemy.position = game.project_cell(game.enemy.cell)
	game.selected = true
	game.rangers.face_direction(Vector2.LEFT)
	game.activate_overwatch()
	check(not await game.try_overwatch(game.rangers, game.enemy), "Overwatch never fires behind the squad")
	check(game.rangers.overwatch_active and not game.rangers.overwatch_fired, "Out-of-arc movement does not consume overwatch")
	game.face_selected(game.enemy.cell)
	check(await game.try_overwatch(game.rangers, game.enemy), "Turning the arc permits a valid frontal reaction")
	check(not game.rangers.overwatch_active, "Valid reaction consumes overwatch")
	game.enemy_turn = true
	var direction: Vector2 = game.rangers.facing
	game.rotate_selected(90.0)
	check(game.rangers.facing == direction, "Player cannot rotate during enemy reactions")
	game.enemy_turn = false
	print("FACING CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
