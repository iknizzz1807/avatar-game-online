extends Node

# ═════════════════════════════════════════════════════════════════════════════
# GAME SERVER — Dedicated Server Root
#
# Launch with:  ./avatar-game-online.x86_64 --headless --server
# Or in editor: add --server to the run arguments.
#
# Responsibilities:
#   • Create ENet listen server on PORT
#   • Accept clients and wait for authenticated registration RPC
#   • Broadcast joined/left events to all peers in the same map
#   • The server is the MultiplayerSpawner authority — it spawns player nodes
#     for newly connected peers and despawns them on disconnect.
# ═════════════════════════════════════════════════════════════════════════════

const PORT: int = 7777
const MAX_CLIENTS: int = 64
var api_base: String = "http://127.0.0.1:8080"
const CHAT_MAX_CHARS: int = 100
const CHAT_WINDOW_SECONDS: float = 5.0
const CHAT_MAX_IN_WINDOW: int = 3
const REGISTER_COOLDOWN_SECONDS: float = 2.0
const MAP_CHANGE_COOLDOWN_SECONDS: float = 2.0
const MOVEMENT_MAX_SPEED: float = 260.0
const MOVEMENT_GRACE_DISTANCE: float = 80.0

# peer_id → { user_id, display_name, map_id, auth_token }
var _players: Dictionary = {}
var _chat_times: Dictionary = {}
var _rpc_times: Dictionary = {}
var _last_movement: Dictionary = {}
var _pending_registrations: Dictionary = {}
var _pending_map_changes: Dictionary = {}

# Reference to the spawner so we can call spawn/despawn
@onready var _spawner: MultiplayerSpawner = $MultiplayerSpawner


func _ready() -> void:
	api_base = _read_arg_or_env("api-base", "API_BASE", api_base)
	if not _is_server_mode():
		# Not running as a dedicated server — do nothing.
		# The node still exists so the scene can be referenced from the editor.
		set_process(false)
		return

	_start_server()


func _is_server_mode() -> bool:
	return OS.has_feature("dedicated_server") \
		or "--server" in OS.get_cmdline_args()


func _start_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("[GameServer] Failed to create server on port %d (err=%d)" % [PORT, err])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("[GameServer] Listening on port %d (max %d clients)" % [PORT, MAX_CLIENTS])


# ─── Peer lifecycle ───────────────────────────────────────────────────────────

func _on_peer_connected(peer_id: int) -> void:
	print("[GameServer] Peer connected: %d" % peer_id)
	# Player is not registered yet — they must call register_player_with_token() first.


func _on_peer_disconnected(peer_id: int) -> void:
	print("[GameServer] Peer disconnected: %d" % peer_id)
	if not _players.has(peer_id):
		return

	var info: Dictionary = _players[peer_id]
	_stop_fishing_for_peer(info)

	# Despawn this player's node on all clients
	var node_path: String = "Player_%d" % peer_id
	var node: Node = get_node_or_null(node_path)
	if node:
		node.queue_free()

	# Notify remaining peers
	var map_id: String = info.get("map_id", "")
	_broadcast_player_left(peer_id, map_id)

	_players.erase(peer_id)
	_last_movement.erase(peer_id)
	_chat_times.erase(peer_id)
	_clear_rpc_limits(peer_id)
	_pending_registrations.erase(peer_id)
	_pending_map_changes.erase(peer_id)
	print("[GameServer] Player %s (peer %d) unregistered" % [info.get("display_name", "?"), peer_id])


# ─── Client → Server RPCs ─────────────────────────────────────────────────────

