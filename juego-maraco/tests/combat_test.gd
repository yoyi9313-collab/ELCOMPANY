extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func seed_for_roll(minimum: int, maximum: int) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in range(10000):
		probe.seed = candidate
		var roll := probe.randf_range(0.0, 100.0)
		if roll >= minimum and roll <= maximum:
			return candidate
	push_error("Could not find deterministic seed")
	return 0

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	# Damage/accuracy scenarios use a clear lane; LOS has a dedicated suite.
	game.cover.clear()
	game.set_process(false)
	game.attack_enemy()
	check(game.enemy.health == 400 and not game.attack_used, "Unselected squad cannot attack")
	game.selected = true
	game.target_hovered = true
	game.refresh_hud()
	check(game.target_panel.visible and game.target_state_label.text == "OUT OF RANGE", "Hovering a distant target shows OUT OF RANGE")
	game.attack_enemy()
	check(game.enemy.health == 400 and game.traces.is_empty() and not game.attack_used, "Out-of-range attack has no effects or action cost")
	game.squad_cell = Vector2i(5, 2)
	game.squad_position = game.project_cell(game.squad_cell)
	check(game.target_distance() == 4, "Range uses orthogonal grid steps")
	check(game.attack_block_reason() == "OUT OF RANGE", "Four tiles is out of range")
	game.squad_cell = Vector2i(6, 2)
	game.squad_position = game.project_cell(game.squad_cell)
	game.rebuild_range()
	game.refresh_hud()
	check(game.target_distance() == 3 and game.attack_block_reason().is_empty(), "Exactly three tiles is in range")
	check(game.target_state_label.text == "VALID TARGET" and not game.fire_button.disabled, "Valid target enables firing")
	check(game.target_hit_chance() == 85, "Exposed target has 85 percent hit chance")
	game.cover[Vector2i(8, 0)] = "sandbags"
	game.refresh_hud()
	check(game.target_hit_chance() == 60 and game.target_cover_label.text.contains("HEAVY"), "Adjacent heavy cover subtracts 25 percentage points")
	game.cover[Vector2i(9, 1)] = "crate"
	check(game.target_hit_chance() == 60, "Multiple cover objects do not stack penalties")
	game.cover.erase(Vector2i(8, 0))
	game.cover.erase(Vector2i(9, 1))
	game.moving = true
	game.attack_enemy()
	check(game.enemy.health == 400 and not game.attack_used, "Squad cannot attack during movement")
	game.moving = false
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.enemy.member_position(game.enemy.members[0]) + Vector2(0, -20)
	game._unhandled_input(click)
	check(game.selected and game.target_pinned and not game.moving and game.enemy.health == 400, "Clicking an enemy model locks the squad target without moving or firing")
	var hit_seed := seed_for_roll(1, 60)
	game.combat_rng.seed = hit_seed
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = hit_seed
	expected_rng.randf_range(0.0, 100.0)
	var expected_damage := expected_rng.randi_range(80, 110)
	var health_after_hit := 400 - expected_damage
	game.fire_button.pressed.emit()
	check(game.enemy.health == health_after_hit and game.attack_used, "One squad attack applies its single damage roll")
	check(game.combat_rng.state == expected_rng.state, "One squad hit roll and one damage roll")
	check(game.traces.size() == 4 and game.volley_left > 0.0, "Four visual shots accompany one damage result")
	check(game.rangers.action_points == 1, "Firing spends one AP")
	check(expected_damage >= 80 and expected_damage <= 110, "Damage lies in inclusive range")
	check(game.enemy.suppression == 1 and game.enemy.effective_movement() == 3 and game.enemy.action_points == 2, "Successful attack applies suppression and movement penalty")
	check(game.suppression_text_left > 0.0 and game.last_result.contains(str(expected_damage)), "Floating text reports damage and suppression")
	game.attack_enemy()
	check(game.enemy.health == health_after_hit, "Rapid repeated attacks cannot deal extra damage")
	var old_cell: Vector2i = game.squad_cell
	game.move_to(Vector2i(6, 1))
	game.next_turn()
	check(not game.moving and game.squad_cell == old_cell and game.turn_number == 1, "Movement and turn change wait for volley")
	game.set_process(true)
	await create_timer(0.7).timeout
	game.set_process(false)
	check(game.volley_left == 0.0 and game.attack_block_reason() == "ATTACK SPENT", "Volley expires; one attack per turn")
	refresh_test_turn(game)
	check(not game.attack_used and game.rangers.action_points == 2, "New turn restores attack and movement")
	check(game.enemy.suppression == 0 and game.enemy.action_points == 2, "Idle enemy phase starts its turn and clears suppression")
	game.combat_rng.seed = seed_for_roll(86, 100)
	game.attack_enemy()
	check(game.enemy.health == health_after_hit and game.last_result == "MISS" and game.attack_used, "Miss consumes attack but deals no damage")
	check(game.enemy.suppression == 0, "Miss does not suppress")
	game.volley_left = 0.0
	refresh_test_turn(game)
	game.cover[Vector2i(8, 0)] = "sandbags"
	game.combat_rng.seed = seed_for_roll(61, 85)
	game.attack_enemy()
	check(game.enemy.health == health_after_hit and game.last_result == "MISS", "Cover changes actual hit resolution, not just UI")
	game.cover.erase(Vector2i(8, 0))
	for shot in 6:
		if game.enemy.health <= 0:
			break
		var expected_health: int = maxi(0, game.enemy.health - expected_damage)
		game.volley_left = 0.0
		refresh_test_turn(game)
		game.combat_rng.seed = hit_seed
		game.attack_enemy()
		check(game.enemy.health == expected_health, "Repeated successful turns clamp damage at zero")
	check(game.enemy.living_members().is_empty() and game.attack_block_reason() == "TARGET ELIMINATED", "Zero-health squad cannot be targeted")
	check(game.reachable.has(game.enemy.cell), "Eliminated squad releases its logical tile")
	game.reset_demo()
	check(game.enemy.health == 400 and game.enemy.living_members().size() == 4, "Reset restores enemy health and roster")
	check(not game.attack_used and game.traces.is_empty() and game.volley_left == 0.0 and not game.target_panel.visible, "Reset clears combat state, effects and target panel")
	check(game.rangers.health == 400, "No enemy attacks occur")
	game.selected = true
	game.rangers.action_points = 1
	game.rangers.apply_suppression()
	check(game.rangers.suppression == 1 and game.rangers.action_points == 1 and game.rangers.effective_movement() == 3, "First suppression subtracts only one from remaining movement")
	check(game.target_hit_chance() == 85, "One suppression point does not penalize accuracy")
	game.rangers.apply_suppression()
	check(game.rangers.action_points == 1 and game.rangers.effective_movement() == 2 and game.target_hit_chance() == 70, "Two suppression points reduce movement by two and accuracy by fifteen")
	game.cover[Vector2i(8, 0)] = "sandbags"
	check(game.target_hit_chance() == 45, "Shooter suppression stacks with target cover")
	game.cover.erase(Vector2i(8, 0))
	game.rangers.apply_suppression()
	check(game.rangers.suppression == 2 and game.rangers.action_points == 1, "Suppression caps at two without repeated movement deductions")
	game.rebuild_range()
	for cell in game.reachable:
		check(game.path_to(cell).size() <= 2, "Movement range obeys reduced remaining movement")
	game.begin_squad_turn(game.enemy)
	check(game.rangers.suppression == 2, "Another squad's turn does not reset Ranger suppression")
	game.begin_squad_turn(game.rangers)
	check(game.rangers.suppression == 2 and game.rangers.action_points == 2, "Own phase retains penalties")
	game.rangers.apply_suppression()
	game.enemy.apply_suppression()
	game.reset_demo()
	check(game.rangers.suppression == 0 and game.enemy.suppression == 0, "Reset clears suppression on both squads")
	for boundary in [80, 110]:
		var found := false
		for candidate in 10000:
			var probe := RandomNumberGenerator.new()
			probe.seed = candidate
			if probe.randf_range(0.0, 100.0) <= 85 and probe.randi_range(80, 110) == boundary:
				game.reset_demo()
				game.selected = true
				game.squad_cell = Vector2i(6, 2)
				game.squad_position = game.project_cell(game.squad_cell)
				game.combat_rng.seed = candidate
				game.attack_enemy()
				check(game.enemy.health == 400 - boundary, "Damage boundary %d is attainable" % boundary)
				found = true
				break
		check(found, "Found seed for inclusive damage boundary")
	print("COMBAT CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func refresh_test_turn(game) -> void:
	# Combat unit-test fixture: replenish actions without running a separate AI turn.
	# Actual asynchronous turn behavior is covered in enemy_ai_test.gd.
	game.begin_squad_turn(game.enemy)
	game.enemy.end_turn()
	game.begin_squad_turn(game.rangers)
	game.turn_number += 1
