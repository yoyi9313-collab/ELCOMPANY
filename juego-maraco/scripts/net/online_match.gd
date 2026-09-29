extends Node
## Online 1v1 session: Steam lobby (GodotSteam) or direct LAN (ENet) transport.
## Only player commands travel; battlefield.gd replays them in lockstep.
## Steam classes are looked up dynamically so stock Godot still opens the
## project; LAN play works everywhere, Steam needs the GodotSteam editor/build.

const DEVELOPMENT_APP_ID := 480  # Spacewar test app until the game has its own
const LAN_PORT := 24744
const LOBBY_GAME_KEY := "game"
const LOBBY_GAME_VALUE := "ELCOMPANY_Hedgerow1v1"
const LOBBY_NAME_KEY := "host_name"
const STEAM_API_INIT_OK := 0
const STEAM_RESULT_OK := 1
const CHAT_ROOM_ENTER_RESPONSE_SUCCESS := 1
const LOBBY_TYPE_FRIENDS_ONLY := 1
const LOBBY_TYPE_PUBLIC := 2
const LOBBY_COMPARISON_EQUAL := 0

signal status_changed(message: String)
signal lobbies_received(lobbies: Array)
signal match_started(local_side: String, rng_seed: int)
signal command_received(command: Array)
signal opponent_left

var steam: Object
var steam_ready := false
var steam_id := 0
var persona_name := ""
var lobby_id := 0
var in_match := false
var status_text := "Offline."


func _init() -> void:
	OS.set_environment("SteamAppId", str(DEVELOPMENT_APP_ID))
	OS.set_environment("SteamGameId", str(DEVELOPMENT_APP_ID))


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(func() -> void: _set_status("Could not connect."); leave())
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if not Engine.has_singleton("Steam"):
		_set_status("Steam unavailable (stock Godot). LAN play only.")
		return
	steam = Engine.get_singleton("Steam")
	var init_result: Variant = steam.call("steamInitEx")
	if typeof(init_result) != TYPE_DICTIONARY or int((init_result as Dictionary).get("status", -1)) != STEAM_API_INIT_OK:
		_set_status("Steam failed to start — is the Steam client open? LAN still works.")
		return
	steam_ready = true
	steam_id = int(steam.call("getSteamID"))
	persona_name = str(steam.call("getPersonaName"))
	_connect_steam("lobby_created", _on_lobby_created)
	_connect_steam("lobby_joined", _on_lobby_joined)
	_connect_steam("lobby_match_list", _on_lobby_match_list)
	_connect_steam("join_requested", _on_join_requested)
	_set_status("Steam ready: %s." % persona_name)
	# Launched from a Steam invite: "+connect_lobby <id>".
	var args := OS.get_cmdline_args()
	var index := args.find("+connect_lobby")
	if index >= 0 and index + 1 < args.size():
		join_steam_lobby(int(args[index + 1]))


func _process(_delta: float) -> void:
	if steam_ready:
		steam.call("run_callbacks")


func busy() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


# --- Steam ------------------------------------------------------------------

func host_steam() -> void:
	if not steam_ready:
		_set_status("Steam is not available. Use LAN, or open with the GodotSteam editor.")
		return
	if busy():
		return
	_set_status("Creating Steam lobby…")
	steam.call("createLobby", LOBBY_TYPE_PUBLIC, 2)


func invite_friend() -> void:
	if steam_ready and lobby_id != 0:
		steam.call("activateGameOverlayInviteDialog", lobby_id)


func lobby_id_text() -> String:
	return str(lobby_id) if lobby_id != 0 else ""


func refresh_lobbies() -> void:
	if not steam_ready:
		return
	steam.call("addRequestLobbyListStringFilter", LOBBY_GAME_KEY, LOBBY_GAME_VALUE, LOBBY_COMPARISON_EQUAL)
	steam.call("addRequestLobbyListDistanceFilter", 3)  # worldwide
	steam.call("requestLobbyList")
	_set_status("Searching lobbies…")


