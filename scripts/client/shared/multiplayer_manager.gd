extends Node


signal connected_to_server()
signal disconnected_from_server()
signal connection_failed()
signal player_joined(peer_id: int, user_id: int, display_name: String)
signal player_left(peer_id: int)
signal chat_received(sender_name: String, text: String)
signal map_change_result(result: Dictionary)

const DEFAULT_HOST: String = "127.0.0.1"
const DEFAULT_PORT: int    = 7777

# List of scene names that are instanced per player (farm).
const INSTANCED_SCENES: Array[String] = [
	"game",
]

# Local player info
var local_user_id:      int    = -1
var local_display_name: String = ""
var local_auth_token:   String = ""
var local_scene_name:   String = "game"
var local_map_id:       String = "game"

# Internal
var _peer: ENetMultiplayerPeer = null
var _invite_dialog: ConfirmationDialog = null
var _pending_invite_user_id: int = -1


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func get_server_host() -> String:
	return _read_arg_or_env("game-host", "GAME_HOST", DEFAULT_HOST)


func get_server_port() -> int:
	return int(_read_arg_or_env("game-port", "GAME_PORT", str(DEFAULT_PORT)))


# ─── Public API ───────────────────────────────────────────────────────────────

## Perform a REST login.
func set_local_player(user_id: int, display_name: String, map_id: String = "game") -> void:
	local_user_id      = user_id
	local_display_name = display_name
	set_map(_server_map_to_scene(map_id))


func set_auth_token(token: String) -> void:
	local_auth_token = token

## Sets the scene name.
func set_map(scene_name: String) -> void:
	var target_map_id_override := ""
	if scene_name.contains("_"):
		var parts := scene_name.split("_")
		if parts.size() == 2 and parts[1].is_valid_int():
			target_map_id_override = scene_name
			scene_name = parts[0]
			
	scene_name = _server_map_to_scene(scene_name)
	local_scene_name = scene_name
	if not target_map_id_override.is_empty():
		local_map_id = target_map_id_override
	elif scene_name in INSTANCED_SCENES:
		local_map_id = scene_name + "_" + str(local_user_id)
	else:
		local_map_id = scene_name


func get_server_map_name(scene_name: String = "") -> String:
	if scene_name.is_empty():
		scene_name = local_scene_name
	match scene_name:
		"game":
			return "farm"
		"park":
			return "central_park"
		"fish_pond":
			return "fishing_lake"
		_:
			return scene_name

# Go dùng scene tên khác :V
func _server_map_to_scene(map_id: String) -> String:
	if map_id.begins_with("game_"):
		return "game"
	match map_id:
		"farm":
			return "game"
		"central_park", "world":
			return "park"
		"fishing_lake":
			return "fish_pond"
		"":
			return "game"
		_:
			return map_id


## Connect to the dedicated Godot game server.
func connect_to_server(host: String = "", port: int = 0) -> void:
	if _peer != null:
		push_warning("[MultiplayerManager] Already connected — disconnect first.")
		return
	if host.is_empty():
		host = get_server_host()
	if port <= 0:
		port = get_server_port()

	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_client(host, port)
	if err != OK:
		push_error("[MultiplayerManager] Failed to create client (err=%d)" % err)
		_peer = null
		connection_failed.emit()
		return

	multiplayer.multiplayer_peer = _peer
	print("[MultiplayerManager] Connecting to %s:%d …" % [host, port])


func disconnect_from_server() -> void:
	if _peer == null:
		return
	multiplayer.multiplayer_peer = null
	_peer = null

# Multiplayer callbacks
func _on_connected_to_server() -> void:
	print("[MultiplayerManager] Connected! My peer ID: %d" % multiplayer.get_unique_id())
	connected_to_server.emit()


## Called by the game scene when it is fully loaded and ready to receive players.
func send_registration() -> void:
	var server_node: Node = get_tree().root.get_node_or_null("ServerScene")
	if server_node and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		if local_auth_token.is_empty() or local_auth_token == "dummy_token":
			push_error("[MultiplayerManager] Refusing to register with dedicated server without a JWT.")
			disconnect_from_server()
			return
		server_node.register_player_with_token.rpc_id(1, local_auth_token, local_map_id)
	elif not server_node:
		push_error("[MultiplayerManager] ServerScene not found in tree — cannot register.")


func _on_connection_failed() -> void:
	push_warning("[MultiplayerManager] Connection failed.")
	_peer = null
	connection_failed.emit()


func _on_server_disconnected() -> void:
	push_warning("[MultiplayerManager] Server disconnected.")
	_peer = null
	disconnected_from_server.emit()


