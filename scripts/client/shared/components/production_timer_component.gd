
extends Node
class_name ProductionTimerComponent

@export var interval: float = 10.0
@export var drop_scene: PackedScene = null

signal produced(spawn_position: Vector2)

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot  = false
	_timer.autostart = false
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

	if interval > 0.0:
		_timer.wait_time = interval
		_timer.start()

func set_interval(new_interval: float) -> void:
	interval = new_interval
	if interval > 0.0:
		_timer.wait_time = interval
		_timer.start()
	else:
		_timer.stop()

func set_active(active: bool) -> void:
	if active and interval > 0.0:
		_timer.start()
	else:
		_timer.stop()

func _on_timeout() -> void:
	var spawn_pos: Vector2 = get_parent().global_position
	emit_signal("produced", spawn_pos)

	if drop_scene != null:
		var drop := drop_scene.instantiate()
		get_parent().get_parent().add_child(drop)
		drop.global_position = spawn_pos
