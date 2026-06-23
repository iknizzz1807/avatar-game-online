extends Area2D
class_name TeleportZone

# ═════════════════════════════════════════════════════════════════════════════
# TELEPORT ZONE
#
# Place this Area2D (with a CollisionShape2D child) anywhere on a map.
# When the local (authority) player walks into it they are:
#   1. Repositioned to `spawn_position` on the new map.
#   2. Transitioned to the target scene via change_scene_to_file.
#   3. Notified to the server via MultiplayerManager.notify_map_changed.
#
# The scene file must live at:  res://scenes/<target_map_id>.tscn
# ═════════════════════════════════════════════════════════════════════════════

@export_group("Teleport")
## The map ID to travel to (must match a .tscn filename in res://scenes/).
@export var target_map_id: String = "cave"
## Where the player will appear on the target map (world-space pixels).
@export var spawn_position: Vector2 = Vector2(160, 100)

## Prevent double-firing while the scene transition is in flight.
var _teleporting: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _teleporting:
		return
	# Only react to the locally-controlled player.
	if not (body is CharacterBody2D and (not _has_active_multiplayer_peer() or body.is_multiplayer_authority())):
		return

	_teleporting = true

	print("[TeleportZone] Player entered zone → target='%s'  spawn_pos=%s  player_pos=%s" % [
		target_map_id, spawn_position, body.global_position
	])

	# Store the desired spawn position so the new scene can read it.
	TeleportData.spawn_position = spawn_position
	print("[TeleportZone] TeleportData.spawn_position set to %s" % TeleportData.spawn_position)

	if MultiplayerManager and _has_active_multiplayer_peer():
		var approved: bool = await MultiplayerManager.request_map_change(target_map_id)
		if not approved:
			_teleporting = false
			TeleportData.spawn_position = Vector2.ZERO
			push_warning("[TeleportZone] Server denied map change — TeleportData cleared.")
			return
		print("[TeleportZone] Server approved map change to '%s'" % target_map_id)
	elif MultiplayerManager:
		MultiplayerManager.set_map(target_map_id)

	print("[TeleportZone] Changing scene → res://scenes/%s.tscn" % target_map_id)
	# Load the target scene.
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % target_map_id)


func _has_active_multiplayer_peer() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
