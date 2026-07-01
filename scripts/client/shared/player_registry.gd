extends Node

# Scene-level. Used to track all remote players in the scene.

const REMOTE_PLAYER_SCENE: PackedScene = preload("res://prefabs/characters/remote_player.tscn")

var _remote_players: Dictionary = {}

@export var players_container: NodePath = NodePath(".")
var _container: Node


func _ready() -> void:
	add_to_group("player_registry")
	_container = get_node(players_container)

	MultiplayerManager.player_joined.connect(_on_player_joined)
	MultiplayerManager.player_left.connect(_on_player_left)
	
	MultiplayerManager.send_registration()


func _on_player_joined(peer_id: int, user_id: int, display_name: String) -> void:
	if _remote_players.has(peer_id):
		push_warning("[PlayerRegistry] Player peer=%d already exists — skipping spawn." % peer_id)
		return

	var node: Node = REMOTE_PLAYER_SCENE.instantiate()
	node.name             = "RemotePlayer_%d" % peer_id
	node.peer_id          = peer_id
	node.user_id          = user_id
	node.display_name_text = display_name
	if node.has_method("configure_context_menu"):
		node.configure_context_menu(user_id, display_name)

	_container.add_child(node)
	_remote_players[peer_id] = node


func _on_player_left(peer_id: int) -> void:
	if not _remote_players.has(peer_id):
		return

	var node: Node = _remote_players[peer_id]
	node.queue_free()
	_remote_players.erase(peer_id)

func get_remote_player(peer_id: int) -> Node:
	return _remote_players.get(peer_id, null)

func get_all_remote_players() -> Array:
	return _remote_players.values()
