extends SceneTree
var failures := 0
var reactions: Array = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func click_squad(game, squad) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = squad.position
	game._unhandled_input(event)

func place(game, squad, cell: Vector2i) -> void:
	squad.cell = cell
	squad.position = game.project_cell(cell)

func run_checks() -> void:
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.ai_delay_scale = 0.01
	check(game.rifle.members.size() == 5 and game.rifle.health == 450, "Rifle profile has five members and 450 squad HP")
	var weapons: Array = []
	for member in game.rifle.members:
		weapons.append(member.weapon)
	check(weapons.count("M1 Garand") == 3 and weapons.count("BAR") == 1 and weapons.count("M1 Carbine") == 1, "Rifle roster equipment")
	click_squad(game, game.rifle)
	check(game.active_squad == game.rifle and game.selected and game.unit_name_label.text == "U.S. RIFLE SQUAD", "Click selects Rifle and updates HUD")
	game.cover.clear()
	place(game, game.rangers, Vector2i(4, 4))
	place(game, game.rifle, Vector2i(5, 4))
	click_squad(game, game.rangers)
	check(game.active_squad == game.rangers, "Click switches back to Rangers")
	check(not game.reachable.has(game.rifle.cell), "Friendly tile cannot be occupied")
	var route = game.path_to(Vector2i(6, 4))
	check(route.size() == 4 and not route.has(game.rifle.cell), "Movement routes around friendly squad")
	await game.move_to(Vector2i(4, 5))
	check(game.rangers.action_points == 1 and game.rifle.action_points == 2, "Movement spends only selected squad AP")
	game.rangers.apply_suppression()
	game.rangers.spend_action("grenade")
	game.select_squad(game.rangers)
	check(game.selected and game.active_squad.action_points == 0 and game.fire_button.disabled and game.grenade_button.disabled and game.overwatch_button.disabled, "Zero AP squad remains inspectable but cannot spend actions")
	click_squad(game, game.rifle)
	check(game.rifle.suppression == 0 and game.rifle.grenades_remaining == 1 and game.grenade_status_label.text == "GRENADE READY", "Suppression and grenades are independent")
	place(game, game.rifle, Vector2i(4, 1))
	place(game, game.enemy, Vector2i(8, 1))
	game.rifle.face_cell(game.enemy.cell)
	game.enemy.face_cell(game.rifle.cell)
	check(game.attack_block_reason().is_empty() and game.target_hit_chance() == 80, "Rifle can fire at range four with 80 percent base accuracy")
	game.cover[Vector2i(8, 0)] = "crate"
	check(game.target_hit_chance() == 55, "Rifle frontal cover accuracy is 55 percent")
	game.cover.clear()
	for seed_value in 100:
		game.combat_rng.seed = seed_value
		if game.combat_rng.randf_range(0.0, 100.0) < 80:
			game.combat_rng.seed = seed_value
			break
	game.attack_enemy()
	check(game.enemy.health >= 305 and game.enemy.health <= 330, "Rifle normal shot deals 70 to 95")
	check(game.rifle.attacks_this_turn == 1 and game.rangers.attacks_this_turn == 0 and game.rifle.action_points == 1, "Attack cap and AP are independent")
	await create_timer(0.65).timeout
	game.select_grenade()
	await game.throw_grenade(Vector2i(6, 1))
	check(game.rifle.grenades_remaining == 0 and game.rifle.action_points == 0, "Rifle uses shared grenade action")
	game.enemy.health = 0
	game.next_turn()
	game.select_squad(game.rangers)
	check(game.active_squad == game.rifle, "Cannot switch during enemy phase")
	while game.enemy_turn:
		await process_frame
	check(game.rangers.action_points == 2 and game.rifle.action_points == 2 and game.rangers.suppression == 1 and game.rifle.attacks_this_turn == 0, "Allied phase resets AP while preserving suppression")
	check(game.rangers.grenades_remaining == 0 and game.rifle.grenades_remaining == 0, "Phase reset does not refill either grenade")
	game.reset_demo()
	game.cover.clear()
	place(game, game.rangers, Vector2i(3, 1))
	place(game, game.rifle, Vector2i(3, 2))
	for squad in game.allies:
		game.select_squad(squad)
		game.face_selected(game.enemy.cell)
		game.activate_overwatch()
	check(game.rangers.overwatch_active and game.rifle.overwatch_active, "Both squads retain independent Overwatch states")
	game.overwatch_triggered.connect(func(watcher, _target): reactions.append(watcher))
	await game.next_turn()
	check(reactions.has(game.rangers) and reactions.has(game.rifle) and reactions.size() == 2, "Both squads react during enemy movement regardless of selection")
	check(game.enemy.cell != game.rangers.cell and game.enemy.cell != game.rifle.cell, "Enemy movement avoids all Allied cells")
	game.rangers.health = 0
	game.select_squad(game.rifle)
	check(game.selected and game.enemy_target() == game.rifle and not game.end_button.disabled, "Remaining Rifle squad can continue the battle")
	game.rifle.health = 270
	check(game.rifle.living_members().size() == 3 and game.rangers.living_members().is_empty(), "Rifle casualties use proportional squad health independently")
	game.reset_demo()
	check(game.rifle.health == 450 and game.rifle.cell == game.RIFLE_START and game.rifle.grenades_remaining == 1 and game.rangers.health == 400, "Reset restores both squad profiles")
	game.queue_free()
	await process_frame
	print("MULTI SQUAD CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
