extends CanvasLayer
## Small overlays, retaining the existing battlefield and information panels.
var game
var intro: Panel
var deployment: Panel
var roster: Array[Button] = []
var begin_button: Button
var start_button: Button
var phase_label: Label
var notice_label: Label
var phase_time := 0.0
var notice_time := 0.0
var notice_history: Array[String] = []
var pending_notices: Array[String] = []
var last_capture := 0
var last_state := "NEUTRAL"
var seen_result := false
signal notification(text: String)

func setup(battlefield) -> void:
	game = battlefield
	layer = 8
	intro = Panel.new()
	intro.size = Vector2(1280, 800)
	intro.add_theme_stylebox_override("panel", game.button_style(Color(0.055, 0.085, 0.07, 0.97)))
	add_child(intro)
	game.label_at(intro, "NORMANDY, 1944  /  FIELD OPERATIONS", Vector2(350, 210), 15, game.GOLD)
	game.label_at(intro, "SECURE THE HEDGEROW", Vector2(350, 252), 35)
	game.label_at(intro, "Capture and hold the German position before Turn 8.", Vector2(350, 321), 18, game.MUTED)
	game.label_at(intro, "Three Allied squads. Two routes. One position to secure.\n\nDeploy your squads, then end two Allied phases inside the zone.\nGerman troops inside the zone will contest your capture.", Vector2(350, 369), 16, game.MUTED)
	start_button = make_button(intro, "START MISSION", Vector2(350, 498), Vector2(580, 48))
	start_button.pressed.connect(game.ui_start)
	var online_button := make_button(intro, "PLAY ONLINE 1v1", Vector2(350, 556), Vector2(580, 40))
	online_button.pressed.connect(game.open_online_panel)
	online_button.visible = game.get_node_or_null("/root/OnlineMatch") != null
	deployment = Panel.new()
	deployment.position = Vector2(25, 130)
	deployment.size = Vector2(265, 496)
	deployment.add_theme_stylebox_override("panel", game.button_style(Color("18251f")))
	add_child(deployment)
	game.label_at(deployment, "ALLIED DEPLOYMENT", Vector2(14, 18), 18, game.GOLD)
	game.label_at(deployment, "Select a squad, then click a\nhighlighted tile to confirm it.\nAll three must be placed.", Vector2(14, 55), 14, game.MUTED)
	for i in game.allies.size():
		var button := make_button(deployment, "", Vector2(14, 130 + i * 57), Vector2(237, 48))
		button.pressed.connect(func(): game.ui_select(game.allies[i]))
		roster.append(button)
	begin_button = make_button(deployment, "BEGIN BATTLE", Vector2(14, 323), Vector2(237, 45))
	begin_button.pressed.connect(game.ui_begin)
	game.label_at(deployment, "Placement costs no AP.\nChoose the west or east approach.\nGerman positions are fixed.", Vector2(14, 389), 13, game.MUTED)
	phase_label = game.label_at(self, "", Vector2(449, 137), 25, game.GOLD)
	phase_label.size = Vector2(490, 38)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label = game.label_at(self, "", Vector2(360, 626), 16, game.GOLD)
	notice_label.size = Vector2(650, 30)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refresh()

func make_button(parent: Node, title: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = title
	button.position = at
	button.size = dimensions
	button.add_theme_stylebox_override("normal", game.button_style(Color("344938")))
	button.add_theme_stylebox_override("hover", game.button_style(Color("536348")))
	parent.add_child(button)
	return button

func announce_phase(side: String) -> void:
	phase_label.text = side + " PHASE"
	phase_label.add_theme_color_override("font_color", game.ENEMY_COLOR if side == "GERMAN" else game.GOLD)
	phase_time = 1.8
	game.feedback.cue("phase")

func notify(text: String) -> void:
	if notice_time > 0:
		pending_notices.append(text)
	else:
		notice_label.text = text
		notice_time = 2.8
	notice_history.append(text)
	if notice_history.size() > 24: notice_history.pop_front()
	notification.emit(text)

func refresh() -> void:
	intro.visible = game.flow.stage == "INTRO"
	deployment.visible = game.flow.stage == "DEPLOYMENT"
	for i in roster.size():
		var squad = game.allies[i]
		roster[i].text = ("✓ " if game.flow.placed.has(squad) else "○ ") + squad.name.trim_prefix("U.S. ")
		roster[i].modulate = Color.WHITE if squad == game.active_squad else Color("a7b39c")
	begin_button.disabled = not game.flow.ready(game.allies)
	var waiting: bool = game.online and game.local_side != game.ALLIED
	start_button.disabled = waiting
	start_button.text = "WAITING FOR THE ALLIED PLAYER…" if waiting else "START MISSION"
	if waiting:
		begin_button.disabled = true
		for button in roster: button.disabled = true
	else:
		for button in roster: button.disabled = false
	if game.flow.stage != "BATTLE" or not game.mission_enabled:
		return
	if game.mission.capture_points > last_capture:
		notify("POSITION HELD  ·  CAPTURE %d / 2" % game.mission.capture_points)
		game.feedback.cue("capture")
	elif game.mission.objective_status != last_state:
		notify("OBJECTIVE  ·  " + game.mission.objective_status)
	last_capture = game.mission.capture_points
	last_state = game.mission.objective_status
	if game.mission_over() and not seen_result:
		seen_result = true
		game.feedback.cue("victory" if game.mission.winner == "ALLIED" else "defeat")

func reset() -> void:
	phase_time = 0
	notice_time = 0
	last_capture = 0
	last_state = "NEUTRAL"
	seen_result = false
	notice_history.clear()
	pending_notices.clear()
	refresh()

func _process(delta: float) -> void:
	phase_time = maxf(0, phase_time - delta)
	notice_time = maxf(0, notice_time - delta)
	if notice_time == 0 and not pending_notices.is_empty():
		notice_label.text = pending_notices.pop_front()
		notice_time = 2.8
	phase_label.visible = phase_time > 0 and not game.mission_over()
	notice_label.visible = notice_time > 0 and not game.mission_over()
	phase_label.modulate.a = minf(1, phase_time / 0.35)
	notice_label.modulate.a = minf(1, notice_time / 0.4)
