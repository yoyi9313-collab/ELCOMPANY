extends SceneTree
const Rules = preload("res://scripts/grenade_rules.gd")
const Squad = preload("res://scripts/squad_data.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	check(Rules.blast_cells(Vector2i(0, 0), 10).size() == 3, "Blast clips at map edge")
	check(Rules.blast_cells(Vector2i(4, 4), 10).size() == 5, "Blast includes four orthogonal neighbors")
	check(not Rules.blast_cells(Vector2i(4, 4), 10).has(Vector2i(5, 5)), "Diagonal is outside blast")
	check(Rules.damage(120, Vector2i(4, 4), {}) == 120, "Exposed damage is unchanged")
	check(Rules.damage(120, Vector2i(4, 4), {Vector2i(4, 3): "crate"}) == 108, "Light cover reduces damage ten percent")
	check(Rules.damage(120, Vector2i(4, 4), {Vector2i(4, 3): "sandbags", Vector2i(3, 4): "crate"}) == 90, "Strongest cover reduces damage 25 percent without stacking")
	var data := Squad.new()
	check(data.spend_action("fire") and data.spend_action("grenade"), "Fire plus grenade uses two AP independently")
	check(data.attacks_this_turn == 1 and data.action_points == 0, "Grenade does not spend a firearm attack")
	data.begin_turn()
	check(not data.can_perform("grenade"), "Turn reset never replenishes grenade")
	data.restore()
	check(data.grenades_remaining == 1, "Battle reset replenishes grenade")
	check(not Squad.new(true).can_perform("grenade"), "Enemy has no grenades")
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.cover.clear()
	game.squad_cell = Vector2i(4, 4)
	game.squad_position = game.project_cell(game.squad_cell)
	game.enemy.cell = Vector2i(4, 2)
	game.enemy.position = game.project_cell(game.enemy.cell)
	game.rangers.face_direction(Vector2.DOWN)
	game.selected = true
	game.rebuild_range()
	game.select_grenade()
	check(game.grenade_mode and not game.target_panel.visible, "Grenade mode replaces normal targeting")
	check(game.valid_grenade_tile(game.enemy.cell) and not game.rangers.in_firing_arc(game.enemy.cell), "Grenade can target behind the squad")
	game.throw_grenade(Vector2i(4, 1))
	check(game.rangers.action_points == 2 and game.rangers.grenades_remaining == 1, "Invalid throw consumes nothing")
	game.deselect()
	check(not game.grenade_mode and game.selected, "Escape cancels grenade without deselecting squad")
	game.rangers.action_points = 0
	game.select_grenade()
	check(not game.grenade_mode, "Cannot select grenade at zero AP")
	game.rangers.begin_turn()
	game.select_grenade()
	game.throw_grenade(game.enemy.cell)
	check(game.grenade_busy and game.rangers.action_points == 1 and game.rangers.grenades_remaining == 0, "Throw spends exactly one AP and one grenade")
	game.next_turn()
	game.reset_demo()
	game.move_to(Vector2i(5, 4))
	game.activate_overwatch()
	check(not game.enemy_turn and game.rangers.action_points == 1 and game.grenade_busy, "Other actions locked during flight")
	check(game.enemy.health == 400, "Damage waits for impact")
	await create_timer(1.5).timeout
	check(not game.grenade_busy, "Throw animation completes")
	check(game.enemy.health >= 190 and game.enemy.health <= 230, "Direct damage is 170 to 210")
	check(game.enemy.suppression == 2 and game.enemy.living_members().size() == ceili(game.enemy.health / 100.0), "Direct explosion suppresses and triggers health-based casualties")
	check(game.rangers.health == 400, "Squad outside radius is unaffected")
	check(game.grenade_results.size() == 1 and game.grenade_status_label.text == "GRENADE SPENT", "Floating result and inventory UI updated")
	game.rangers.begin_turn()
	game.select_grenade()
	check(not game.grenade_mode, "Spent grenade cannot be selected next turn")
	game.enemy.restore()
	game.enemy.cell = Vector2i(4, 3)
	game.enemy.position = game.project_cell(game.enemy.cell)
	game.resolve_grenade(game.squad_cell)
	check(game.rangers.health >= 190 and game.rangers.health <= 230 and game.rangers.suppression == 2, "Friendly direct damage and suppression")
	check(game.enemy.health >= 290 and game.enemy.health <= 315 and game.enemy.suppression == 1, "Adjacent damage and one suppression")
	game.enemy.health = 1
	game.resolve_grenade(game.enemy.cell)
	check(game.enemy.health == 0 and not game.enemy_occupies(game.enemy.cell), "Lethal blast removes squad occupancy")
	game.reset_demo()
	check(game.rangers.grenades_remaining == 1 and game.grenade_results.is_empty(), "Reset clears visuals and restores inventory")
	game.enemy_turn = true
	game.selected = true
	game.select_grenade()
	check(not game.grenade_mode, "Enemy turn disables grenade selection")
	game.enemy_turn = false
	game.queue_free()
	await process_frame
	print("GRENADE CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
