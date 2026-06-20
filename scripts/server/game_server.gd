extends Node

# ═════════════════════════════════════════════════════════════════════════════
# GAME SERVER — Dedicated Server Root
#
# Launch with:  ./avatar-game-online.x86_64 --headless --server
# Or in editor: add --server to the run arguments.
#
# Responsibilities:
#   • Create ENet listen server on PORT
#   • Accept clients and wait for their register_player() RPC
#   • Broadcast joined/left events to all peers in the same map
#   • The server is the MultiplayerSpawner authority — it spawns player nodes
#     for newly connected peers and despawns them on disconnect.
# ═════════════════════════════════════════════════════════════════════════════

const PORT: int = 7777
const MAX_CLIENTS: int = 64

# peer_id → { user_id, display_name, map_id }
var _players: Dictionary = {}

# Reference to the spawner so we can call spawn/despawn
@onready var _spawner: MultiplayerSpawner = $MultiplayerSpawner


func _ready() -> void:
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
	# Player is not registered yet — they must call register_player() first.


func _on_peer_disconnected(peer_id: int) -> void:
	print("[GameServer] Peer disconnected: %d" % peer_id)
	if not _players.has(peer_id):
		return

	var info: Dictionary = _players[peer_id]

	# Despawn this player's node on all clients
	var node_path: String = "Player_%d" % peer_id
	var node: Node = get_node_or_null(node_path)
	if node:
		node.queue_free()

	# Notify remaining peers
	var map_id: String = info.get("map_id", "")
	_broadcast_player_left(peer_id, map_id)

	_players.erase(peer_id)
	print("[GameServer] Player %s (peer %d) unregistered" % [info.get("display_name", "?"), peer_id])


# ─── Client → Server RPCs ─────────────────────────────────────────────────────

## Called by the client immediately after the ENet connection is established.
## user_id and display_name come from the Go REST login response.
## map_id is the player's current map (e.g. "world", "farm_42").
@rpc("any_peer", "reliable")
func register_player(user_id: int, display_name: String, map_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()

	if _players.has(sender_id):
		push_warning("[GameServer] Peer %d tried to register twice — ignoring" % sender_id)
		return

	_players[sender_id] = {
		"user_id":      user_id,
		"display_name": display_name,
		"map_id":       map_id,
	}
	print("[GameServer] Registered: %s (uid=%d, peer=%d, map=%s)" % [
		display_name, user_id, sender_id, map_id
	])

	# Tell the new peer about every player already on the same map
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

	# Tell everyone else on the same map about the new player
	_broadcast_player_joined(sender_id, user_id, display_name, map_id)


## Called by the client when the player changes maps.
@rpc("any_peer", "reliable")
func change_map(new_map_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _players.has(sender_id):
		return

	var old_map: String = _players[sender_id].get("map_id", "")
	_players[sender_id]["map_id"] = new_map_id

	# Notify players on the old map that this peer left
	_broadcast_player_left(sender_id, old_map)

	# Notify players on the new map
	var info: Dictionary = _players[sender_id]
	_broadcast_player_joined(sender_id, info.get("user_id", -1), info.get("display_name", ""), new_map_id)


## Called by the client every physics frame to sync movement.
@rpc("any_peer", "unreliable_ordered")
func sync_player_state(pos: Vector2, anim_state: String, facing: Vector2, flip_h: bool) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _players.has(sender_id):
		return
		
	var map_id: String = _players[sender_id].get("map_id", "")
	
	# Relay to everyone else on the same map
	for target_id: int in _players:
		if target_id == sender_id:
			continue
		if _players[target_id].get("map_id", "") != map_id:
			continue
		MultiplayerManager.update_remote_player.rpc_id(target_id, sender_id, pos, anim_state, facing, flip_h)




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
