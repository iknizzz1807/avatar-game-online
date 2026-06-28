extends Node2D
class_name FishingLineDrawer

@export var line_color: Color = Color(0.92, 0.86, 0.68, 0.95)
@export var line_width: float = 1.5
@export var bobber_color: Color = Color(1.0, 0.18, 0.12, 1.0)
@export var bobber_radius: float = 3.0

var _lines: Dictionary = {}


func update_line_points(owner_key: String, new_points: PackedVector2Array) -> void:
	if new_points.size() < 2:
		_lines.erase(owner_key)
	else:
		_lines[owner_key] = new_points
	queue_redraw()


func clear_line(owner_key: String) -> void:
	if _lines.erase(owner_key):
		queue_redraw()


func _process(_delta: float) -> void:
	_lock_to_world_space()


func _draw() -> void:
	_lock_to_world_space()
	for points in _lines.values():
		if points.size() < 2:
			continue
		draw_polyline(points, line_color, line_width, true)
		draw_circle(points[points.size() - 1], bobber_radius, bobber_color)


func _lock_to_world_space() -> void:
	# _draw() uses local coordinates. Keeping this node at world origin lets
	# callers pass raw global points without player transform drift.
	global_position = Vector2.ZERO
	global_rotation = 0.0
	global_scale = Vector2.ONE
