extends Node

# ═════════════════════════════════════════════════════════════════════════════
# PLAYER REGISTRY — Scene-level singleton (NOT a global Autoload).
#
# Place this node in game.tscn. It listens to MultiplayerManager signals and
# maintains the dictionary of live RemotePlayer nodes.
#
# The remote_player.tscn scene is used for all other players.
# ═════════════════════════════════════════════════════════════════════════════

const REMOTE_PLAYER_SCENE: PackedScene = preload("res://prefabs/characters/remote_player.tscn")

# peer_id → RemotePlayer node
var _remote_players: Dictionary = {}

## Parent node where RemotePlayer nodes are added (set in _ready via export).
@export var players_container: NodePath = NodePath(".")
var _container: Node


func _ready() -> void:
	_container = get_node(players_container)

	MultiplayerManager.player_joined.connect(_on_player_joined)
	MultiplayerManager.player_left.connect(_on_player_left)


# ─── Signal handlers ──────────────────────────────────────────────────────────

func _on_player_joined(peer_id: int, user_id: int, display_name: String) -> void:
	if _remote_players.has(peer_id):
		push_warning("[PlayerRegistry] Player peer=%d already exists — skipping spawn." % peer_id)
		return

	var node: RemotePlayer = REMOTE_PLAYER_SCENE.instantiate() as RemotePlayer
	node.name             = "RemotePlayer_%d" % peer_id
	node.peer_id          = peer_id
	node.user_id          = user_id
	node.display_name_text = display_name

	_container.add_child(node)
	_remote_players[peer_id] = node
	print("[PlayerRegistry] Spawned RemotePlayer for %s (peer=%d)" % [display_name, peer_id])


func _on_player_left(peer_id: int) -> void:
	if not _remote_players.has(peer_id):
		return

	var node: RemotePlayer = _remote_players[peer_id]
	node.queue_free()
	_remote_players.erase(peer_id)
	print("[PlayerRegistry] Removed RemotePlayer peer=%d" % peer_id)


# ─── Public helpers ───────────────────────────────────────────────────────────

## Returns the RemotePlayer node for a given peer_id, or null.
func get_remote_player(peer_id: int) -> RemotePlayer:
	return _remote_players.get(peer_id, null) as RemotePlayer


## Returns all currently tracked remote players.
func get_all_remote_players() -> Array:
	return _remote_players.values()