# Server → Client RPCs

## joined peer_id.
@rpc("authority", "reliable")
func _client_player_joined(peer_id: int, user_id: int, display_name: String, _map_id: String) -> void:
	print("[MultiplayerManager] Player joined: %s (peer=%d)" % [display_name, peer_id])
	player_joined.emit(peer_id, user_id, display_name)


## disconnected peer_id.
@rpc("authority", "reliable")
func _client_player_left(peer_id: int) -> void:
	print("[MultiplayerManager] Player left: peer=%d" % peer_id)
	player_left.emit(peer_id)


func send_chat_message(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	var server_node: Node = get_tree().root.get_node_or_null("ServerScene")
	if server_node and multiplayer.has_multiplayer_peer():
		server_node.receive_chat.rpc_id(1, trimmed)


func request_map_change(scene_name: String) -> bool:
	var server_node: Node = get_tree().root.get_node_or_null("ServerScene")
	if not server_node or not multiplayer.has_multiplayer_peer():
		return false
	server_node.request_map_change.rpc_id(1, scene_name)
	var result: Dictionary = await map_change_result
	return result.get("approved", false) and result.get("scene_name", "") == scene_name


@rpc("authority", "reliable")
func broadcast_chat(_sender_peer_id: int, sender_name: String, text: String) -> void:
	chat_received.emit(sender_name, text)


@rpc("authority", "reliable")
func map_change_approved(scene_name: String) -> void:
	set_map(scene_name)
	map_change_result.emit({ "approved": true, "scene_name": scene_name })


@rpc("authority", "reliable")
func map_change_denied() -> void:
	map_change_result.emit({ "approved": false, "scene_name": "" })

# Farm Sync

## Send farm action (plant, water, harvest, remove)
func send_farm_action(plot_id: int, action: String, data: String = "") -> void:
	var server_node: Node = get_tree().root.get_node_or_null("ServerScene")
	if server_node and multiplayer.has_multiplayer_peer():
		server_node.request_farm_action.rpc_id(1, local_map_id, plot_id, action, data)


func notify_farm_changed(plot_id: int) -> void:
	var server_node: Node = get_tree().root.get_node_or_null("ServerScene")
	if server_node and multiplayer.has_multiplayer_peer():
		server_node.notify_farm_changed.rpc_id(1, plot_id)


@rpc("authority", "reliable")
func farm_changed(map_id: String, _plot_id: int) -> void:
	if map_id != local_map_id:
		return
	for slot in get_tree().get_nodes_in_group("farm_slots"):
		if slot.has_method("_load_farm_from_server"):
			slot.call_deferred("_load_farm_from_server")
			return

@rpc("authority", "reliable")
func sync_farm_slot(map_id: String, plot_id: int, state: int, seed_id: String, ready_at: int) -> void:
	if map_id != local_map_id:
		return
	
	var slots = get_tree().get_nodes_in_group("farm_slots")
	for slot in slots:
		if slot.plotId == plot_id:
			slot.sync_state(state, seed_id, ready_at)
			break

@rpc("authority", "reliable")
func sync_all_farm_slots(map_id: String, slots_data: Dictionary) -> void:
	if map_id != local_map_id:
		return
	
	var slots = get_tree().get_nodes_in_group("farm_slots")
	for slot in slots:
		var plot_key = slot.plotId
		# bruh
		if slots_data.has(plot_key):
			var data = slots_data[plot_key]
			slot.sync_state(data.get("state", 0), data.get("seed_id", ""), data.get("ready_at", 0))
		elif slots_data.has(str(plot_key)):
			var data = slots_data[str(plot_key)]
			slot.sync_state(data.get("state", 0), data.get("seed_id", ""), data.get("ready_at", 0))

# Sync Player Movement.

## player's movement state relays.
@rpc("authority", "unreliable_ordered")
func update_remote_player(peer_id: int, pos: Vector2, anim_state: String, facing: Vector2, flip_h: bool) -> void:
	var registries := get_tree().get_nodes_in_group("player_registry")
	var registry = registries[0] if not registries.is_empty() else null
	if not registry:
		return
		
	var remote_player = registry.get_remote_player(peer_id)
	if remote_player:
		remote_player.sync_position = pos
		remote_player.sync_anim_state = anim_state
		remote_player.sync_facing = facing
		remote_player.sync_flip_h = flip_h


@rpc("authority", "reliable")
func force_position(pos: Vector2) -> void:
	for player in get_tree().get_nodes_in_group("local_player"):
		print("[MultiplayerManager] force_position called: snapping player from %s → %s" % [player.global_position, pos])
		player.global_position = pos
		if "sync_position" in player:
			player.sync_position = pos
		return


func _read_arg_or_env(arg_name: String, env_name: String, default_value: String) -> String:
	var prefix := "--" + arg_name + "="
	for arg in OS.get_cmdline_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	var env_value := OS.get_environment(env_name)
	return env_value if not env_value.is_empty() else default_value


# Farm Invitation

func send_farm_invite(target_user_id: int) -> void:
	var server_node: Node = get_tree().root.get_node_or_null("ServerScene")
	if server_node and multiplayer.has_multiplayer_peer():
		server_node.send_farm_invite.rpc_id(1, target_user_id)


@rpc("authority", "reliable")
func receive_farm_invite(inviter_name: String, inviter_user_id: int) -> void:
	if _invite_dialog != null:
		_invite_dialog.queue_free()
		_invite_dialog = null
	
	_pending_invite_user_id = inviter_user_id
	
	_invite_dialog = ConfirmationDialog.new()
	_invite_dialog.title = tr("FARM_INVITATION")
	_invite_dialog.dialog_text = tr("FARM_INVITE_PROMPT") % inviter_name
	_invite_dialog.confirmed.connect(_on_invite_confirmed)
	_invite_dialog.canceled.connect(_on_invite_canceled)
	get_tree().root.add_child(_invite_dialog)
	_invite_dialog.popup_centered()


func _on_invite_confirmed() -> void:
	if _pending_invite_user_id > 0:
		var target_map_id := "game_" + str(_pending_invite_user_id)
		var approved: bool = await request_map_change(target_map_id)
		if approved:
			TransitionManager.transition_to("res://scenes/game.tscn")
		else:
			ToastManager.show_toast(tr("FAILED_TO_JOIN_FARM"), ToastManager.Type.WARNING)
	_cleanup_invite_dialog()


func _on_invite_canceled() -> void:
	_cleanup_invite_dialog()


func _cleanup_invite_dialog() -> void:
	if _invite_dialog != null:
		_invite_dialog.queue_free()
		_invite_dialog = null
	_pending_invite_user_id = -1


@rpc("authority", "reliable")
func farm_invite_sent_status(success: bool, friend_name: String) -> void:
	if success:
		ToastManager.show_toast(tr("INVITATION_SENT") % friend_name, ToastManager.Type.SUCCESS)
	else:
		ToastManager.show_toast(tr("FRIEND_OFFLINE_OR_NOT_IN_GAME"), ToastManager.Type.WARNING)


func broadcast_farm_slots(slots_data: Dictionary) -> void:
	var server_node: Node = get_tree().root.get_node_or_null("ServerScene")
	if server_node and multiplayer.has_multiplayer_peer():
		server_node.sync_farm_slots_from_owner.rpc_id(1, local_map_id, slots_data)


func get_profile_save_path() -> String:
	var profile := ""
	var prefix := "--profile="
	for arg in OS.get_cmdline_args():
		if arg.begins_with(prefix):
			profile = arg.substr(prefix.length())
			break
	if not profile.is_empty():
		return "user://credentials_" + profile + ".cfg"
	return "user://credentials.cfg"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_player_position()

# For showcase.
func save_player_position() -> void:
	var player = get_tree().get_first_node_in_group("local_player")
	if player != null:
		var path := get_profile_save_path()
		var config := ConfigFile.new()
		config.load(path)
		config.set_value("position", "scene", local_scene_name)
		config.set_value("position", "x", player.global_position.x)
		config.set_value("position", "y", player.global_position.y)
		config.save(path)
		print("[MultiplayerManager] Saved player position: %s in scene %s" % [player.global_position, local_scene_name])


@rpc("authority", "reliable")
func receive_friend_request_notification(request_data: Dictionary) -> void:
	FriendManager.handle_rpc_friend_request(request_data)


@rpc("authority", "reliable")
func receive_trade_request(trade_data: Dictionary) -> void:
	TradeManager.handle_rpc_trade_request(trade_data)


@rpc("authority", "reliable")
func receive_trade_updated(trade_data: Dictionary) -> void:
	TradeManager.handle_rpc_trade_updated(trade_data)


@rpc("authority", "reliable")
func receive_trade_canceled() -> void:
	TradeManager.handle_rpc_trade_canceled()


@rpc("authority", "reliable")
func receive_login_rejected(reason: String) -> void:
	ToastManager.show_toast(reason, ToastManager.Type.ERROR)
	disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/auth.tscn")