@rpc("any_peer", "reliable")
func register_player(_user_id: int, _display_name: String, _map_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	push_warning("[GameServer] Rejected unauthenticated legacy registration from peer %d" % sender_id)
	multiplayer.multiplayer_peer.disconnect_peer(sender_id)


## Called by the client immediately after the ENet connection is established,
## and also every time the client loads a new map (scene).
@rpc("any_peer", "reliable")
func register_player_with_token(token: String, map_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if _pending_registrations.has(sender_id) or not _allow_rpc(sender_id, "register", REGISTER_COOLDOWN_SECONDS):
		push_warning("[GameServer] Rejected registration spam from peer %d" % sender_id)
		multiplayer.multiplayer_peer.disconnect_peer(sender_id)
		return
	_pending_registrations[sender_id] = true
	var user: Dictionary = await _verify_token(token)
	_pending_registrations.erase(sender_id)
	if user.is_empty():
		push_warning("[GameServer] Rejected unauthenticated peer %d" % sender_id)
		multiplayer.multiplayer_peer.disconnect_peer(sender_id)
		return
	var verified_map_id: String = _map_id_from_user(user)
	_register_verified_player(sender_id, int(user.get("id", -1)), user.get("display_name", "Player"), verified_map_id, token)


func _register_verified_player(sender_id: int, user_id: int, display_name: String, map_id: String, auth_token: String = "") -> void:

	if _players.has(sender_id):
		# Player is already registered. They just loaded a scene and want a state sync.
		var old_map: String = _players[sender_id].get("map_id", "")
		_players[sender_id]["map_id"] = map_id
		if not auth_token.is_empty():
			_players[sender_id]["auth_token"] = auth_token
		
		# If the map changed, broadcast to others
		if old_map != map_id:
			print("[GameServer] Map change peer=%d: '%s' → '%s'  clearing last_movement" % [sender_id, old_map, map_id])
			_last_movement.erase(sender_id)
			_broadcast_player_left(sender_id, old_map)
			_broadcast_player_joined(sender_id, user_id, display_name, map_id)
	else:
		_players[sender_id] = {
			"user_id":      user_id,
			"display_name": display_name,
			"map_id":       map_id,
			"auth_token":   auth_token,
		}
		print("[GameServer] Registered: %s (uid=%d, peer=%d, map=%s)" % [
			display_name, user_id, sender_id, map_id
		])
		_broadcast_player_joined(sender_id, user_id, display_name, map_id)

	# Tell the peer about every player already on the map
	for existing_peer_id: int in _players:
		if existing_peer_id == sender_id:
			continue
		var other: Dictionary = _players[existing_peer_id]
		if other.get("map_id", "") != map_id:
			continue
		MultiplayerManager._client_player_joined.rpc_id(sender_id,
			existing_peer_id,
			other.get("user_id", -1),
			other.get("display_name", ""),
			map_id
		)


@rpc("any_peer", "reliable")
func request_map_change(scene_name: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _players.has(sender_id):
		return
	if _pending_map_changes.has(sender_id) or not _allow_rpc(sender_id, "map_change", MAP_CHANGE_COOLDOWN_SECONDS):
		MultiplayerManager.map_change_denied.rpc_id(sender_id)
		return

	var info: Dictionary = _players[sender_id]
	var token: String = info.get("auth_token", "")
	var server_map_name := _server_map_from_scene(scene_name)
	if token.is_empty() or not _is_allowed_server_map(server_map_name):
		MultiplayerManager.map_change_denied.rpc_id(sender_id)
		return

	_pending_map_changes[sender_id] = true
	if not await _update_user_map(token, server_map_name):
		_pending_map_changes.erase(sender_id)
		MultiplayerManager.map_change_denied.rpc_id(sender_id)
		return
	_pending_map_changes.erase(sender_id)

	MultiplayerManager.map_change_approved.rpc_id(sender_id, scene_name)


func _is_allowed_server_map(server_map_name: String) -> bool:
	return server_map_name in [
		"farm",
		"central_park",
		"fishing_lake",
		"town",
		"cave",
	]


func _server_map_from_scene(scene_name: String) -> String:
	match scene_name:
		"game":
			return "farm"
		"park":
			return "central_park"
		"fish_pond":
			return "fishing_lake"
		_:
			return scene_name


func _update_user_map(token: String, server_map_name: String) -> bool:
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token,
	])
	var body := JSON.stringify({ "map": server_map_name })
	var err := http.request(api_base + "/api/user/map", headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		http.queue_free()
		return false
	var response = await http.request_completed
	http.queue_free()
	return int(response[0]) == HTTPRequest.RESULT_SUCCESS and int(response[1]) == 200


func _stop_fishing_for_peer(info: Dictionary) -> void:
	var token: String = info.get("auth_token", "")
	if token.is_empty():
		return
	_stop_fishing_for_token(token)


func _stop_fishing_for_token(token: String) -> void:
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token,
	])
	var err := http.request(api_base + "/api/fishing/stop", headers, HTTPClient.METHOD_POST, "{}")
	if err != OK:
		http.queue_free()
		return
	await http.request_completed
	http.queue_free()


