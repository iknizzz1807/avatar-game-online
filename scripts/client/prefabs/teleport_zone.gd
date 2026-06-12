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
	if not (body is CharacterBody2D and body.is_multiplayer_authority()):
		return

	_teleporting = true

	# Store the desired spawn position so the new scene can read it.
	TeleportData.spawn_position = spawn_position

	# Tell the server (and other clients) we have changed maps.
	if MultiplayerManager:
		MultiplayerManager.notify_map_changed(target_map_id)

	# Load the target scene.
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % target_map_id)