func join_steam_lobby(id: int) -> void:
	if not steam_ready or id == 0 or busy():
		return
	_set_status("Joining lobby %d…" % id)
	steam.call("joinLobby", id)


func _connect_steam(signal_name: StringName, callback: Callable) -> void:
	if steam.connect(signal_name, callback) != OK:
		push_warning("[OnlineMatch] Could not connect Steam signal %s." % signal_name)


func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != STEAM_RESULT_OK:
		_set_status("Steam could not create a lobby (code %d)." % result)
		return
	lobby_id = new_lobby_id
	steam.call("setLobbyData", lobby_id, LOBBY_GAME_KEY, LOBBY_GAME_VALUE)
	steam.call("setLobbyData", lobby_id, LOBBY_NAME_KEY, persona_name)
	steam.call("setLobbyJoinable", lobby_id, true)
	var peer := ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if peer == null or int(peer.call("create_host", 0)) != OK:
		_set_status("SteamMultiplayerPeer failed. Use the GodotSteam 4.20 build.")
		leave()
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Lobby %d open. Invite a friend or share the ID. You play ALLIES." % lobby_id)


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		_set_status("Steam rejected the join (code %d)." % response)
		return
	lobby_id = joined_lobby_id
	var host_steam_id := int(steam.call("getLobbyOwner", lobby_id))
	if host_steam_id == steam_id:
		return  # our own lobby: the host peer already exists
	var peer := ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if peer == null or int(peer.call("create_client", host_steam_id, 0)) != OK:
		_set_status("Could not connect to the lobby host.")
		leave()
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Connecting to host…")


func _on_lobby_match_list(ids: Array) -> void:
	var lobbies: Array = []
	for id: int in ids:
		lobbies.append({"id": id, "name": str(steam.call("getLobbyData", id, LOBBY_NAME_KEY)), "members": int(steam.call("getNumLobbyMembers", id))})
	lobbies_received.emit(lobbies)
	_set_status("%d lobby(ies) found." % lobbies.size())


func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	leave()
	join_steam_lobby(requested_lobby_id)


# --- LAN (ENet) — for two windows on one PC or a local network ---------------

func host_lan() -> void:
	if busy():
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(LAN_PORT, 1)
	if error != OK:
		_set_status("Could not open LAN port %d (%s)." % [LAN_PORT, error_string(error)])
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Hosting LAN on port %d. You play ALLIES. Waiting…" % LAN_PORT)


func join_lan(address: String) -> void:
	if busy():
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges() if not address.strip_edges().is_empty() else "127.0.0.1", LAN_PORT)
	if error != OK:
		_set_status("Could not start LAN client (%s)." % error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Connecting to %s…" % address)


# --- Session ------------------------------------------------------------------

func leave() -> void:
	if steam_ready and lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	in_match = false


func send_command(command: Array) -> void:
	if busy():
		_remote_command.rpc(command)


@rpc("any_peer", "call_remote", "reliable")
func _remote_command(command: Array) -> void:
	command_received.emit(command)


@rpc("authority", "call_local", "reliable")
func _begin_match(rng_seed: int) -> void:
	in_match = true
	var side := "ALLIED" if multiplayer.is_server() else "GERMAN"
	_set_status("Match started. You play %s." % ("ALLIES" if side == "ALLIED" else "GERMANS"))
	match_started.emit(side, rng_seed)


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_peers().size() > 1:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	# Host picks the shared seed; both peers roll the same combat RNG.
	_begin_match.rpc(randi())


func _on_peer_disconnected(_peer_id: int) -> void:
	if in_match:
		in_match = false
		_set_status("Opponent left the match.")
		opponent_left.emit()


func _on_server_disconnected() -> void:
	_set_status("Host closed the match.")
	in_match = false
	opponent_left.emit()
	leave()


func _set_status(message: String) -> void:
	status_text = message
	print("[OnlineMatch] ", message)
	status_changed.emit(message)