func _verify_token(token: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token,
	])
	var err := http.request(api_base + "/api/user/me", headers, HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return {}
	var response = await http.request_completed
	http.queue_free()
	var result: int = response[0]
	var code: int = response[1]
	var body: PackedByteArray = response[3]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


func _map_id_from_user(user: Dictionary) -> String:
	var user_id: int = int(user.get("id", -1))
	var current_map: String = user.get("current_map", "central_park")
	match current_map:
		"farm", "game":
			return "game_" + str(user_id)
		"central_park":
			return "park"
		"fishing_lake":
			return "fish_pond"
		"":
			return "park"
		_:
			return current_map

## Called by the client every physics frame to sync movement.
@rpc("any_peer", "unreliable_ordered")
func sync_player_state(map_id: String, pos: Vector2, anim_state: String, facing: Vector2, flip_h: bool) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _players.has(sender_id):
		return
	if _players[sender_id].get("map_id", "") != map_id:
		return
	if not _is_movement_valid(sender_id, pos):
		var last: Dictionary = _last_movement.get(sender_id, {})
		var last_pos: Vector2 = last.get("pos", pos)
		push_warning("[GameServer] FORCE_POSITION peer=%d  reported=%s  last_known=%s  dist=%.1fpx" % [
			sender_id, pos, last_pos, last_pos.distance_to(pos)
		])
		MultiplayerManager.force_position.rpc_id(sender_id, last_pos)
		return
		

	
	# Relay to everyone else on the same map
	for target_id: int in _players:
		if target_id == sender_id:
			continue
		if _players[target_id].get("map_id", "") == map_id:
			MultiplayerManager.update_remote_player.rpc_id(target_id, sender_id, pos, anim_state, facing, flip_h)


func _is_movement_valid(peer_id: int, pos: Vector2) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if not _last_movement.has(peer_id):
		_last_movement[peer_id] = { "pos": pos, "time": now }
		return true

	var last: Dictionary = _last_movement[peer_id]
	var last_pos: Vector2 = last.get("pos", pos)
	var last_time: float = float(last.get("time", now))
	var dt: float = maxf(now - last_time, 1.0 / 60.0)
	var allowed_distance: float = MOVEMENT_MAX_SPEED * dt + MOVEMENT_GRACE_DISTANCE
	var distance: float = last_pos.distance_to(pos)
	if distance > allowed_distance:
		push_warning("[GameServer] Ignored suspicious movement from peer %d: %.2fpx in %.3fs" % [peer_id, distance, dt])
		return false

	_last_movement[peer_id] = { "pos": pos, "time": now }
	return true

# ─── Farm Sync RPCs ──────────────────────────────────────────────────────────

@rpc("any_peer", "reliable")
func request_farm_action(_map_id: String, plot_id: int, _action: String, _data: String) -> void:
	# Farm state is authoritative in the Go API. Client-triggered broadcast was
	# intentionally disabled to avoid reload amplification/DDoS from forged RPCs.
	pass


@rpc("any_peer", "reliable")
func notify_farm_changed(plot_id: int) -> void:
	# Kept as a harmless no-op for older clients; do not broadcast client-supplied
	# farm events. The actor already applies the Go API response locally.
	pass


@rpc("any_peer", "reliable")
func receive_chat(text: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _players.has(sender_id):
		return
	var trimmed := text.strip_edges().left(CHAT_MAX_CHARS)
	if trimmed.is_empty() or not _allow_chat(sender_id):
		return
	var sender: Dictionary = _players[sender_id]
	var map_id: String = sender.get("map_id", "")
	var display_name: String = sender.get("display_name", "Player")
	for target_id: int in _players:
		if target_id == sender_id:
			continue
		if _players[target_id].get("map_id", "") == map_id:
			MultiplayerManager.broadcast_chat.rpc_id(target_id, sender_id, display_name, trimmed)


func _allow_chat(peer_id: int) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var times: Array = _chat_times.get(peer_id, [])
	var fresh: Array = []
	for t in times:
		if now - float(t) <= CHAT_WINDOW_SECONDS:
			fresh.append(t)
	if fresh.size() >= CHAT_MAX_IN_WINDOW:
		_chat_times[peer_id] = fresh
		return false
	fresh.append(now)
	_chat_times[peer_id] = fresh
	return true


func _allow_rpc(peer_id: int, rpc_name: String, cooldown_seconds: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var key := "%d:%s" % [peer_id, rpc_name]
	var last_time := float(_rpc_times.get(key, -cooldown_seconds))
	if now - last_time < cooldown_seconds:
		return false
	_rpc_times[key] = now
	return true


func _clear_rpc_limits(peer_id: int) -> void:
	var prefix := "%d:" % peer_id
	for key in _rpc_times.keys():
		if str(key).begins_with(prefix):
			_rpc_times.erase(key)


func _read_arg_or_env(arg_name: String, env_name: String, default_value: String) -> String:
	var prefix := "--" + arg_name + "="
	for arg in OS.get_cmdline_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	var env_value := OS.get_environment(env_name)
	return env_value if not env_value.is_empty() else default_value


# ─── Broadcast helpers ───────────────────────────────────────────────────────

func _broadcast_player_joined(peer_id: int, user_id: int, display_name: String, map_id: String) -> void:
	for target_id: int in _players:
		if target_id == peer_id:
			continue
		if _players[target_id].get("map_id", "") != map_id:
			continue
		MultiplayerManager._client_player_joined.rpc_id(target_id, peer_id, user_id, display_name, map_id)


func _broadcast_player_left(peer_id: int, map_id: String) -> void:
	for target_id: int in _players:
		if target_id == peer_id:
			continue
		if _players[target_id].get("map_id", "") != map_id:
			continue
		MultiplayerManager._client_player_left.rpc_id(target_id, peer_id)
