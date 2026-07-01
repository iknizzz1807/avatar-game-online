extends Node
class_name WanderComponent

@export var walk_speed: float = 30.0

@export var idle_time_min: float = 1.5
@export var idle_time_max: float = 4.0

@export var walk_time_min: float = 0.8
@export var walk_time_max: float = 2.5

@export var animatedSprite : AnimatedSprite2D;

signal state_changed(is_walking: bool, direction: Vector2)

var velocity_wish: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var is_walking: bool = false
var _timer: Timer

func _ready() -> void:
	assert(animatedSprite != null, "Animated sprite must be assigned");

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	_enter_idle()

func _enter_idle() -> void:
	is_walking    = false
	direction     = Vector2.ZERO
	velocity_wish = Vector2.ZERO

	animatedSprite.play("idle")

	_timer.wait_time = randf_range(idle_time_min, idle_time_max)
	_timer.start()

	state_changed.emit(false, Vector2.ZERO);


func _enter_walk() -> void:
	is_walking = true

	var angle  : float = randf_range(0.0, TAU)
	direction   = Vector2(cos(angle), sin(angle))
	velocity_wish = direction * walk_speed

	animatedSprite.flip_h = direction.x < 0.0
	animatedSprite.play("walk")

	_timer.wait_time = randf_range(walk_time_min, walk_time_max)
	_timer.start()

	state_changed.emit(true, direction);


func _on_timer_timeout() -> void:
	if is_walking:
		_enter_idle()
	else:
		_enter_walk()
