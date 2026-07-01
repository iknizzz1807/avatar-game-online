extends Node2D
class_name WorldBoundary

@export_group("Walls")
@export var wall_thickness: float = 64.0

@onready var _shape_node: CollisionShape2D = $CollisionShape2D

var _wall_bodies: Array[StaticBody2D] = []


func _ready() -> void:
	var rect : Rect2 = _rect_from_shape()

	_build_walls(rect)
	await get_tree().process_frame
	_apply_camera_limits(rect)


func _rect_from_shape() -> Rect2:
	assert(_shape_node != null, "[WorldBoundary] No CollisionShape2D child found. Add a CollisionShape2D named 'CollisionShape2D' as a child of this node.");
	assert(_shape_node.shape is RectangleShape2D, "[WorldBoundary] The CollisionShape2D must use a RectangleShape2D (box shape).");

	var box   : RectangleShape2D = _shape_node.shape as RectangleShape2D
	var center : Vector2 = _shape_node.global_position
	var half   : Vector2 = box.size * 0.5

	return Rect2(center - half, box.size)

func _build_walls(rect: Rect2) -> void:
	for body : StaticBody2D in _wall_bodies:
		body.queue_free()
	_wall_bodies.clear()

	var t : float = wall_thickness

	# Each entry: [center_x, center_y, slab_width, slab_height, node_name]
	var defs: Array = [
		# Top wall
		[rect.position.x + rect.size.x * 0.5,
		 rect.position.y - t * 0.5,
		 rect.size.x + t * 2.0, t,
		 "WallTop"],

		# Bottom wall
		[rect.position.x + rect.size.x * 0.5,
		 rect.position.y + rect.size.y + t * 0.5,
		 rect.size.x + t * 2.0, t,
		 "WallBottom"],

		# Left wall
		[rect.position.x - t * 0.5,
		 rect.position.y + rect.size.y * 0.5,
		 t, rect.size.y,
		 "WallLeft"],

		# Right wall
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


func _apply_camera_limits(rect: Rect2) -> void:
	var player : Node = _find_local_player()

	var retries := 5
	while player == null and retries > 0:
		await get_tree().process_frame
		player = _find_local_player()
		retries -= 1

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


func _find_local_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0]
	return _search(get_tree().root)


func _search(node: Node) -> Node:
	if node is Player and (not _has_active_multiplayer_peer() or node.is_multiplayer_authority()):
		return node
	for child in node.get_children():
		var result : Node = _search(child)
		if result != null:
			return result
	return null


func _has_active_multiplayer_peer() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
