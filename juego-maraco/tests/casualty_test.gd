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
	for hostile in [false, true]:
		var squad := Squad.new(hostile)
		for hp in [400, 301, 300, 201, 200, 101, 100, 1, 0]:
			squad.health = hp
			var expected := 0 if hp == 0 else (4 if hp > 300 else (3 if hp > 200 else (2 if hp > 100 else 1)))
			check(squad.living_members().size() == expected, "Exact HP boundary %d for faction %s" % [hp, hostile])
			squad.update_visuals(1.0)
			check(squad.visible_members().size() == expected, "Completed casualty fades match living roster")
		squad.restore()
		check(squad.health == 400 and squad.visible_members().size() == 4, "Restore returns full roster")
	for count in [2, 3, 4, 5]:
		var squad := Squad.new(false, count, "TEST INFANTRY")
		check(squad.members.size() == count and squad.health == count * 100, "Configurable initial squad size")
		squad.position = Vector2(240, 240)
		var dying = squad.members[-1]
		var survivor = squad.members[1] if count == 5 else squad.members[0]
		var old_offset: Vector2 = survivor.offset
		squad.health -= 100
		check(squad.living_members().size() == count - 1 and squad.visible_members().size() == count, "Casualty stays visible while no longer active")
		check(not dying.alive and dying.casualty_time == 0.0, "Casualty animation begins at threshold")
		check(survivor.offset == old_offset and survivor.target_offset != old_offset, "Survivors ease to their new slots instead of jumping")
		var corpse_position: Vector2 = squad.member_position(dying)
		squad.position += Vector2(50, 20)
		check(squad.member_position(dying) == corpse_position, "Falling casualty stays at the death location as squad moves")
		squad.update_visuals(0.35)
		check(dying.casualty_progress() > 0.0 and dying.casualty_progress() < 1.0 and dying.is_visible(), "Casualty progresses without disappearing instantly")
		check(survivor.offset != old_offset, "Survivor formation interpolates")
		squad.health -= 1
		check(dying.casualty_time > 0.0, "Damage within the same threshold does not restart casualty animation")
		squad.update_visuals(1.0)
		check(not dying.is_visible(), "Casualty disappears when animation finishes")
		squad.health = 0
		check(squad.living_members().is_empty(), "Lethal damage immediately removes logical unit")
		squad.update_visuals(1.0)
		check(squad.visible_members().is_empty(), "Lethal damage fades all remaining models")
		squad.restore()
		check(squad.visible_members().size() == count, "Reset cancels all casualty animation state")
	var custom := Squad.new(false, 5, "RIFLE SQUAD", "INFANTRY SQUAD", 250)
	custom.health = 200
	check(custom.living_members().size() == 4, "Custom max health uses proportional thresholds")
	custom.health = 500
	check(custom.health == 250, "Health clamps to squad maximum")
	custom.health = -10
	check(custom.health == 0, "Health cannot become negative")
	var game = load("res://scenes/battlefield.tscn").instantiate()
	# Keep this legacy scenario focused on its original Grenadier opponent.
	game.enemies.erase(game.mg42)
	game.mission_enabled = false # Isolate tactical rules from mission victory/AI.
	root.add_child(game)
	await process_frame
	game.rangers.health = 200
	game.enemy.health = 100
	game.refresh_hud()
	check(game.unit_label.text == "ASSAULT SQUAD / 2 MEN", "Ranger HUD follows health thresholds")
	check(game.enemy_info_label.text.contains("1 MEN"), "Enemy HUD follows health thresholds")
	check(not game.members[2].alive and not game.enemy.members[1].alive, "Roster indicators derive dimmed state from health")
	game.selected = true
	game.rangers.health = 0
	await process_frame
	check(not game.selected and game.reachable.is_empty(), "Destroyed Rangers cannot be selected or moved")
	game.reset_demo()
	check(game.rangers.health == 400 and game.enemy.health == 400, "Demo reset restores both squad health totals")
	print("CASUALTY CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
