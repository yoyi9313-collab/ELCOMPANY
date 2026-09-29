extends Node2D
const MissionFlow = preload("res://scripts/mission_flow.gd")
const MissionPresentation = preload("res://scripts/mission_presentation.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
@export var mission_start_flow := true
var flow := MissionFlow.new()
var presentation: MissionPresentation
var feedback: CombatFeedback
var outcome_stats: Label
var outcome_values: Label
@export_range(0.0, 1.0) var camera_feedback_strength := 1.0
@export var audio_cues: Dictionary[String, AudioStream] = {}
const SoldierVisual = preload("res://scripts/soldier_visual.gd")
var soldier_visuals: Dictionary = {}
@export var imported_soldier_visuals := true
signal overwatch_triggered(watcher, target)
signal movement_finished(squad)
## Compact isometric squad tactics. All gameplay coordinates are grid cells.

const BOARD := 10
const HALF := Vector2(43, 22)
const ORIGIN := Vector2(640, 225)
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const INK := Color("e5e5cf")
const MUTED := Color("9fa99a")
const GOLD := Color("e1bf74")
const GREEN := Color("a8ce90")
const START := Vector2i(3, 7)
const SquadMember = preload("res://scripts/squad_member.gd")
const MEMBER_SCALE := 0.58
const COVER_PENALTY := 25
const VOLLEY_DURATION := 0.55

const SquadData = preload("res://scripts/squad_data.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const Terrain = preload("res://scripts/terrain_rules.gd")
const LOS = preload("res://scripts/line_of_sight.gd")
@export var show_los_debug := false
const Mission = preload("res://scripts/mission_state.gd")
@export var mission_enabled := true
var mission := Mission.new()
var objective_label: Label
var outcome_panel: Panel
var outcome_title: Label
var outcome_reason: Label
var restart_button: Button
const ENEMY_COLOR := Color("c78276")
var rangers := SquadData.new()
var rifle := preload("res://scripts/squad_profiles.gd").rifle_squad()
var machine_gun := preload("res://scripts/squad_profiles.gd").machine_gun_team()
var allies: Array[SquadData] = [rangers, rifle, machine_gun]
var active_squad: SquadData = rangers
const RIFLE_START := Vector2i(1, 7)
const MG_START := Vector2i(5, 9)
var enemy := SquadData.new(true)
var mg42 := preload("res://scripts/squad_profiles.gd").mg42_team()
var enemies: Array[SquadData] = [enemy, mg42]
var target_enemy: SquadData = enemy
var acting_enemy: SquadData = enemy
const MG42_START := Vector2i(6, 3)
var enemy_turn := false
var enemy_moving := false
var enemy_attack_used: bool:
	get: return enemy.attacks_this_turn >= enemy.max_attacks_per_turn
var ai_delay_scale := 1.0
var firing_squad: SquadData = active_squad
var combat_target: SquadData = enemy
# Compatibility accessors address the currently selected Allied squad.
var members: Array[SquadMember]:
	get: return active_squad.members
var squad_cell: Vector2i:
	get: return active_squad.cell
	set(value): active_squad.cell = value
var squad_position: Vector2:
	get: return active_squad.position
	set(value): active_squad.position = value
var selected := false
var moving := false
var turn_number := 1
var hovered := Vector2i(-1, -1)
var reachable: Dictionary = {}
var predecessors: Dictionary = {}
var preview: Array[Vector2i] = []
var cover: Dictionary = {}
var elapsed := 0.0
var status := "Select your squad to inspect movement range."
var status_label: Label
var moves_label: Label
var turn_label: Label
var phase_label: Label
var unit_label: Label
var unit_name_label: Label
var overwatch_help_label: Label
var position_label: Label
var end_button: Button
var reset_button: Button
var motion_tween: Tween
var attack_used: bool:
	get: return active_squad.attacks_this_turn >= active_squad.max_attacks_per_turn
var target_hovered := false
var target_pinned := false
var volley_left := 0.0
var result_left := 0.0
var last_result := ""
var suppression_text_left := 0.0
var traces: Array[Dictionary] = []
var combat_rng := RandomNumberGenerator.new()
var target_panel: Panel
var target_range_label: Label
var target_arc_label: Label
var target_los_label: Label
var target_chance_label: Label
var target_cover_label: Label
var target_direction_label: Label
var target_state_label: Label
var enemy_info_label: Label
var enemy_name_label: Label
var target_name_label: Label
var attack_state_label: Label
var suppression_duration_label: Label
var fire_button: Button
var overwatch_button: Button
var overwatch_preview := false
var overwatch_fire_left := 0.0
var reaction_label: Label
var rotate_left_button: Button
var rotate_right_button: Button
var flank_text := ""
const GrenadeRules = preload("res://scripts/grenade_rules.gd")
const GRENADE_FLIGHT := 0.8
const GRENADE_EXPLOSION := 0.5
var grenade_mode := false
var grenade_busy := false
var grenade_elapsed := 0.0
var grenade_center := Vector2i(-1, -1)
var grenade_origin := Vector2.ZERO
var grenade_results: Array[Dictionary] = []
var grenade_button: Button
var grenade_status_label: Label
var grenade_help_label: Label
var deployment_label: Label
const WATCH_COLOR := Color("91c8db")

func _ready() -> void:
	feedback = CombatFeedback.new()
	add_child(feedback)
	feedback.shake_strength = camera_feedback_strength
	feedback.rifle_sound = audio_cues.get("rifle")
	feedback.machine_gun_sound = audio_cues.get("machine_gun")
	feedback.grenade_sound = audio_cues.get("grenade")
	feedback.movement_sound = audio_cues.get("move")
	feedback.ui_sound = audio_cues.get("ui")
	if not mission_enabled or not mission_start_flow or "--capture-demo" in OS.get_cmdline_user_args():
		flow.stage = MissionFlow.BATTLE
	combat_rng.randomize()
	for cell in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(7, 6), Vector2i(7, 7), Vector2i(1, 5)]:
		cover[cell] = Terrain.properties("sandbags")
	for cell in [Vector2i(2, 2), Vector2i(7, 2), Vector2i(8, 3), Vector2i(4, 6), Vector2i(5, 6), Vector2i(2, 8)]:
		cover[cell] = Terrain.properties("crate")
	rifle.cell = RIFLE_START
	rifle.position = project_cell(rifle.cell)
	rifle.face_cell(enemy.cell)
	machine_gun.cell = MG_START
	machine_gun.position = project_cell(machine_gun.cell)
	machine_gun.face_cell(enemy.cell)
	squad_position = project_cell(squad_cell)
	enemy.position = project_cell(enemy.cell)
	mg42.cell = MG42_START
	mg42.position = project_cell(mg42.cell)
	mg42.face_cell(rangers.cell)
	build_hud()
	presentation = MissionPresentation.new()
	add_child(presentation)
	presentation.setup(self)
	if imported_soldier_visuals and DisplayServer.get_name() != "headless":
		for squad in all_squads():
			for index in squad.members.size():
				var member: SquadMember = squad.members[index]
				var visual := SoldierVisual.new()
				add_child(visual)
				visual.setup(squad.hostile, index, member, squad.position)
				visual.sync(squad, member, false, false, 0.0)
				soldier_visuals[member] = visual
	for squad in allies:
		squad.tactical_stats_changed.connect(rebuild_range)
	rebuild_range()
	refresh_hud()
	if "--capture-demo" in OS.get_cmdline_user_args():
		selected = true
		set_process(false)
		hovered = Vector2i(5, 5)
		preview = path_to(hovered)
		status = "Choose a highlighted tile. Cover blocks movement."
		if "--capture-rifle" in OS.get_cmdline_user_args():
			select_squad(rifle)
		if "--capture-mg" in OS.get_cmdline_user_args():
			select_squad(machine_gun)
		if "--capture-mg42" in OS.get_cmdline_user_args():
			select_squad(rifle)
			target_hostile(mg42, true)
		if "--capture-pinned" in OS.get_cmdline_user_args():
			select_squad(machine_gun)
			machine_gun.apply_suppression(2)
			rangers.apply_suppression(1)
			enemy.apply_suppression(2)
		if "--capture-grenade" in OS.get_cmdline_user_args():
			squad_cell = Vector2i(6, 1)
			squad_position = project_cell(squad_cell)
			rebuild_range()
			select_grenade()
			hovered = enemy.cell
			if "--capture-grenade-flight" in OS.get_cmdline_user_args():
				throw_grenade(enemy.cell)
				grenade_elapsed = GRENADE_FLIGHT * 0.5
			if "--capture-grenade-blast" in OS.get_cmdline_user_args():
				throw_grenade(enemy.cell)
				await get_tree().create_timer(GRENADE_FLIGHT + 0.05).timeout
				grenade_elapsed = GRENADE_FLIGHT + 0.15
		if "--capture-overwatch" in OS.get_cmdline_user_args():
			overwatch_preview = true
			preview.clear()
			status = "OVERWATCH [1 AP] — highlighted tiles are within reaction range."
		if "--capture-overwatch-fire" in OS.get_cmdline_user_args():
			squad_cell = Vector2i(3, 1)
			squad_position = project_cell(squad_cell)
			rebuild_range()
			activate_overwatch()
			set_process(true)
			next_turn()
			await overwatch_triggered
			await get_tree().create_timer(0.12).timeout
		if "--capture-combat" in OS.get_cmdline_user_args():
			squad_cell = Vector2i(6, 2)
			squad_position = project_cell(squad_cell)
			rebuild_range()
			preview.clear()
			target_pinned = true
			hovered = enemy.cell
			if "--capture-volley" in OS.get_cmdline_user_args():
				# Reproducible hit for visual QA only; normal gameplay stays random.
				for capture_seed in 100:
					combat_rng.seed = capture_seed
					if combat_rng.randf_range(0.0, 100.0) <= target_hit_chance():
						combat_rng.seed = capture_seed
						break
				attack_enemy()
				volley_left = VOLLEY_DURATION - 0.15
			if "--capture-casualty" in OS.get_cmdline_user_args():
				enemy.health = 220
				enemy.update_visuals(1.0 if "--settled" in OS.get_cmdline_user_args() else 0.38)
			if "--capture-enemy" in OS.get_cmdline_user_args():
				combat_rng.seed = 0
				set_process(true)
				next_turn()
				await get_tree().create_timer(0.55).timeout
		if "--capture-los-debug" in OS.get_cmdline_user_args():
			show_los_debug = true
		if "--capture-los-clear" in OS.get_cmdline_user_args():
			cover[Vector2i(7, 2)] = Terrain.properties("sandbags")
		if "--capture-mission-victory" in OS.get_cmdline_user_args():
			rangers.cell = Mission.ZONE[0]
			rangers.position = project_cell(rangers.cell)
			mission.capture_points = 1
			mission.end_allied_phase(turn_number, allies, enemies)
		if "--capture-mission-defeat" in OS.get_cmdline_user_args():
			turn_number = 8
			mission.end_german_phase(turn_number, allies, enemies)
		if "--capture-intro" in OS.get_cmdline_user_args():
			flow.stage = MissionFlow.INTRO
		if "--capture-deployment" in OS.get_cmdline_user_args():
			flow.stage = MissionFlow.INTRO
			start_mission()
		for squad in all_squads():
			for member in squad.members:
				if soldier_visuals.has(member):
					soldier_visuals[member].sync(squad, member, squad == firing_squad and volley_left > 0, false, 1.0, feedback.reaction(squad))
		refresh_hud()
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://demo-preview.png")
		get_tree().quit()

func combat_ready() -> bool:
	return flow.stage == MissionFlow.BATTLE and not mission_over()

func start_mission() -> void:
	if flow.stage != MissionFlow.INTRO: return
	flow.stage = MissionFlow.DEPLOYMENT
	feedback.cue("ui")
	select_squad(rangers)
	status = "DEPLOYMENT — select a squad, then confirm a highlighted tile."
	refresh_hud()

func place_deployment(squad: SquadData, cell: Vector2i) -> bool:
	if squad not in allies or not flow.can_place(squad, cell, all_squads(), cover):
		status = "Choose a free highlighted deployment tile."
		refresh_hud()
		return false
	squad.cell = cell
	squad.position = project_cell(cell)
	squad.face_cell(Vector2i(5, 4))
	flow.placed[squad] = true
	feedback.cue("ui")
	status = "%s placed at %s. %d / 3 squads ready." % [squad.name, grid_name(cell), flow.placed.size()]
	rebuild_range()
	refresh_hud()
	queue_redraw()
	return true

func begin_battle() -> void:
	if not flow.ready(allies): return
	flow.stage = MissionFlow.BATTLE
	for squad in allies: squad.begin_turn()
	selected = true
	status = "Secure the central zone. End two Allied phases there to capture it."
	feedback.cue("ui")
	presentation.announce_phase("ALLIED")
	rebuild_range()
	refresh_hud()

func all_squads() -> Array[SquadData]:
	var squads: Array[SquadData] = allies.duplicate()
	squads.append_array(enemies)
	return squads

func living_enemies() -> Array[SquadData]:
	return enemies.filter(func(squad: SquadData) -> bool: return squad.health > 0)

func hostile_at(point: Vector2) -> SquadData:
	for squad in living_enemies():
		if cell_at(point) == squad.cell or squad.hit_test(point):
			return squad
	return null

func target_hostile(squad: SquadData, pin: bool = false) -> void:
	if squad not in enemies or squad.health <= 0:
		return
	target_enemy = squad
	target_pinned = selected and pin
	refresh_hud()

func living_allies() -> Array[SquadData]:
	return allies.filter(func(squad: SquadData) -> bool: return squad.health > 0)

func mission_over() -> bool:
	return mission_enabled and mission.finished()

func check_mission() -> void:
	if not mission_enabled or flow.stage != MissionFlow.BATTLE:
		return
	mission.update_status(allies, enemies)
	mission.check_elimination(allies, enemies)
	if mission.finished():
		grenade_mode = false
		overwatch_preview = false
		preview.clear()

func objective_route_for(attacker: SquadData) -> Array[Vector2i]:
	if not mission_enabled or mission_over():
		return []
	var occupied: Array[Vector2i] = []
	for squad in all_squads():
		if squad != attacker and squad.health > 0:
			occupied.append(squad.cell)
	return EnemyAI.objective_route(attacker.cell, Mission.ZONE, attacker.ai_role == "support", attacker.effective_movement(), BOARD, cover, attacker.attack_range, occupied)

func occupied_by_other(cell: Vector2i, mover: SquadData) -> bool:
	for squad in all_squads():
		if squad != mover and squad.health > 0 and squad.cell == cell:
			return true
	return false

func friendly_at(point: Vector2) -> SquadData:
	for squad in living_allies():
		if cell_at(point) == squad.cell or squad.hit_test(point):
			return squad
	return null

func select_squad(squad: SquadData) -> void:
	if mission_over() or flow.stage == MissionFlow.INTRO:
		return
	if squad not in allies or squad.health <= 0 or enemy_turn or moving or grenade_busy or volley_left > 0.0:
		return
	active_squad = squad
	feedback.cue("ui")
	selected = true
	grenade_mode = false
	overwatch_preview = false
	target_pinned = false
	preview.clear()
	rebuild_range()
	status = "%s selected. %d AP remaining." % [squad.name, squad.action_points]
	refresh_hud()
	queue_redraw()

func enemy_target(attacker: SquadData = null) -> SquadData:
	if attacker == null:
		attacker = enemy
	var target: SquadData = null
	var best_score := 2147483647
	for squad in living_allies():
		var distance := EnemyAI.distance(attacker.cell, squad.cell)
		var score := distance + (10000 if not has_ai_shot(attacker, squad) else 0)
		if attacker.ai_role == "support":
			# A valid in-range shot outranks approaching a more attractive target.
			score += (1000 if squad_in_cover(squad) else 0) + squad.suppression * 100
		if target == null or score < best_score:
			target = squad
			best_score = score
	return target

func has_ai_shot(attacker: SquadData, target: SquadData) -> bool:
	# AI may freely face a chosen target before firing; the resolver enforces arc.
	return EnemyAI.distance(attacker.cell, target.cell) <= attacker.effective_attack_range() and has_line_of_sight(attacker, target)

func has_line_of_sight(attacker: SquadData, target: SquadData) -> bool:
	return LOS.is_clear(attacker.cell, target.cell, cover)

func project_cell(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2((cell.x - cell.y) * HALF.x, (cell.x + cell.y) * HALF.y)

func cell_at(point: Vector2) -> Vector2i:
	var relative := point - ORIGIN
	return Vector2i(roundi((relative.x / HALF.x + relative.y / HALF.y) / 2.0), roundi((relative.y / HALF.y - relative.x / HALF.x) / 2.0))

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BOARD and cell.y < BOARD

func rebuild_range() -> void:
	if flow.stage != MissionFlow.BATTLE:
		reachable.clear()
		predecessors.clear()
		return
	if active_squad.health <= 0:
		reachable.clear()
		predecessors.clear()
		return
	reachable = {squad_cell: 0}
	predecessors.clear()
	if not active_squad.can_perform("move"):
		return
	var frontier: Array[Vector2i] = [squad_cell]
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		if reachable[current] >= active_squad.effective_movement():
			continue
		for direction: Vector2i in DIRECTIONS:
			var next := current + direction
			if inside(next) and not Terrain.blocks_movement(cover.get(next)) and not occupied_by_other(next, active_squad) and not reachable.has(next):
				reachable[next] = reachable[current] + 1
				predecessors[next] = current
				frontier.append(next)

func path_to(destination: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not reachable.has(destination):
		return result
	var current := destination
	while current != squad_cell:
		result.push_front(current)
		current = predecessors[current]
	return result

func _process(delta: float) -> void:
	check_mission()
	elapsed += delta
	if grenade_busy:
		grenade_elapsed += delta
	for result in grenade_results:
		result.time -= delta
	grenade_results = grenade_results.filter(func(result: Dictionary) -> bool: return result.time > 0.0)
	for squad in all_squads():
		squad.update_visuals(delta)
		for member in squad.members:
			if soldier_visuals.has(member):
				soldier_visuals[member].sync(squad, member, squad == firing_squad and volley_left > 0.0, squad == active_squad and grenade_busy and grenade_elapsed < GRENADE_FLIGHT, delta, feedback.reaction(squad))
	if active_squad.health == 0:
		selected = false
		target_pinned = false
		rebuild_range()
	volley_left = maxf(0.0, volley_left - delta)
	result_left = maxf(0.0, result_left - delta)
	suppression_text_left = maxf(0.0, suppression_text_left - delta)
	overwatch_fire_left = maxf(0.0, overwatch_fire_left - delta)
	var ui_mouse := get_global_mouse_position()
	var mouse := ui_mouse - feedback.camera_offset
	var over_panel := target_panel.visible and target_panel.get_global_rect().has_point(ui_mouse)
	var hovered_enemy := hostile_at(mouse)
	if hovered_enemy != null and not enemy_turn and not grenade_mode:
		target_enemy = hovered_enemy
	target_hovered = hovered_enemy != null or (over_panel and target_enemy.health > 0)
	var new_hover := cell_at(mouse)
	if new_hover != hovered and not moving:
		hovered = new_hover
		preview.clear()
		if selected:
			preview = path_to(hovered)
	if target_hovered:
		preview.clear()
	refresh_hud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if flow.stage == MissionFlow.INTRO: return
	if flow.stage == MissionFlow.DEPLOYMENT:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_canvas_transform().affine_inverse() * event.position
			var friendly := friendly_at(point)
			if friendly != null and friendly != active_squad:
				select_squad(friendly)
			else:
				place_deployment(active_squad, cell_at(point))
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		show_los_debug = not show_los_debug
		queue_redraw()
		return
	if mission_over():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			reset_demo()
		return
	if enemy_turn or grenade_busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: next_turn()
			KEY_R: reset_demo()
			KEY_ESCAPE: deselect()
			KEY_Q: rotate_selected(-45.0)
			KEY_E: rotate_selected(45.0)
	if event is InputEventMouseButton and event.pressed and not moving and volley_left <= 0.0:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if grenade_mode:
				cancel_grenade()
				return
			var aim_cell := cell_at(get_canvas_transform().affine_inverse() * event.position - feedback.camera_offset)
			if selected and inside(aim_cell) and aim_cell != squad_cell:
				face_selected(aim_cell)
			else:
				deselect()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_canvas_transform().affine_inverse() * event.position - feedback.camera_offset
			var cell := cell_at(point)
			if grenade_mode:
				throw_grenade(cell)
				return
			if hostile_at(point) != null:
				target_hostile(hostile_at(point), true)
				status = "Target locked. Use FIRE SQUAD to attack." if selected else "Select an Allied squad before targeting the enemy."
				refresh_hud()
				return
			if friendly_at(point) != null:
				select_squad(friendly_at(point))
			elif selected and inside(cell):
				if Terrain.blocks_movement(cover.get(cell)):
					status = "Occupied by cover. Choose a clear tile."
				elif reachable.has(cell):
					move_to(cell)
				else:
					status = "NO AP — start the next turn." if active_squad.action_points == 0 else "Outside this move's range. Choose a highlighted tile."
				refresh_hud()

func deselect() -> void:
	if moving or enemy_turn or grenade_busy:
		return
	if grenade_mode:
		cancel_grenade()
		return
	selected = false
	target_pinned = false
	preview.clear()
	status = "Select your squad to inspect movement range."
	refresh_hud()

func can_rotate() -> bool:
	return combat_ready() and selected and active_squad.health > 0 and not enemy_turn and not moving and not grenade_busy and not grenade_mode and volley_left <= 0.0

func rotate_selected(degrees: float) -> void:
	if not can_rotate():
		return
	active_squad.face_direction(active_squad.facing.rotated(deg_to_rad(degrees)))
	status = "Facing adjusted — free action. Q/E rotate; right-click a tile to aim."
	refresh_hud()
	queue_redraw()

func face_selected(cell: Vector2i) -> void:
	if not can_rotate():
		return
	active_squad.face_cell(cell)
	status = "Facing %s — free action." % grid_name(cell)
	refresh_hud()
	queue_redraw()

func move_to(destination: Vector2i) -> void:
	if not combat_ready():
		return
	if grenade_mode or grenade_busy:
		return
	if moving or enemy_turn or volley_left > 0.0 or not selected or not active_squad.can_perform("move"):
		return
	var route := path_to(destination)
	if route.is_empty():
		return
	if route.size() > active_squad.effective_movement() or not active_squad.spend_action("move"):
		return
	moving = true
	target_pinned = false
	preview.clear()
	status = "Moving to grid %s…" % grid_name(destination)
	refresh_hud()
	var mover := active_squad
	var steps_moved := 0
	for cell in route:
		if mission_over() or mover.health <= 0 or steps_moved >= mover.effective_movement():
			break
		mover.face_cell(cell)
		motion_tween = create_tween()
		motion_tween.tween_property(mover, "position", project_cell(cell), 0.19).set_trans(Tween.TRANS_SINE)
		await motion_tween.finished
		mover.cell = cell
		feedback.cue("move")
		steps_moved += 1
		for watcher in living_enemies():
			if mover.health <= 0:
				break
			await try_overwatch(watcher, mover)
	moving = false
	rebuild_range()
	status = "Squad eliminated during movement." if mover.health <= 0 else ("Movement interrupted — PINNED." if mover.is_pinned() else "In position. %d AP remaining." % mover.action_points)
	refresh_hud()
	movement_finished.emit(mover)

func next_turn() -> void:
	if not combat_ready():
		return
	if grenade_busy:
		return
	grenade_mode = false
	if moving or enemy_turn or volley_left > 0.0 or living_allies().is_empty():
		return
	for squad in allies:
		squad.end_turn()
	if mission_enabled:
		mission.end_allied_phase(turn_number, allies, enemies)
		if mission_over():
			refresh_hud()
			return
	enemy_turn = true
	presentation.announce_phase("GERMAN")
	preview.clear()
	target_pinned = false
	for squad in living_enemies():
		begin_squad_turn(squad)
	suppression_text_left = 0.0
	status = "ENEMY TURN — German squads assessing the battlefield."
	refresh_hud()
	await get_tree().create_timer(0.4 * ai_delay_scale).timeout
	for squad in living_enemies():
		if mission_over() or living_allies().is_empty():
			break
		await run_enemy_turn(squad)
	for squad in enemies:
		squad.end_turn()
	enemy_turn = false
	if mission_enabled:
		mission.end_german_phase(turn_number, allies, enemies)
		if mission_over():
			refresh_hud()
			return
	turn_number += 1
	presentation.announce_phase("ALLIED")
	for squad in living_allies():
		begin_squad_turn(squad)
	rebuild_range()
	preview.clear()
	if selected:
		preview = path_to(hovered)
	status = "Allied squads eliminated. Reset to play again." if living_allies().is_empty() else "ALLIED TURN — each surviving squad has 2 AP."
	refresh_hud()

func run_enemy_turn(attacker: SquadData) -> void:
	acting_enemy = attacker
	while not mission_over() and attacker.health > 0 and not living_allies().is_empty() and attacker.action_points > 0:
		var target := enemy_target(attacker)
		var objective_path := objective_route_for(attacker)
		var contest_first := attacker.ai_role != "support" and not objective_path.is_empty()
		if not contest_first and has_ai_shot(attacker, target) and attacker.can_perform("fire"):
			# A simple free turn toward the existing target, never a flank search.
			attacker.face_cell(target.cell)
			await get_tree().create_timer(0.2 * ai_delay_scale).timeout
			attacker.spend_action("fire")
			resolve_squad_attack(attacker, target, attacker.base_hit_chance, attacker.minimum_damage, attacker.maximum_damage, attacker.effective_attack_range())
			await get_tree().create_timer(VOLLEY_DURATION + 0.45 * ai_delay_scale).timeout
			volley_left = 0.0
			break
		elif (contest_first or not has_ai_shot(attacker, target)) and attacker.can_perform("move") and not (attacker.ai_role == "support" and attacker.moved_this_turn):
			var occupied: Array[Vector2i] = []
			for squad in all_squads():
				if squad != attacker and squad.health > 0:
					occupied.append(squad.cell)
			# Moving forfeits setup range; plan using the post-move profile.
			var route := objective_path if mission_enabled else EnemyAI.plan(attacker.cell, target.cell, attacker.effective_movement(), BOARD, cover, attacker.attack_range, occupied)
			if not route.is_empty() and attacker.spend_action("move"):
				enemy_moving = true
				status = "ENEMY TURN — %s moving to %s." % [attacker.name, grid_name(route[-1])]
				refresh_hud()
				var steps_moved := 0
				for cell in route:
					if mission_over() or attacker.health <= 0 or steps_moved >= attacker.effective_movement():
						break
					var movement_tween := create_tween()
					attacker.face_cell(cell)
					movement_tween.tween_property(attacker, "position", project_cell(cell), 0.23 * ai_delay_scale).set_trans(Tween.TRANS_SINE)
					await movement_tween.finished
					attacker.cell = cell
					feedback.cue("move")
					steps_moved += 1
					# Resolve reactions on every entered tile, before advancing again.
					for watcher in living_allies():
						if attacker.health <= 0:
							break
						if watcher.can_react():
							enemy_moving = false
							await try_overwatch(watcher, attacker)
							enemy_moving = attacker.health > 0
				enemy_moving = false
				rebuild_range()
				await get_tree().create_timer(0.35 * ai_delay_scale).timeout
				continue
		if attacker.ai_role == "support" and attacker.can_perform("overwatch"):
			attacker.face_cell(target.cell)
			attacker.spend_action("overwatch")
			status = "ENEMY TURN — %s covering the Allied approach." % attacker.name
			refresh_hud()
			await get_tree().create_timer(0.35 * ai_delay_scale).timeout
			break
		status = "ENEMY TURN — no action available."
		refresh_hud()
		await get_tree().create_timer(0.35 * ai_delay_scale).timeout
		break

func begin_squad_turn(squad: SquadData) -> void:
	squad.begin_turn()
	if squad in allies:
		rebuild_range()

func reset_demo() -> void:
	if moving or enemy_turn or grenade_busy:
		return
	mission = Mission.new()
	flow = MissionFlow.new()
	if not mission_enabled or not mission_start_flow: flow.stage = MissionFlow.BATTLE
	feedback.reset()
	presentation.reset()
	grenade_mode = false
	grenade_results.clear()
	active_squad = rangers
	squad_cell = START
	rifle.cell = RIFLE_START
	rifle.position = project_cell(rifle.cell)
	squad_position = project_cell(squad_cell)
	machine_gun.cell = MG_START
	machine_gun.position = project_cell(machine_gun.cell)
	turn_number = 1
	target_pinned = false
	target_hovered = false
	volley_left = 0.0
	result_left = 0.0
	suppression_text_left = 0.0
	overwatch_preview = false
	overwatch_fire_left = 0.0
	last_result = ""
	traces.clear()
	enemy.cell = Vector2i(8, 1)
	enemy.position = project_cell(enemy.cell)
	mg42.cell = MG42_START
	mg42.position = project_cell(mg42.cell)
	target_enemy = enemy
	firing_squad = active_squad
	combat_target = enemy
	for squad in enemies:
		squad.restore()
		squad.face_cell(rangers.cell)
	for squad in allies:
		squad.restore()
		squad.face_cell(enemy.cell)
	enemy.face_cell(active_squad.cell)
	flank_text = ""
	selected = false
	preview.clear()
	rebuild_range()
	status = "Select your squad to inspect movement range."
	refresh_hud()

func grid_name(cell: Vector2i) -> String:
	return "%s%d" % [char(65 + cell.x), cell.y + 1]

func living_members() -> Array[SquadMember]:
	return active_squad.living_members()

func member_position(member: SquadMember) -> Vector2:
	return active_squad.member_position(member)

func squad_hit_test(point: Vector2) -> bool:
	return active_squad.hit_test(point)

func in_cover() -> bool:
	return squad_in_cover(active_squad)

func squad_in_cover(squad: SquadData) -> bool:
	return Terrain.adjacent_cover(squad.cell, cover) > 0

func enemy_occupies(cell: Vector2i) -> bool:
	for squad in living_enemies():
		if squad.cell == cell:
			return true
	return false

func target_distance() -> int:
	# Same orthogonal grid steps used by movement; cover does not alter range.
	return EnemyAI.distance(squad_cell, target_enemy.cell)

func target_hit_chance() -> float:
	return shot_chance(active_squad, target_enemy, active_squad.base_hit_chance)

func attack_block_reason() -> String:
	if flow.stage != MissionFlow.BATTLE: return "DEPLOY BEFORE COMBAT"
	if mission_over():
		return "MISSION COMPLETE"
	if grenade_busy or grenade_mode:
		return "GRENADE ACTION"
	if enemy_turn:
		return "ENEMY TURN"
	if target_enemy.health <= 0:
		return "TARGET ELIMINATED"
	if not selected:
		return "SELECT AN ALLIED SQUAD"
	if moving:
		return "SQUAD MOVING"
	if volley_left > 0.0:
		return "FIRING"
	if target_distance() > active_squad.effective_attack_range():
		return "OUT OF RANGE"
	if not active_squad.in_firing_arc(target_enemy.cell):
		return "OUT OF ARC"
	if not has_line_of_sight(active_squad, target_enemy):
		return "NO LINE OF SIGHT"
	if active_squad.action_points == 0:
		return "NO ACTION POINTS"
	if attack_used:
		return "ATTACK SPENT"
	if not active_squad.can_perform("fire"):
		return "ATTACK RESERVED"
	if living_members().is_empty():
		return "NO ACTIVE MEMBERS"
	return ""

func attack_enemy() -> void:
	var blocked := attack_block_reason()
	if not blocked.is_empty():
		status = blocked
		refresh_hud()
		return
	# Exactly one random roll and one damage application per squad volley.
	if not active_squad.spend_action("fire"):
		return
	target_pinned = true
	resolve_squad_attack(active_squad, target_enemy, active_squad.base_hit_chance, active_squad.minimum_damage, active_squad.maximum_damage, active_squad.effective_attack_range())

func cover_penalty(attacker: SquadData, target: SquadData) -> float:
	if not squad_in_cover(target):
		return 0.0
	match target.incoming_sector(attacker.cell):
		"REAR": return 0.0
		"FLANK": return COVER_PENALTY * 0.5
	return float(COVER_PENALTY)

func shot_chance(attacker: SquadData, target: SquadData, base_chance: int) -> float:
	return clampf(base_chance + attacker.deployment_accuracy_bonus() - cover_penalty(attacker, target) - pinned_cover_penalty(target) - attacker.accuracy_penalty(), 0.0, 100.0)

func pinned_cover_penalty(target: SquadData) -> int:
	return 10 if target.is_pinned() and squad_in_cover(target) else 0

func resolve_squad_attack(attacker: SquadData, target: SquadData, base_chance: int, minimum_damage: int, maximum_damage: int, range_limit: int = -1) -> void:
	if not combat_ready():
		return
	if range_limit < 0:
		range_limit = attacker.effective_attack_range()
	if attacker.health <= 0 or target.health <= 0 or EnemyAI.distance(attacker.cell, target.cell) > range_limit:
		return
	if not attacker.in_firing_arc(target.cell):
		return
	if not has_line_of_sight(attacker, target):
		return
	firing_squad = attacker
	combat_target = target
	var hit := combat_rng.randf_range(0.0, 100.0) < shot_chance(attacker, target, base_chance)
	var sector := target.incoming_sector(attacker.cell)
	flank_text = "REAR ATTACK" if sector == "REAR" else ("FLANKED" if sector == "FLANK" else "")
	traces.clear()
	volley_left = VOLLEY_DURATION
	var heavy := attacker.suppression_on_hit == 2
	feedback.cue("machine_gun" if heavy else "rifle")
	if heavy: feedback.shake(1.5, 0.3)
	for member in attacker.living_members():
		var muzzle := attacker.member_position(member) + muzzle_offset(member)
		if soldier_visuals.has(member):
			muzzle = attacker.member_position(member) + soldier_visuals[member].muzzle_screen_offset()
		var endpoint := target.position + Vector2(member.offset.x * 0.7, -17 + member.offset.y * 0.4)
		if not hit:
			endpoint += Vector2(26, -28)
		traces.append({"from": muzzle, "to": endpoint})
		var impact_point := endpoint if hit else target.position + Vector2(member.offset.x, 3 + member.offset.y * 0.3)
		var on_cover := false
		if not hit:
			for direction in DIRECTIONS:
				if cover.has(target.cell + direction):
					impact_point = project_cell(target.cell + direction) + Vector2(member.offset.x * 0.3, -14)
					on_cover = true
					break
			traces[-1]["to"] = impact_point
		feedback.impact(impact_point, on_cover, 0.10 + traces.size() * 0.045)
	result_left = 1.8
	if hit:
		var rolled_damage := combat_rng.randi_range(minimum_damage, maximum_damage)
		rolled_damage = target.incoming_damage(rolled_damage, attacker.cell)
		var damage := mini(rolled_damage, target.health)
		var previous_members := target.living_members().size()
		target.health = maxi(0, target.health - rolled_damage)
		feedback.hit(target, target.living_members().size() < previous_members)
		target.apply_suppression(attacker.suppression_on_hit)
		suppression_text_left = 1.8
		last_result = "HIT  −%d" % damage
		status = "%s hit: %d damage. %s: %d / %d HP." % [attacker.name, damage, target.name, target.health, target.max_health]
		if target.health == 0:
			last_result = "−%d  /  ELIMINATED" % damage
			status = "%s eliminated." % target.name
			rebuild_range()
	else:
		last_result = "MISS"
		status = "%s volley missed. No damage." % attacker.name
		if attacker.suppression_on_miss > 0:
			target.apply_suppression(attacker.suppression_on_miss)
			suppression_text_left = 1.8
			status += " Target suppressed."
	check_mission()
	refresh_hud()
	queue_redraw()

func activate_overwatch() -> void:
	if not combat_ready():
		return
	if grenade_busy or grenade_mode:
		return
	if enemy_turn or moving or volley_left > 0.0 or not selected:
		return
	if not active_squad.spend_action("overwatch"):
		return
	overwatch_preview = false
	preview.clear()
	status = "OVERWATCH active: one reaction shot during enemy movement."
	refresh_hud()
	queue_redraw()

func try_overwatch(watcher: SquadData, target: SquadData) -> bool:
	if not combat_ready(): return false
	if mission_over():
		return false
	if watcher.hostile == target.hostile or target.health <= 0 or not watcher.can_react():
		return false
	if EnemyAI.distance(watcher.cell, target.cell) > watcher.effective_overwatch_range():
		return false
	if not watcher.in_firing_arc(target.cell):
		return false
	if not has_line_of_sight(watcher, target):
		return false
	if not watcher.consume_overwatch_shot():
		return false
	var base := watcher.base_hit_chance
	resolve_squad_attack(watcher, target, base - watcher.overwatch_accuracy_penalty, watcher.minimum_damage, watcher.maximum_damage, watcher.effective_overwatch_range())
	overwatch_fire_left = VOLLEY_DURATION + 0.4
	status = "OVERWATCH FIRE — " + status
	overwatch_triggered.emit(watcher, target)
	refresh_hud()
	await get_tree().create_timer(VOLLEY_DURATION + 0.3 * ai_delay_scale).timeout
	volley_left = 0.0
	return true

func can_select_grenade() -> bool:
	return combat_ready() and selected and not enemy_turn and not moving and not grenade_busy and volley_left <= 0.0 and active_squad.can_perform("grenade")

func valid_grenade_tile(cell: Vector2i) -> bool:
	return inside(cell) and GrenadeRules.distance(squad_cell, cell) <= GrenadeRules.RANGE

func select_grenade() -> void:
	if grenade_mode:
		cancel_grenade()
		return
	if not can_select_grenade():
		return
	grenade_mode = true
	overwatch_preview = false
	target_pinned = false
	preview.clear()
	status = "GRENADE: hover to preview; click a tile to throw. ESC cancels."
	refresh_hud()
	queue_redraw()

func cancel_grenade() -> void:
	grenade_mode = false
	status = "Grenade cancelled. Choose your next action."
	refresh_hud()
	queue_redraw()

func throw_grenade(cell: Vector2i) -> void:
	if not grenade_mode or not can_select_grenade():
		return
	if not valid_grenade_tile(cell):
		status = "GRENADE OUT OF RANGE — choose a tile within 2 steps."
		refresh_hud()
		return
	if not active_squad.spend_action("grenade"):
		return
	grenade_mode = false
	grenade_busy = true
	grenade_elapsed = 0.0
	grenade_center = cell
	grenade_origin = active_squad.member_position(active_squad.living_members()[0]) + Vector2(0, -23)
	preview.clear()
	status = "GRENADE AWAY!"
	refresh_hud()
	await get_tree().create_timer(GRENADE_FLIGHT).timeout
	grenade_elapsed = GRENADE_FLIGHT
	resolve_grenade(cell)
	await get_tree().create_timer(GRENADE_EXPLOSION).timeout
	grenade_busy = false
	rebuild_range()
	status = "GRENADE SPENT — choose your next action." if active_squad.health > 0 else "Squad eliminated. Select another surviving Allied squad."
	refresh_hud()

func resolve_grenade(center: Vector2i) -> void:
	if not combat_ready():
		return
	feedback.shake(3.2, 0.45)
	feedback.focus(project_cell(center))
	feedback.cue("grenade")
	var blast := GrenadeRules.blast_cells(center, BOARD)
	for squad in all_squads():
		if squad.health <= 0 or not blast.has(squad.cell):
			continue
		var direct: bool = squad.cell == center
		var rolled := combat_rng.randi_range(GrenadeRules.DIRECT_MIN, GrenadeRules.DIRECT_MAX) if direct else combat_rng.randi_range(GrenadeRules.ADJACENT_MIN, GrenadeRules.ADJACENT_MAX)
		var dealt := mini(squad.health, GrenadeRules.damage(rolled, squad.cell, cover))
		squad.health -= dealt
		feedback.hit(squad, true)
		for point in (2 if direct else 1):
			squad.apply_suppression()
		grenade_results.append({"position": squad.position, "damage": dealt, "time": 2.0, "state": squad.suppression_state()})
	check_mission()
	rebuild_range()
	refresh_hud()

func grenade_point(progress: float) -> Vector2:
	return grenade_origin.lerp(project_cell(grenade_center), progress) + Vector2(0, -sin(progress * PI) * 90.0)

func draw_grenade() -> void:
	if grenade_busy:
		if grenade_elapsed < GRENADE_FLIGHT:
			var progress := clampf(grenade_elapsed / GRENADE_FLIGHT, 0.0, 1.0)
			var trajectory := PackedVector2Array()
			for i in 25:
				trajectory.append(grenade_point(float(i) / 24.0 * progress))
			draw_polyline(trajectory, Color(GOLD, 0.65), 2.0, true)
			draw_circle(grenade_point(progress), 5, Color("303c28"))
			draw_arc(grenade_point(progress), 5, 0, TAU, 16, GOLD, 1.5, true)
			# One representative member throws on behalf of the whole squad.
			var hand := grenade_origin + Vector2(sin(progress * PI) * 15, -12 * sin(progress * PI))
			draw_line(grenade_origin + Vector2(-3, 5), hand, Color("b2a379"), 4, true)
		else:
			var progress := clampf((grenade_elapsed - GRENADE_FLIGHT) / GRENADE_EXPLOSION, 0.0, 1.0)
			var center := project_cell(grenade_center)
			paint_ellipse(center, Vector2(65, 33) * (0.3 + progress), Color(0.9, 0.55, 0.18, 0.65 * (1.0 - progress)))
			draw_circle(center + Vector2(0, -12), 15 + progress * 34, Color(1.0, 0.78, 0.35, 1.0 - progress))
			for i in 10:
				var direction := Vector2.RIGHT.rotated(TAU * i / 10.0)
				draw_line(center + direction * progress * 30, center + direction * progress * 65, Color(GOLD, 1.0 - progress), 2.0, true)
	for result in grenade_results:
		var pos: Vector2 = result.position + Vector2(-46, -115 - (2.0 - result.time) * 12)
		draw_string(ThemeDB.fallback_font, pos, "−%d HP" % result.damage, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
		draw_string(ThemeDB.fallback_font, pos + Vector2(0, 18), result.state, HORIZONTAL_ALIGNMENT_LEFT, -1, 14 if result.state == "PINNED" else 12, ENEMY_COLOR if result.state == "PINNED" else GOLD)

func muzzle_offset(member: SquadMember) -> Vector2:
	var tip := Vector2(29, -34)
	match member.weapon:
		"M1 Garand": tip = Vector2(28, -49)
		"BAR": tip = Vector2(38, -40)
		"M1 Carbine": tip = Vector2(22, -40)
		"MP40": tip = Vector2(29, -33)
		"Kar98k": tip = Vector2(30, -51)
		"MG42": tip = Vector2(45, -39)
		"M1919": tip = Vector2(44, -27)
	return tip * Vector2(MEMBER_SCALE * firing_facing(member), MEMBER_SCALE)

func firing_facing(member: SquadMember) -> float:
	return absf(member.facing) * (1.0 if combat_target.position.x >= firing_squad.position.x else -1.0)

func label_at(parent: Node, text_value: String, position_value: Vector2, size_value: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("66715a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	label_at(layer, "FIELD OPERATIONS  /  TACTICAL SANDBOX", Vector2(38, 22), 13, GOLD)
	label_at(layer, "SECURE THE HEDGEROW", Vector2(36, 42), 30)
	label_at(layer, "NORMANDY, 1944     /     ALLIED PATROL", Vector2(39, 88), 13, MUTED)
	turn_label = label_at(layer, "", Vector2(1080, 30), 22, GOLD)
	phase_label = label_at(layer, "ALLIED PHASE", Vector2(1081, 63), 12, MUTED)
	objective_label = label_at(layer, "", Vector2(620, 22), 14, GOLD)
	reaction_label = label_at(layer, "OVERWATCH FIRE", Vector2(620, 92), 16, WATCH_COLOR)
	label_at(layer, "01  /  RECON SECTOR", Vector2(39, 146), 15, GOLD)
	label_at(layer, "Hold the central zone.\nEnd two Allied phases there.\nKeep German squads out.", Vector2(39, 176), 15, MUTED)
	overwatch_button = Button.new()
	overwatch_button.text = "OVERWATCH [1 AP]"
	overwatch_button.position = Vector2(39, 267)
	overwatch_button.size = Vector2(210, 40)
	overwatch_button.focus_mode = Control.FOCUS_ALL
	overwatch_button.add_theme_stylebox_override("normal", button_style(Color("29414a")))
	overwatch_button.add_theme_stylebox_override("hover", button_style(Color("3c5964")))
	overwatch_button.add_theme_stylebox_override("focus", button_style(Color("3c5964")))
	overwatch_button.pressed.connect(activate_overwatch)
	overwatch_button.mouse_entered.connect(func(): overwatch_preview = true)
	overwatch_button.mouse_exited.connect(func(): overwatch_preview = false)
	overwatch_button.focus_entered.connect(func(): overwatch_preview = true)
	overwatch_button.focus_exited.connect(func(): overwatch_preview = false)
	layer.add_child(overwatch_button)
	overwatch_help_label = label_at(layer, "Hover to preview the 3-tile range.\nOne shot · −15% accuracy", Vector2(39, 315), 12, MUTED)
	rotate_left_button = Button.new()
	rotate_left_button.text = "Q   LEFT"
	rotate_left_button.position = Vector2(39, 364)
	rotate_left_button.size = Vector2(99, 31)
	rotate_left_button.focus_mode = Control.FOCUS_NONE
	rotate_left_button.pressed.connect(rotate_selected.bind(-45.0))
	layer.add_child(rotate_left_button)
	rotate_right_button = Button.new()
	rotate_right_button.text = "RIGHT   E"
	rotate_right_button.position = Vector2(145, 364)
	rotate_right_button.size = Vector2(104, 31)
	rotate_right_button.focus_mode = Control.FOCUS_NONE
	rotate_right_button.pressed.connect(rotate_selected.bind(45.0))
	layer.add_child(rotate_right_button)
	for button in [rotate_left_button, rotate_right_button]:
		button.add_theme_stylebox_override("normal", button_style(Color("293b35")))
		button.add_theme_stylebox_override("hover", button_style(Color("42574b")))
	label_at(layer, "FREE · right-click a tile to face it", Vector2(39, 399), 11, MUTED)
	grenade_button = Button.new()
	grenade_button.text = "GRENADE [1 AP]"
	grenade_button.position = Vector2(39, 443)
	grenade_button.size = Vector2(210, 38)
	grenade_button.focus_mode = Control.FOCUS_NONE
	grenade_button.add_theme_stylebox_override("normal", button_style(Color("634b37")))
	grenade_button.add_theme_stylebox_override("hover", button_style(Color("826440")))
	grenade_button.pressed.connect(select_grenade)
	layer.add_child(grenade_button)
	grenade_status_label = label_at(layer, "GRENADE READY", Vector2(39, 487), 13, GOLD)
	grenade_help_label = label_at(layer, "Range 2 · blast + 4 neighbors\nAffects allies too\nSandbags −25% / crates −10%", Vector2(39, 511), 11, MUTED)
	deployment_label = label_at(layer, "", Vector2(39, 443), 13, GOLD)
	label_at(layer, "BATTLEFIELD KEY", Vector2(1035, 147), 13, GOLD)
	label_at(layer, "◈  Reachable ground\n•  Planned route\n▰  Sandbag / crate cover", Vector2(1035, 179), 14, MUTED)
	enemy_name_label = label_at(layer, "HOSTILE / GRENADIERS", Vector2(1035, 275), 15, ENEMY_COLOR)
	enemy_info_label = label_at(layer, "", Vector2(1035, 302), 12, MUTED)
	target_panel = Panel.new()
	target_panel.position = Vector2(1030, 375)
	target_panel.size = Vector2(220, 278)
	target_panel.add_theme_stylebox_override("panel", button_style(Color("1b2823")))
	layer.add_child(target_panel)
	target_name_label = label_at(target_panel, "TARGET: GRENADIERS", Vector2(12, 12), 15, ENEMY_COLOR)
	target_range_label = label_at(target_panel, "", Vector2(12, 40), 14)
	target_arc_label = label_at(target_panel, "", Vector2(12, 62), 13)
	target_los_label = label_at(target_panel, "", Vector2(12, 84), 13)
	target_cover_label = label_at(target_panel, "", Vector2(12, 106), 13, MUTED)
	target_chance_label = label_at(target_panel, "", Vector2(12, 128), 14)
	target_direction_label = label_at(target_panel, "", Vector2(12, 150), 13, GOLD)
	target_state_label = label_at(target_panel, "", Vector2(12, 174), 14, GOLD)
	fire_button = Button.new()
	fire_button.position = Vector2(12, 204)
	fire_button.size = Vector2(196, 38)
	fire_button.text = "FIRE [1 AP] / 80–110"
	fire_button.focus_mode = Control.FOCUS_NONE
	fire_button.add_theme_stylebox_override("normal", button_style(Color("634b37")))
	fire_button.add_theme_stylebox_override("hover", button_style(Color("826440")))
	fire_button.pressed.connect(attack_enemy)
	target_panel.add_child(fire_button)
	label_at(target_panel, "Max 1 attack / turn · costs 1 AP", Vector2(12, 252), 11, MUTED)
	unit_name_label = label_at(layer, "U.S. RANGERS", Vector2(42, 680), 20)
	unit_label = label_at(layer, "", Vector2(43, 711), 14, MUTED)
	position_label = label_at(layer, "", Vector2(690, 686), 13, MUTED)
	attack_state_label = label_at(layer, "", Vector2(690, 710), 12, GOLD)
	suppression_duration_label = label_at(layer, "", Vector2(39, 578), 11, GOLD)
	moves_label = label_at(layer, "", Vector2(427, 682), 19, GREEN)
	status_label = label_at(layer, "", Vector2(427, 730), 14, MUTED)
	status_label.size = Vector2(550, 42)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_button = Button.new()
	end_button.text = "NEXT TURN   [SPACE]"
	end_button.position = Vector2(1040, 682)
	end_button.size = Vector2(204, 43)
	end_button.add_theme_stylebox_override("normal", button_style(Color("3e4b35")))
	end_button.add_theme_stylebox_override("hover", button_style(Color("566447")))
	end_button.add_theme_stylebox_override("pressed", button_style(Color("293525")))
	end_button.add_theme_color_override("font_color", INK)
	end_button.focus_mode = Control.FOCUS_NONE
	end_button.pressed.connect(next_turn)
	layer.add_child(end_button)
	reset_button = Button.new()
	reset_button.text = "RESET EXERCISE  [R]"
	reset_button.position = Vector2(1040, 737)
	reset_button.size = Vector2(204, 28)
	reset_button.flat = true
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.add_theme_color_override("font_color", MUTED)
	reset_button.pressed.connect(reset_demo)
	layer.add_child(reset_button)
	label_at(layer, "LEFT CLICK  Select / move    •    Q/E  Rotate    •    RIGHT CLICK  Face tile    •    ESC  Deselect    •    F3  LOS debug", Vector2(39, 774), 12, MUTED)
	var outcome_layer := CanvasLayer.new()
	outcome_layer.layer = 10
	add_child(outcome_layer)
	outcome_panel = Panel.new()
	outcome_panel.position = Vector2(340, 165)
	outcome_panel.size = Vector2(600, 458)
	outcome_panel.add_theme_stylebox_override("panel", button_style(Color("17271f")))
	outcome_layer.add_child(outcome_panel)
	label_at(outcome_panel, "SECURE THE HEDGEROW", Vector2(30, 24), 18, GOLD)
	outcome_title = label_at(outcome_panel, "", Vector2(30, 65), 30)
	outcome_reason = label_at(outcome_panel, "", Vector2(30, 113), 16, MUTED)
	outcome_reason.size = Vector2(505, 65)
	outcome_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outcome_stats = label_at(outcome_panel, "", Vector2(30, 202), 18, INK)
	outcome_values = label_at(outcome_panel, "", Vector2(430, 202), 18, GOLD)
	restart_button = Button.new()
	restart_button.position = Vector2(30, 388)
	restart_button.size = Vector2(540, 42)
	restart_button.text = "RESTART MISSION [R]"
	restart_button.pressed.connect(reset_demo)
	outcome_panel.add_child(restart_button)

func refresh_hud() -> void:
	if not is_instance_valid(status_label):
		return
	turn_label.text = "TURN %d / 8" % turn_number if mission_enabled else ("ENEMY TURN" if enemy_turn else "TURN  %02d" % turn_number)
	phase_label.text = "MISSION COMPLETE" if mission_over() else ("ENEMY TURN" if enemy_turn else "ALLIED PHASE")
	if mission_enabled and enemy_turn: phase_label.text = "GERMAN PHASE"
	objective_label.visible = mission_enabled
	mission.update_status(allies, enemies)
	objective_label.text = "OBJECTIVE: SECURE THE HEDGEROW\nSTATUS: %s\nCAPTURE: %d/2" % [mission.objective_status, mission.capture_points]
	outcome_panel.visible = mission_over()
	outcome_title.text = "ALLIED VICTORY" if mission.winner == "ALLIED" else "DEFEAT — GERMAN VICTORY"
	outcome_title.add_theme_color_override("font_color", GREEN if mission.winner == "ALLIED" else ENEMY_COLOR)
	outcome_reason.text = mission.reason + "\nCapture: %d/2 · Turn %d/8" % [mission.capture_points, turn_number]
	var report := MissionFlow.summary(mission, turn_number, allies, enemies)
	outcome_stats.text = "RESULT\nTURNS USED\nALLIED SQUADS SURVIVING\nALLIED CASUALTIES\nENEMY SQUADS DESTROYED"
	outcome_values.text = "%s\n%d / 8\n%d / %d\n%d\n%d / %d" % [report.result, report.turns, report.survivors, allies.size(), report.casualties, report.destroyed, enemies.size()]
	restart_button.disabled = moving or enemy_turn or grenade_busy or volley_left > 0.0
	moves_label.text = "ACTION POINTS: " + "● ".repeat(active_squad.action_points) + "○ ".repeat(2 - active_squad.action_points)
	unit_name_label.text = active_squad.name
	overwatch_help_label.text = "Hover to preview the %d-tile arc.\nOne shot · −%d%% accuracy" % [active_squad.effective_overwatch_range(), active_squad.overwatch_accuracy_penalty]
	fire_button.text = "FIRE [1 AP] / %d–%d" % [active_squad.minimum_damage, active_squad.maximum_damage]
	unit_label.text = "%s / %d MEN" % [active_squad.type, living_members().size()]
	if active_squad.stationary_range_bonus > 0:
		unit_label.text += " · " + ("PINNED" if active_squad.is_pinned() else ("DEPLOYED" if active_squad.is_deployed() else "MOVED"))
	position_label.text = "%s / %s / HP %d/%d" % [grid_name(squad_cell), "IN COVER" if in_cover() else "EXPOSED", active_squad.health, active_squad.max_health]
	status_label.text = status
	attack_state_label.text = "%s %d/2 · MOVE %d TILES" % [active_squad.suppression_state(), active_squad.suppression, active_squad.effective_movement()]
	suppression_duration_label.text = active_squad.suppression_duration_text()
	suppression_duration_label.add_theme_color_override("font_color", ENEMY_COLOR if active_squad.is_pinned() else GOLD)
	attack_state_label.add_theme_color_override("font_color", ENEMY_COLOR if active_squad.is_pinned() else GOLD)
	enemy_name_label.text = "HOSTILE / " + target_enemy.name
	target_name_label.text = "TARGET: " + target_enemy.name
	enemy_info_label.text = "%s / %d MEN\nHP %d/%d · AP %d/2\n%s" % [target_enemy.type.trim_suffix(" / SUPPRESSION"), target_enemy.living_members().size(), target_enemy.health, target_enemy.max_health, target_enemy.action_points, "ELIMINATED" if target_enemy.health == 0 else "%s %d/2 · MOVE %d" % [target_enemy.suppression_state(), target_enemy.suppression, target_enemy.effective_movement()]]
	enemy_info_label.tooltip_text = target_enemy.type + "\n" + target_enemy.suppression_duration_text()
	target_panel.visible = not grenade_mode and not grenade_busy and not enemy_turn and selected and (target_hovered or target_pinned)
	target_range_label.text = "RANGE  %d / %d TILES" % [target_distance(), active_squad.effective_attack_range()]
	target_arc_label.text = "ARC: " + ("FRONT" if active_squad.in_firing_arc(target_enemy.cell) else "OUT OF ARC")
	var clear_los := has_line_of_sight(active_squad, target_enemy)
	target_los_label.text = "LOS: " + ("CLEAR" if clear_los else "BLOCKED")
	target_los_label.add_theme_color_override("font_color", GREEN if clear_los else ENEMY_COLOR)
	target_chance_label.text = "HIT CHANCE  %s%%" % str(target_hit_chance()) if target_distance() <= active_squad.effective_attack_range() and active_squad.in_firing_arc(target_enemy.cell) and clear_los and target_enemy.health > 0 else "HIT CHANCE  —"
	target_cover_label.text = "COVER: " + Terrain.cover_name(target_enemy.cell, cover)
	target_cover_label.tooltip_text = "Accuracy penalty: %s points; pinned defense: %d points" % [str(cover_penalty(active_squad, target_enemy)), pinned_cover_penalty(target_enemy)]
	if pinned_cover_penalty(target_enemy) > 0:
		target_cover_label.text += " · PINNED −10"
	target_direction_label.text = "DIRECTION  " + target_enemy.incoming_sector(active_squad.cell)
	var reason := attack_block_reason()
	target_state_label.text = "VALID TARGET" if reason.is_empty() else reason
	if reason.is_empty():
		match target_enemy.incoming_sector(active_squad.cell):
			"FLANK": target_state_label.text = "FLANKED — VALID"
			"REAR": target_state_label.text = "REAR ATTACK — VALID"
	target_state_label.add_theme_color_override("font_color", GREEN if reason.is_empty() else ENEMY_COLOR)
	fire_button.disabled = not reason.is_empty()
	end_button.disabled = enemy_turn or moving or volley_left > 0.0 or living_allies().is_empty()
	reset_button.disabled = moving or enemy_turn
	overwatch_button.disabled = enemy_turn or moving or volley_left > 0.0 or not selected or not active_squad.can_perform("overwatch")
	overwatch_button.text = "OVERWATCH ACTIVE" if active_squad.overwatch_active else "OVERWATCH [1 AP]"
	if active_squad.is_pinned():
		overwatch_button.text = "OVERWATCH · PINNED"
		overwatch_preview = false
		overwatch_help_label.text = "Pinned through own phase end.\nNew suppression renews duration."
	reaction_label.visible = overwatch_fire_left > 0.0
	rotate_left_button.disabled = not can_rotate()
	rotate_right_button.disabled = not can_rotate()
	grenade_button.disabled = not can_select_grenade()
	for control in [grenade_button, grenade_status_label, grenade_help_label]:
		control.visible = active_squad.grenade_capacity > 0
	deployment_label.visible = active_squad.stationary_range_bonus > 0
	deployment_label.text = ("DEPLOYED · +10% / +1 RANGE" if active_squad.is_deployed() else "MOVED · BASE FIRE PROFILE") + "\nSUPPORT / SUPPRESSION\nHit: 2 points · miss: 1 point"
	if active_squad.is_pinned():
		deployment_label.text = "PINNED · NO SET UP BONUS\nOVERWATCH UNAVAILABLE\nHit: 2 points · miss: 1 point"
	grenade_button.text = "CANCEL GRENADE" if grenade_mode else "GRENADE [1 AP]"
	grenade_status_label.text = "GRENADE READY" if active_squad.grenades_remaining > 0 else "GRENADE SPENT"
	grenade_help_label.text = "Range 2 · blast + 4 neighbors\nAffects allies too\nSandbags −25% / crates −10%"
	if grenade_mode:
		grenade_help_label.text = "Click to throw · ESC cancels\n" + ("TARGET %s · BLAST PREVIEW" % grid_name(hovered) if valid_grenade_tile(hovered) else "OUT OF RANGE") + "\nDirect %d–%d / adjacent %d–%d" % [GrenadeRules.DIRECT_MIN, GrenadeRules.DIRECT_MAX, GrenadeRules.ADJACENT_MIN, GrenadeRules.ADJACENT_MAX]
	if grenade_busy:
		end_button.disabled = true
		reset_button.disabled = true
	if grenade_mode or grenade_busy:
		overwatch_button.disabled = true
	if mission_over():
		end_button.disabled = true
		fire_button.disabled = true
		overwatch_button.disabled = true
		grenade_button.disabled = true
		rotate_left_button.disabled = true
		rotate_right_button.disabled = true
		target_panel.visible = false
		reset_button.disabled = restart_button.disabled
	if flow.stage != MissionFlow.BATTLE:
		phase_label.text = flow.stage
		turn_label.text = "PRE-MISSION"
		target_panel.visible = false
		end_button.disabled = true
		fire_button.disabled = true
		overwatch_button.disabled = true
		grenade_button.disabled = true
	if presentation != null: presentation.refresh()

func diamond(center: Vector2, inset: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -HALF.y + inset), center + Vector2(HALF.x - inset, 0), center + Vector2(0, HALF.y - inset), center + Vector2(-HALF.x + inset, 0)])

func outline(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func _draw() -> void:
	draw_set_transform(feedback.camera_offset if feedback != null else Vector2.ZERO)
	draw_rect(Rect2(0, 0, 1280, 800), Color("141d1b"))
	# Quiet map-paper marks and a layered diorama base.
	for x in range(0, 1280, 40):
		draw_line(Vector2(x, 125), Vector2(x, 655), Color(0.6, 0.7, 0.6, 0.025))
	for y in range(135, 655, 40):
		draw_line(Vector2(20, y), Vector2(1260, y), Color(0.6, 0.7, 0.6, 0.025))
	var corners := PackedVector2Array([Vector2(640, 195), Vector2(1086, 423), Vector2(640, 652), Vector2(194, 423)])
	var shadow := corners.duplicate()
	for i in shadow.size():
		shadow[i] += Vector2(0, 14)
	draw_colored_polygon(shadow, Color("0c1210"))
	draw_colored_polygon(corners, Color("343b2c"))
	outline(corners, Color("626851"), 2)
	for y in BOARD:
		for x in BOARD:
			var cell := Vector2i(x, y)
			var p := project_cell(cell)
			var tile := diamond(p, 0.7)
			var shade := float(posmod(x * 17 + y * 31, 9)) / 100.0
			var ground := Color(0.30 + shade, 0.33 + shade, 0.23 + shade * 0.7)
			if x == 5 or x == 6:
				ground = Color(0.39 + shade, 0.36 + shade, 0.27 + shade * 0.5)
			draw_colored_polygon(tile, ground)
			outline(tile, Color(0.10, 0.15, 0.11, 0.35))
			for seed_index in 3:
				var offset := Vector2(posmod(x * 13 + y * 7 + seed_index * 19, 43) - 21, posmod(x * 9 + y * 11 + seed_index * 7, 15) - 7)
				draw_line(p + offset, p + offset + Vector2(3, -1), Color(0.17, 0.22, 0.13, 0.4))
			if selected and not grenade_mode and not grenade_busy and not overwatch_preview and not enemy_turn and not moving and reachable.has(cell) and cell != squad_cell:
				draw_colored_polygon(diamond(p, 2), Color(0.48, 0.72, 0.60, 0.28))
				outline(diamond(p, 2), Color(0.58, 0.82, 0.69, 0.5))
			if selected and not grenade_mode and not grenade_busy and not enemy_turn and overwatch_preview and active_squad.can_perform("overwatch") and EnemyAI.distance(squad_cell, cell) <= active_squad.effective_overwatch_range() and active_squad.in_firing_arc(cell):
				draw_colored_polygon(diamond(p, 3), Color(WATCH_COLOR, 0.3))
				outline(diamond(p, 3), WATCH_COLOR, 1.5)
			if grenade_mode and valid_grenade_tile(cell):
				draw_colored_polygon(diamond(p, 3), Color(GOLD, 0.25))
				outline(diamond(p, 3), Color(GOLD, 0.7))
	if mission_enabled:
		var objective_color := MUTED
		if mission.objective_status == "ALLIED CONTROL":
			objective_color = GREEN
		elif mission.objective_status == "CONTESTED":
			objective_color = Color("edb368")
		for cell in Mission.ZONE:
			var center := project_cell(cell)
			draw_colored_polygon(diamond(center, 4), Color(objective_color, 0.16))
			outline(diamond(center, 5), Color(objective_color, 0.8), 2.0)
			draw_circle(center, 4, objective_color)
			draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), Color(INK, 0.55), 1)
			draw_line(center + Vector2(0, -4), center + Vector2(0, 4), Color(INK, 0.55), 1)
		outline(PackedVector2Array([project_cell(Vector2i(4, 4)) + Vector2(0, -HALF.y), project_cell(Vector2i(5, 4)) + Vector2(HALF.x, 0), project_cell(Vector2i(5, 5)) + Vector2(0, HALF.y), project_cell(Vector2i(4, 5)) + Vector2(-HALF.x, 0)]), objective_color, 2.5)
	if grenade_mode and valid_grenade_tile(hovered):
		for cell in GrenadeRules.blast_cells(hovered, BOARD):
			draw_colored_polygon(diamond(project_cell(cell), 2), Color(ENEMY_COLOR, 0.45))
			outline(diamond(project_cell(cell), 2), ENEMY_COLOR, 2)
		outline(diamond(project_cell(hovered), 5), GOLD, 3)
	if flow.stage == MissionFlow.DEPLOYMENT:
		for x in range(1, 6):
			for y in range(7, 10):
				var cell := Vector2i(x, y)
				if flow.can_place(active_squad, cell, all_squads(), cover):
					draw_colored_polygon(diamond(project_cell(cell), 3), Color(GREEN, 0.23))
					outline(diamond(project_cell(cell), 3), Color(GREEN, 0.8), 1.5)
	if selected and combat_ready() and not grenade_mode and not grenade_busy and not enemy_turn and active_squad.health > 0:
		draw_firing_arc(active_squad, overwatch_preview or active_squad.overwatch_active)
	# Map coordinates sit outside the playing surface.
	var font := ThemeDB.fallback_font
	for i in BOARD:
		draw_string(font, project_cell(Vector2i(i, 0)) + Vector2(5, -31), char(65 + i), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		draw_string(font, project_cell(Vector2i(0, i)) + Vector2(-44, -5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	if selected and combat_ready() and not grenade_mode and not grenade_busy and not overwatch_preview and not enemy_turn and not moving:
		var last := squad_position
		for cell in preview:
			var point := project_cell(cell)
			draw_line(last, point, GOLD, 2.5, true)
			draw_circle(point, 3, GOLD)
			last = point
		if inside(hovered) and hovered != squad_cell and not target_hovered:
			var valid := reachable.has(hovered)
			outline(diamond(project_cell(hovered), 2), GOLD if valid else Color("ce8067"), 2.5)
			if valid:
				draw_string(font, project_cell(hovered) + Vector2(-27, -9), "%d tiles / 1 AP" % reachable[hovered], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	# A single selection outline surrounds all members. Visuals sort with cover.
	for hostile in living_enemies():
		var target_color := ENEMY_COLOR
		if hostile == target_enemy and selected and not grenade_mode and not grenade_busy and (target_hovered or target_pinned):
			target_color = GREEN if attack_block_reason().is_empty() else Color("e58e74")
			outline(diamond(hostile.position, -3), target_color, 2.0)
			# A reticle supplements the color for valid / invalid target readability.
			draw_arc(hostile.position + Vector2(0, -15), 17, 0, TAU, 32, target_color, 1.5, true)
			draw_line(hostile.position + Vector2(-24, -15), hostile.position + Vector2(-11, -15), target_color, 2)
			draw_line(hostile.position + Vector2(11, -15), hostile.position + Vector2(24, -15), target_color, 2)
		draw_colored_polygon(diamond(hostile.position, 1), Color(target_color, 0.17))
		outline(diamond(hostile.position, 1), target_color, 2.5)
	if selected:
		outline(diamond(squad_position, 1), GOLD, 2.5)
		outline(diamond(squad_position, 5), Color(GOLD, 0.5), 1.2)
	for squad in living_allies():
		if squad != active_squad or not selected:
			outline(diamond(squad.position, 2), Color(0.88, 0.75, 0.45, 0.5), 1.5)
		draw_string(font, squad.position + Vector2(-32, -59), "MG TEAM" if squad == machine_gun else ("RIFLE" if squad == rifle else "RANGERS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
		for point in 2:
			draw_circle(squad.position + Vector2(-6 + point * 12, -48), 4.5, Color("16231d"))
			draw_circle(squad.position + Vector2(-6 + point * 12, -48), 3.3, GREEN if point < squad.action_points else Color("50594e"))
	var drawables: Array[Dictionary] = []
	for cell: Vector2i in cover:
		drawables.append({"y": project_cell(cell).y, "cell": cell})
	for squad in all_squads():
		for member in squad.visible_members():
			drawables.append({"y": squad.member_position(member).y, "member": member, "squad": squad})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	for item in drawables:
		if item.has("member"):
			draw_squad_member(item.member, item.squad)
		else:
			draw_cover(item.cell)
	if selected:
		draw_circle(squad_position + Vector2(0, -45), 3, GOLD)
	for squad in all_squads():
		if squad.health > 0:
			draw_facing_indicator(squad, ENEMY_COLOR if squad.hostile else GOLD)
	for hostile in living_enemies():
		draw_string(font, hostile.position + Vector2(-39, -64), hostile.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ENEMY_COLOR)
		draw_rect(Rect2(hostile.position + Vector2(-38, -56), Vector2(76, 8)), Color("111917"))
		draw_rect(Rect2(hostile.position + Vector2(-37, -55), Vector2(74 * float(hostile.health) / hostile.max_health, 6)), ENEMY_COLOR)
		draw_string(font, hostile.position + Vector2(-26, -37), "%d / %d" % [hostile.health, hostile.max_health], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	draw_volley()
	if show_los_debug and selected and active_squad.health > 0 and target_enemy.health > 0:
		var los_color := Color("70ef93") if has_line_of_sight(active_squad, target_enemy) else Color("ff605b")
		draw_line(project_cell(active_squad.cell), project_cell(target_enemy.cell), los_color, 3.0, true)
		draw_string(font, Vector2(39, 646), "LOS DEBUG [F3] — green: clear / red: blocked", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, los_color)
	draw_grenade()
	if result_left > 0.0:
		draw_string(font, combat_target.position + Vector2(-62, -111 - (1.8 - result_left) * 9), last_result, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)
		if not flank_text.is_empty():
			draw_string(font, combat_target.position + Vector2(-48, -131 - (1.8 - result_left) * 9), flank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	if suppression_text_left > 0.0:
		draw_string(font, combat_target.position + Vector2(-48, -92 - (1.8 - suppression_text_left) * 9), combat_target.suppression_state(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14 if combat_target.is_pinned() else 12, ENEMY_COLOR if combat_target.is_pinned() else GOLD)
	for squad in all_squads():
		if squad.overwatch_active and squad.health > 0:
			draw_string(font, squad.position + Vector2(-39, -93), "OVERWATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WATCH_COLOR)
		if squad.suppression > 0 and squad.health > 0:
			if squad.is_pinned():
				draw_rect(Rect2(squad.position + Vector2(-36, -93), Vector2(74, 21)), Color("542c27"))
			draw_string(font, squad.position + Vector2(-32 if squad.is_pinned() else -39, -77), squad.suppression_state(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if squad.is_pinned() else 11, ENEMY_COLOR if squad.is_pinned() else GOLD)
	# HUD backing.
	feedback.draw_on(self)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0, 0, 1280, 122), Color("111917"))
	draw_line(Vector2(38, 121), Vector2(1242, 121), Color("4b5545"))
	draw_rect(Rect2(24, 665, 1232, 106), Color("1c2823"))
	draw_line(Vector2(24, 665), Vector2(1256, 665), Color("6c775e"))
	draw_line(Vector2(402, 682), Vector2(402, 750), Color("46513f"))
	draw_string(font, Vector2(428, 721), "MOVE [1 AP]   FIRE [1 AP]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	# Four small soldier silhouettes are roster indicators, never selection buttons.
	for i in members.size():
		var spacing := minf(85.0, 340.0 / members.size())
		var p := Vector2(50 + i * spacing, 747)
		var tint := GREEN if members[i].alive else Color("51594e")
		paint_ellipse(p, Vector2(5, 4), tint)
		draw_line(p + Vector2(-6, 2), p + Vector2(6, 2), tint, 2)
		draw_rect(Rect2(p + Vector2(-4, 5), Vector2(8, 8)), tint)
		draw_line(p + Vector2(-2, 13), p + Vector2(-3, 17), tint, 2)
		draw_line(p + Vector2(2, 13), p + Vector2(3, 17), tint, 2)
		draw_string(font, p + Vector2(13, 10), members[i].weapon.left(4).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)
	# Enemy roster indicators use the same health-derived member state.
	for i in target_enemy.members.size():
		var p := Vector2(1040 + i * minf(28.0, 190.0 / target_enemy.members.size()), 365)
		var tint := ENEMY_COLOR if target_enemy.members[i].alive else Color("414b45")
		draw_circle(p + Vector2(0, -5), 3, tint)
		draw_line(p, p + Vector2(0, 5), tint, 5)

func grid_vector_to_screen(direction: Vector2) -> Vector2:
	return Vector2((direction.x - direction.y) * HALF.x, (direction.x + direction.y) * HALF.y)

func draw_facing_indicator(squad: SquadData, color: Color) -> void:
	var direction := grid_vector_to_screen(squad.facing).normalized()
	var side := direction.orthogonal()
	var tip := squad.position + direction * 39.0
	draw_line(squad.position + direction * 22.0, tip, color, 2.0, true)
	draw_colored_polygon(PackedVector2Array([tip, tip - direction * 8 + side * 4, tip - direction * 8 - side * 4]), color)

func draw_firing_arc(squad: SquadData, watching: bool) -> void:
	var radius := squad.effective_overwatch_range() if watching else squad.effective_attack_range()
	var points := PackedVector2Array([squad.position])
	var half_arc := deg_to_rad(squad.firing_arc_degrees) * 0.5
	for i in 41:
		var direction := squad.facing.rotated(lerpf(-half_arc, half_arc, float(i) / 40.0))
		var extent := direction * float(radius) / (absf(direction.x) + absf(direction.y))
		points.append(squad.position + grid_vector_to_screen(extent))
	var color := WATCH_COLOR if watching else GOLD
	draw_colored_polygon(points, Color(color, 0.14 if watching else 0.055))
	outline(points, Color(color, 0.85 if watching else 0.35), 1.5 if watching else 1.0)

func draw_volley() -> void:
	if volley_left <= 0.0:
		return
	var time := VOLLEY_DURATION - volley_left
	for i in traces.size():
		var local_time := time - float(i) * 0.055
		if local_time < 0.0 or local_time > 0.33:
			continue
		if firing_squad.suppression_on_hit == 2:
			local_time = fmod(local_time, 0.11)
		var start: Vector2 = traces[i]["from"]
		var finish: Vector2 = traces[i]["to"]
		var alpha := clampf(1.0 - local_time / 0.33, 0.0, 1.0)
		draw_line(start, finish, Color(1.0, 0.82, 0.40, alpha * 0.75), 1.5, true)
		var head := start.lerp(finish, clampf(local_time / 0.18, 0.0, 1.0))
		draw_circle(head, 2.1, Color(1.0, 0.95, 0.72, alpha))
		var direction := (finish - start).normalized()
		if local_time < 0.085:
			var flash_size := 13.0 if firing_squad.suppression_on_hit == 2 else 10.0
			draw_circle(start, 8, Color(1.0, 0.62, 0.20, 0.22 * alpha))
			draw_colored_polygon(PackedVector2Array([start - direction * 2, start + direction * 4 + direction.orthogonal() * 3.5, start + direction * flash_size, start + direction * 4 - direction.orthogonal() * 3.5]), Color(1.0, 0.79, 0.3, alpha))
			draw_circle(start + direction * 3, 2.5, Color(1, 0.97, 0.8, alpha))
		draw_circle(start + direction * 7 + Vector2(0, -local_time * 18), 2 + local_time * 6, Color(0.70, 0.70, 0.61, 0.16 * alpha))

func draw_box(center: Vector2, size_value: Vector2, height: float, top: Color, left: Color, right: Color) -> void:
	var a := center + Vector2(0, -size_value.y)
	var b := center + Vector2(size_value.x, 0)
	var c := center + Vector2(0, size_value.y)
	var d := center + Vector2(-size_value.x, 0)
	var up := Vector2(0, -height)
	draw_colored_polygon(PackedVector2Array([d, c, c + up, d + up]), left)
	draw_colored_polygon(PackedVector2Array([c, b, b + up, c + up]), right)
	draw_colored_polygon(PackedVector2Array([a + up, b + up, c + up, d + up]), top)
	outline(PackedVector2Array([a + up, b + up, c + up, d + up]), Color(0, 0, 0, 0.25))

func draw_cover(cell: Vector2i) -> void:
	var p := project_cell(cell)
	draw_colored_polygon(diamond(p + Vector2(6, 4), 6), Color(0.05, 0.08, 0.04, 0.3))
	if Terrain.properties(cover[cell]).get("kind", "") == "crate":
		draw_box(p, Vector2(25, 13), 29, Color("9c8050"), Color("735d3c"), Color("574b33"))
		for offset in [-14, 0, 14]:
			draw_line(p + Vector2(offset, -29 + abs(offset) * 0.52 - 13), p + Vector2(offset, -29 - abs(offset) * 0.52 + 13), Color("645233"), 1)
		draw_line(p + Vector2(-22, -27), p + Vector2(-2, 9), Color("b49a63"), 4, true)
		draw_line(p + Vector2(2, 9), p + Vector2(22, -27), Color("8b7449"), 4, true)
		draw_line(p + Vector2(-22, -1), p + Vector2(-2, -15), Color("b49a63"), 3, true)
	else:
		for row in 2:
			for bag in 3:
				var offset := Vector2((bag - 1) * 19 + row * 4, (bag - 1) * 7 - row * 10)
				draw_box(p + offset, Vector2(16, 9), 10, Color("b1a477"), Color("8f845e"), Color("776e4e"))
				draw_line(p + offset + Vector2(-11, -9), p + offset + Vector2(0, -4), Color("cec093"), 1, true)

func draw_squad_member(member: SquadMember, squad: SquadData) -> void:
	var anchor := squad.member_position(member)
	paint_ellipse(anchor + Vector2(0, 1), Vector2(7, 3), casualty_color(Color(0, 0, 0, 0.35), member))
	if soldier_visuals.has(member):
		soldier_visuals[member].draw_at(self, anchor, member)
		return
	var phase := float(squad.members.find(member)) * 1.7
	var walking := (moving and squad == active_squad) or (enemy_moving and squad == acting_enemy)
	var bob := sin(elapsed * 20.0 + phase) * 1.3 if walking else sin(elapsed * 2.0 + phase) * 0.4
	if not member.alive:
		bob = 0.0
	var uniform := casualty_color(Color("535f59"), member) if squad.hostile else casualty_color(Color("78815a"), member)
	var straps := casualty_color(Color("343b36"), member) if squad.hostile else casualty_color(Color("b2a379"), member)
	var visual_direction := grid_vector_to_screen(squad.facing)
	var facing := absf(member.facing) * (1.0 if visual_direction.x >= 0.0 else -1.0)
	if squad == firing_squad and volley_left > 0.0:
		facing = firing_facing(member)
	var fall := 0.0 if member.alive else smoothstep(0.0, 0.75, member.casualty_progress()) * 1.45
	draw_set_transform(anchor + feedback.camera_offset, fall, Vector2(MEMBER_SCALE * facing, MEMBER_SCALE))
	var p := Vector2(0, bob)
	# Boots, fatigues, webbing, pack, face and steel helmet.
	draw_line(p + Vector2(-5, -17), p + Vector2(-7, -3), uniform.darkened(0.3), 8, true)
	draw_line(p + Vector2(5, -17), p + Vector2(7, -2), uniform.darkened(0.15), 8, true)
	draw_line(p + Vector2(-7, -2), p + Vector2(-2, 0), casualty_color(Color("262d26"), member), 6, true)
	draw_line(p + Vector2(7, -1), p + Vector2(12, 1), casualty_color(Color("262d26"), member), 6, true)
	draw_style_box(button_style(uniform.darkened(0.2)), Rect2(p + Vector2(-14, -36), Vector2(12, 21)))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -35), p + Vector2(7, -35), p + Vector2(11, -16), p + Vector2(-10, -16)]), uniform)
	draw_line(p + Vector2(-5, -34), p + Vector2(4, -18), straps, 3, true)
	draw_line(p + Vector2(-10, -18), p + Vector2(10, -18), casualty_color(Color("3d4430"), member), 4, true)
	draw_line(p + Vector2(7, -31), p + Vector2(15, -23), uniform, 7, true)
	draw_line(p + Vector2(-7, -30), p + Vector2(6, -23), uniform.lightened(0.12), 6, true)
	# Distinct placeholder silhouettes: SMG magazine, long rifle, heavy BAR,
	# and a compact carbine. No weapon adds any combat behavior.
	match member.weapon:
		"M1919":
			draw_line(p + Vector2(-9, -25), p + Vector2(44, -27), casualty_color(Color("29322b"), member), 8, true)
			draw_line(p + Vector2(16, -25), p + Vector2(5, -3), straps, 3, true)
			draw_line(p + Vector2(16, -25), p + Vector2(37, -3), straps, 3, true)
			draw_line(p + Vector2(3, -23), p + Vector2(-4, -13), casualty_color(GOLD, member), 4, true)
			for hole in 5:
				draw_circle(p + Vector2(23 + hole * 4, -27), 1, straps)
		"MP40":
			draw_line(p + Vector2(0, -21), p + Vector2(29, -33), casualty_color(Color("272e2b"), member), 4, true)
			draw_line(p + Vector2(15, -27), p + Vector2(20, -16), casualty_color(Color("222824"), member), 3, true)
			draw_line(p + Vector2(-4, -19), p + Vector2(7, -24), casualty_color(Color("93988b"), member), 2, true)
		"Kar98k":
			draw_line(p + Vector2(0, -19), p + Vector2(20, -39), casualty_color(Color("63462e"), member), 4, true)
			draw_line(p + Vector2(17, -36), p + Vector2(30, -51), casualty_color(Color("272e2b"), member), 2, true)
		"MG42":
			draw_line(p + Vector2(-3, -23), p + Vector2(39, -37), casualty_color(Color("252d2b"), member), 6, true)
			draw_line(p + Vector2(34, -35), p + Vector2(45, -39), casualty_color(Color("222824"), member), 3, true)
			draw_line(p + Vector2(32, -34), p + Vector2(36, -23), casualty_color(Color("222824"), member), 2, true)
			draw_line(p + Vector2(14, -27), p + Vector2(7, -14), casualty_color(Color("b49b62"), member), 4, true)
			for x in [21, 26, 31]:
				draw_circle(p + Vector2(x, -31 - (x - 21) * 0.33), 1, casualty_color(Color("90968b"), member))
		"Thompson":
			draw_line(p + Vector2(0, -22), p + Vector2(22, -31), casualty_color(Color("4b3826"), member), 5, true)
			draw_line(p + Vector2(10, -27), p + Vector2(29, -34), casualty_color(Color("272e2b"), member), 4, true)
			draw_line(p + Vector2(15, -28), p + Vector2(18, -19), casualty_color(Color("272e2b"), member), 4, true)
		"M1 Garand":
			draw_line(p + Vector2(2, -17), p + Vector2(22, -39), casualty_color(Color("65492f"), member), 5, true)
			draw_line(p + Vector2(17, -34), p + Vector2(28, -49), casualty_color(Color("272e2b"), member), 3, true)
		"BAR":
			draw_line(p + Vector2(-2, -21), p + Vector2(30, -36), casualty_color(Color("40382a"), member), 7, true)
			draw_line(p + Vector2(23, -33), p + Vector2(38, -40), casualty_color(Color("272e2b"), member), 4, true)
			draw_line(p + Vector2(15, -29), p + Vector2(18, -19), casualty_color(Color("272e2b"), member), 6, true)
			for x in [-7, 0, 7]:
				draw_rect(Rect2(p + Vector2(x, -19), Vector2(5, 7)), casualty_color(Color("b2a379"), member))
		"M1 Carbine":
			draw_line(p + Vector2(2, -20), p + Vector2(17, -34), casualty_color(Color("795a39"), member), 4, true)
			draw_line(p + Vector2(14, -31), p + Vector2(22, -40), casualty_color(Color("272e2b"), member), 2, true)
	if member.id == "assistant" or member.id == "ammo_bearer":
		draw_rect(Rect2(p + Vector2(-23, -25), Vector2(15, 15)), casualty_color(Color("566342"), member))
		draw_line(p + Vector2(-23, -21), p + Vector2(-8, -21), straps, 2, true)
	draw_circle(p + Vector2(11, -26), 3, casualty_color(Color("c4aa7f"), member))
	draw_circle(p + Vector2(0, -39), 7, casualty_color(Color("c4aa7f"), member))
	paint_ellipse(p + Vector2(-1, -45), Vector2(11, 8), uniform.darkened(0.1))
	if squad.hostile:
		# Flared helmet skirt and longer tunic distinguish the German silhouettes.
		draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -46), p + Vector2(-14, -38), p + Vector2(-5, -37), p + Vector2(11, -40), p + Vector2(9, -44)]), uniform.darkened(0.23))
		draw_rect(Rect2(p + Vector2(-9, -18), Vector2(17, 6)), uniform)
	else:
		draw_line(p + Vector2(-12, -41), p + Vector2(10, -42), casualty_color(Color("3c4734"), member), 3, true)
	draw_arc(p + Vector2(-1, -45), 7, PI, PI * 1.8, 12, uniform.lightened(0.2), 1.5, true)
	if member.id == "leader" and not squad.hostile:
		draw_line(p + Vector2(-3, -49), p + Vector2(-3, -44), casualty_color(GOLD, member), 3, true)
		draw_line(p + Vector2(-11, -30), p + Vector2(-6, -27), casualty_color(GOLD, member), 2, true)
	draw_set_transform(feedback.camera_offset)

func paint_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

func casualty_color(color: Color, member: SquadMember) -> Color:
	if not member.alive:
		color.a *= 1.0 - smoothstep(0.25, 1.0, member.casualty_progress())
	return color
