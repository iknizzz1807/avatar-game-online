extends Node2D

@export var world_rect: Rect2 = Rect2(-320, -320, 1280, 1280)

func _ready() -> void:
	await get_tree().process_frame
	_configure_camera_limits()


func _configure_camera_limits() -> void:
	var player_node: Node = _find_local_player()
	if player_node == null:
		await get_tree().process_frame
		player_node = _find_local_player()
		if player_node == null:
			push_warning("[Game] Could not find local Player node to configure camera limits.")
			return

	var cam: Camera2D = player_node.get_node_or_null("Camera2D")
	if cam == null:
		push_warning("[Game] Player node has no Camera2D child.")
		return

	cam.limit_left   = int(world_rect.position.x)
	cam.limit_top    = int(world_rect.position.y)
	cam.limit_right  = int(world_rect.position.x + world_rect.size.x)
	cam.limit_bottom = int(world_rect.position.y + world_rect.size.y)

# TODO: fix
func _find_local_player() -> Node:
	for child in get_children():
		if child is CharacterBody2D and (not _has_active_multiplayer_peer() or child.is_multiplayer_authority()):
			return child
		for grandchild in child.get_children():
			if grandchild is CharacterBody2D and (not _has_active_multiplayer_peer() or grandchild.is_multiplayer_authority()):
				return grandchild
	return null


func _has_active_multiplayer_peer() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
