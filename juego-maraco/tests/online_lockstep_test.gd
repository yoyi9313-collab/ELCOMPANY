extends SceneTree
## Two battlefields joined by an in-process loopback play random legal turns
## for both sides; their state hashes must never diverge.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")

func idle(a, b) -> bool:
	return a.sim_idle() and b.sim_idle() and a.command_queue.is_empty() and b.command_queue.is_empty()

func settle(a, b) -> void:
	for i in 2000:
		await process_frame
		if idle(a, b):
			await process_frame
			if idle(a, b):
				return
	check(false, "Peers never settled")

func run_checks() -> void:
	var host = load("res://scenes/battlefield.tscn").instantiate()
	var guest = load("res://scenes/battlefield.tscn").instantiate()
	root.add_child(host)
	root.add_child(guest)
	await process_frame
	host.start_online("ALLIED", 12345, func(c: Array) -> void: guest.receive_command(c.duplicate(true)))
	guest.start_online("GERMAN", 12345, func(c: Array) -> void: host.receive_command(c.duplicate(true)))
	check(host.state_hash() == guest.state_hash(), "Peers start identical")

	guest.ui_start()
	await settle(host, guest)
	check(guest.flow.stage == "INTRO", "German player cannot start the mission")
	host.ui_start()
	await settle(host, guest)
	check(guest.flow.stage == "DEPLOYMENT", "Host start reaches the guest")
	var spots := [Vector2i(2, 9), Vector2i(4, 8), Vector2i(5, 9)]
	for i in host.allies.size():
		host.ui_deploy(host.allies[i], spots[i])
		await settle(host, guest)
	host.ui_begin()
	await settle(host, guest)
	check(guest.flow.stage == "BATTLE" and guest.rangers.cell == Vector2i(2, 9), "Deployment replicates")

	var rng := RandomNumberGenerator.new()
	rng.seed = int(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else 7
	var turns_played := 0
	while not host.mission_over() and turns_played < 16:
		var side: String = host.phase_side
		var actor = host if side == "ALLIED" else guest
		var other = guest if side == "ALLIED" else host
		other.ui_end_turn()
		await settle(host, guest)
		check(host.phase_side == side, "Waiting player cannot end the opponent's phase")
		for squad in actor.controlled_squads():
			if squad.health <= 0 or actor.mission_over():
				continue
			actor.ui_select(squad)
			await settle(host, guest)
			for step in 3:
				if actor.mission_over():
					break
				var fired := false
				for target in actor.opposing_squads():
					if target.health > 0:
						actor.target_enemy = target
						if actor.attack_block_reason() == "OUT OF ARC":
							actor.ui_face(target.cell)
							await settle(host, guest)
						actor.target_enemy = target
						if actor.attack_block_reason().is_empty():
							actor.ui_fire()
							fired = true
							break
				if not fired:
					var options: Array = actor.reachable.keys().filter(func(c): return c != actor.active_squad.cell)
					if options.is_empty():
						if actor.active_squad.can_perform("overwatch"):
							actor.ui_overwatch()
					else:
						actor.ui_move(options[rng.randi_range(0, options.size() - 1)])
				await settle(host, guest)
				check(host.state_hash() == guest.state_hash(), "State diverged during %s phase" % side)
		actor.ui_end_turn()
		await settle(host, guest)
		turns_played += 1
		check(host.state_hash() == guest.state_hash(), "State diverged after %s phase end" % side)
	check(not host.desync and not guest.desync, "No desync flagged")
	check(turns_played >= 2, "At least one full round was played (%d phases)" % turns_played)
	print("Phases played: %d, over: %s, winner: %s, capture %d" % [turns_played, host.mission_over(), host.mission.winner, host.mission.capture_points])
	for squad in host.all_squads():
		print("  %s hp %d at %s" % [squad.name, squad.health, host.grid_name(squad.cell)])
	if host.mission_over():
		guest.ui_reset()
		await settle(host, guest)
		check(guest.mission_over(), "Guest cannot trigger the rematch")
		host.ui_reset()
		await settle(host, guest)
		check(not guest.mission_over() and guest.flow.stage == "INTRO" and host.state_hash() == guest.state_hash(), "Rematch resets both peers")
	host.queue_free()
	guest.queue_free()
	await process_frame
	print("ONLINE LOCKSTEP CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
