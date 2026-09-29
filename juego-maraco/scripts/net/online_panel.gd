extends CanvasLayer
## Lobby overlay for OnlineMatch. Opened from the intro screen or with F10.

var game
var net
var panel: Panel
var status_label: Label
var lobby_edit: LineEdit
var address_edit: LineEdit
var lobby_list: ItemList
var invite_button: Button
var copy_button: Button
var found_lobbies: Array = []


func setup(battlefield, online_match) -> void:
	game = battlefield
	net = online_match
	layer = 20
	panel = Panel.new()
	panel.position = Vector2(290, 120)
	panel.size = Vector2(700, 540)
	panel.add_theme_stylebox_override("panel", game.button_style(Color(0.07, 0.1, 0.085, 0.98)))
	add_child(panel)
	game.label_at(panel, "ONLINE 1v1  ·  ALLIES vs GERMANS", Vector2(28, 22), 22, game.GOLD)
	game.label_at(panel, "Host plays the Allies, the guest plays the Germans.", Vector2(28, 56), 14, game.MUTED)
	status_label = game.label_at(panel, "", Vector2(28, 84), 14, game.WATCH_COLOR)
	status_label.size = Vector2(644, 40)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	game.label_at(panel, "STEAM", Vector2(28, 136), 15, game.GOLD)
	button("HOST LOBBY", Vector2(28, 162), Vector2(200, 38), net.host_steam)
	invite_button = button("INVITE FRIEND", Vector2(240, 162), Vector2(200, 38), net.invite_friend)
	copy_button = button("COPY LOBBY ID", Vector2(452, 162), Vector2(200, 38), func() -> void: DisplayServer.clipboard_set(net.lobby_id_text()))
	lobby_edit = LineEdit.new()
	lobby_edit.placeholder_text = "Paste lobby ID"
	lobby_edit.position = Vector2(28, 212)
	lobby_edit.size = Vector2(412, 36)
	panel.add_child(lobby_edit)
	button("JOIN BY ID", Vector2(452, 212), Vector2(200, 36), func() -> void: net.join_steam_lobby(int(lobby_edit.text.strip_edges())))
	button("FIND LOBBIES", Vector2(28, 258), Vector2(200, 34), net.refresh_lobbies)
	lobby_list = ItemList.new()
	lobby_list.position = Vector2(240, 258)
	lobby_list.size = Vector2(412, 84)
	lobby_list.item_activated.connect(func(index: int) -> void: net.join_steam_lobby(found_lobbies[index].id))
	panel.add_child(lobby_list)

	game.label_at(panel, "LAN / SAME PC (testing without Steam)", Vector2(28, 362), 15, game.GOLD)
	button("HOST LAN", Vector2(28, 388), Vector2(200, 38), net.host_lan)
	address_edit = LineEdit.new()
	address_edit.text = "127.0.0.1"
	address_edit.position = Vector2(240, 388)
	address_edit.size = Vector2(200, 38)
	panel.add_child(address_edit)
	button("JOIN LAN", Vector2(452, 388), Vector2(200, 38), func() -> void: net.join_lan(address_edit.text))

	button("LEAVE / OFFLINE", Vector2(28, 470), Vector2(300, 40), func() -> void:
		net.leave()
		if game.online: game.stop_online())
	button("CLOSE  [F10]", Vector2(352, 470), Vector2(300, 40), func() -> void: visible = false)

	net.status_changed.connect(func(_message: String) -> void: refresh())
	net.lobbies_received.connect(_on_lobbies)
	net.match_started.connect(func(_side: String, _seed: int) -> void: visible = false)
	visible = false
	refresh()


func button(title: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.position = at
	b.size = dimensions
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", game.button_style(Color("344938")))
	b.add_theme_stylebox_override("hover", game.button_style(Color("536348")))
	b.pressed.connect(action)
	panel.add_child(b)
	return b


func refresh() -> void:
	status_label.text = net.status_text
	invite_button.disabled = net.lobby_id == 0
	copy_button.disabled = net.lobby_id == 0


func _on_lobbies(lobbies: Array) -> void:
	found_lobbies = lobbies
	lobby_list.clear()
	for lobby in lobbies:
		lobby_list.add_item("%s  (%d/2)" % [lobby.name, lobby.members])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		visible = not visible
		refresh()
		get_viewport().set_input_as_handled()
