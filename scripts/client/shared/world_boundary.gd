extends Node2D
class_name WorldBoundary

# ═════════════════════════════════════════════════════════════════════════════
# WORLD BOUNDARY
#
# Place a CollisionShape2D child named "CollisionShape2D" with a
# RectangleShape2D inside this node.  The script reads that shape's
# world-space position and size at runtime to:
#
#   1. Build four thick StaticBody2D + RectangleShape2D wall slabs around the
#      zone so the player (move_and_slide) is physically blocked.
#   2. Set the local player's Camera2D limit_* so the camera never pans
#      outside the zone.
#
# To resize the zone: select the CollisionShape2D in the Godot editor and
# drag its orange handles.  The walls and camera limits update every run.
# ═════════════════════════════════════════════════════════════════════════════

@export_group("Walls")
## Thickness of each invisible wall slab in pixels.
## Must be large enough that a fast player cannot tunnel through in one frame.
@export var wall_thickness: float = 64.0

# ─── Internal ─────────────────────────────────────────────────────────────────

@onready var _shape_node: CollisionShape2D = $CollisionShape2D

var _wall_bodies: Array[StaticBody2D] = []


func _ready() -> void:
	# Derive the playable Rect2 from the child CollisionShape2D.
	var rect : Rect2 = _rect_from_shape()

	_build_walls(rect)

	# Wait one frame so MultiplayerManager has time to spawn the local Player.
	await get_tree().process_frame
	_apply_camera_limits(rect)


# ─── Rect extraction ──────────────────────────────────────────────────────────

## Reads the child CollisionShape2D (must have a RectangleShape2D) and returns
## the equivalent world-space Rect2 based on its global position and size.
func _rect_from_shape() -> Rect2:
	assert(
		_shape_node != null,
		"[WorldBoundary] No CollisionShape2D child found. " +
		"Add a CollisionShape2D named 'CollisionShape2D' as a child of this node."
	)
	assert(
		_shape_node.shape is RectangleShape2D,
		"[WorldBoundary] The CollisionShape2D must use a RectangleShape2D (box shape)."
	)

	var box   : RectangleShape2D = _shape_node.shape as RectangleShape2D
	# global_position of the CollisionShape2D is the box center in world space.
	var center : Vector2 = _shape_node.global_position
	var half   : Vector2 = box.size * 0.5

	return Rect2(center - half, box.size)


# ─── Wall construction ────────────────────────────────────────────────────────

## Destroys any previous walls and rebuilds four RectangleShape2D slabs that
## surround `rect`.  Horizontal walls are widened by `wall_thickness` on each
## side so the corners are fully sealed.
func _build_walls(rect: Rect2) -> void:
	for body : StaticBody2D in _wall_bodies:
		body.queue_free()
	_wall_bodies.clear()

	var t : float = wall_thickness

	# Each entry: [center_x, center_y, slab_width, slab_height, node_name]
	var defs: Array = [
		# Top wall — sits flush above the rect
		[rect.position.x + rect.size.x * 0.5,
		 rect.position.y - t * 0.5,
		 rect.size.x + t * 2.0, t,
		 "WallTop"],

		# Bottom wall — sits flush below the rect
		[rect.position.x + rect.size.x * 0.5,
		 rect.position.y + rect.size.y + t * 0.5,
		 rect.size.x + t * 2.0, t,
		 "WallBottom"],

		# Left wall — spans the interior height only (corners covered by H walls)
		[rect.position.x - t * 0.5,
		 rect.position.y + rect.size.y * 0.5,
		 t, rect.size.y,
		 "WallLeft"],

		# Right wall — same
		[rect.position.x + rect.size.x + t * 0.5,
		 rect.position.y + rect.size.y * 0.5,
		 t, rect.size.y,
		 "WallRight"],
	]

	for d in defs:
		var body : StaticBody2D = StaticBody2D.new()
		body.name = d[4]

		var col : CollisionShape2D = CollisionShape2D.new()
		var box : RectangleShape2D = RectangleShape2D.new()
		box.size = Vector2(d[2], d[3])
		col.shape = box

		body.position = Vector2(d[0], d[1])
		body.add_child(col)
		add_child(body)
		_wall_bodies.append(body)

	print("[WorldBoundary] 4 walls built from shape rect: ", rect)


# ─── Camera limits ────────────────────────────────────────────────────────────

## Finds the local (authority) player's Camera2D and sets its limit_* values
## to exactly match `rect`.
func _apply_camera_limits(rect: Rect2) -> void:
	var player : Node = _find_local_player()

	if player == null:
		# One extra frame in case the host spawns slightly later.
		await get_tree().process_frame
		player = _find_local_player()

	if player == null:
		push_warning("[WorldBoundary] Local Player not found — camera limits NOT applied.")
		return

	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		push_warning("[WorldBoundary] Player has no Camera2D child — camera limits NOT applied.")
		return

	cam.limit_left   = int(rect.position.x)
	cam.limit_top    = int(rect.position.y)
	cam.limit_right  = int(rect.position.x + rect.size.x)
	cam.limit_bottom = int(rect.position.y + rect.size.y)

	print("[WorldBoundary] Camera limits → L:%d  T:%d  R:%d  B:%d" % [
		cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom
	])


# ─── Helpers ─────────────────────────────────────────────────────────────────

## Recursively searches the current scene for a CharacterBody2D that has
## multiplayer authority (the locally-controlled player).
func _find_local_player() -> Node:
	return _search(get_tree().current_scene)


func _search(node: Node) -> Node:
	if node is CharacterBody2D and (not multiplayer.has_multiplayer_peer() or node.is_multiplayer_authority()):
		return node
	for child in node.get_children():
		var result : Node = _search(child)
		if result != null:
			return result
	return null
