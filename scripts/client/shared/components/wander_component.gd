## WanderComponent
## ─────────────────────────────────────────────────────────────────────────────
## Drop this Node as a child of any CharacterBody2D NPC to give it autonomous
## wander behaviour.  The component owns two timers (idle & walk phases) and
## drives an AnimatedSprite2D by playing "idle" / "walk" animations.
##
## The owning body should read `velocity_wish` each physics frame and apply it:
##
##   func _physics_process(delta):
##       velocity = $WanderComponent.velocity_wish
##       move_and_slide()
##
## Or connect to `state_changed` if you need custom animation logic.
## ─────────────────────────────────────────────────────────────────────────────
extends Node
class_name WanderComponent

# ── Exports ───────────────────────────────────────────────────────────────────

## Walk speed passed to the owning body (pixels / second).
@export var walk_speed: float = 30.0

## Minimum seconds spent in the idle phase.
@export var idle_time_min: float = 1.5
## Maximum seconds spent in the idle phase.
@export var idle_time_max: float = 4.0

## Minimum seconds spent walking before going idle.
@export var walk_time_min: float = 0.8
## Maximum seconds spent walking before going idle.
@export var walk_time_max: float = 2.5

## NodePath to the AnimatedSprite2D on the owner that should be driven.
## Leave empty to skip animation control entirely.
@export var animatedSprite : AnimatedSprite2D;

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted every time the wander state flips.
## is_walking: true  → component just started a walk phase
## is_walking: false → component just entered idle
signal state_changed(is_walking: bool, direction: Vector2)

# ── Public read-only ──────────────────────────────────────────────────────────

## The velocity the owning body should apply this frame.
var velocity_wish: Vector2 = Vector2.ZERO

## Current movement direction (unit vector, zero when idle).
var direction: Vector2 = Vector2.ZERO

## Whether the component is currently in the walk phase.
var is_walking: bool = false

# ── Private ───────────────────────────────────────────────────────────────────

var _timer: Timer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	assert(animatedSprite != null, "Animated sprite must be assigned");

	# Internal one-shot timer — restarted each phase
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	_enter_idle()


# ── Phase transitions ─────────────────────────────────────────────────────────

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

	print("walking");
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
