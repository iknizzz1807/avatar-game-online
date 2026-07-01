extends Area2D
class_name TeleportZone


@export_group("Teleport")
@export var target_map_id: String = "cave"
@export var spawn_position: Vector2 = Vector2(160, 100)

var _teleporting: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _teleporting:
		return
	if not (body is CharacterBody2D and (not _has_active_multiplayer_peer() or body.is_multiplayer_authority())):
		return

	_teleporting = true

	TeleportData.spawn_position = spawn_position

	if MultiplayerManager and _has_active_multiplayer_peer():
		var approved: bool = await MultiplayerManager.request_map_change(target_map_id)
		if not approved:
			_teleporting = false
			TeleportData.spawn_position = Vector2.ZERO
			push_warning("[TeleportZone] Server denied map change — TeleportData cleared.")
			return
	elif MultiplayerManager:
		MultiplayerManager.set_map(target_map_id)
	TransitionManager.transition_to("res://scenes/%s.tscn" % target_map_id)


func _has_active_multiplayer_peer() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
