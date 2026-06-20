## ProductionTimerComponent
## ─────────────────────────────────────────────────────────────────────────────
## Drop this Node as a child of any NPC to give it periodic item production
## (eggs from chickens, milk from cows, wool from sheep, etc.).
##
## When the timer fires it:
##   1. Emits  `produced(global_position)`  so you can handle it in GDScript.
##   2. Optionally spawns `drop_scene` into the parent's parent (the world).
##
## Usage:
##   $ProductionTimer.produced.connect(_on_produced)
##   func _on_produced(pos: Vector2): ...
## ─────────────────────────────────────────────────────────────────────────────
extends Node
class_name ProductionTimerComponent

# ── Exports ───────────────────────────────────────────────────────────────────

## Seconds between each production event.  Set to 0 to disable entirely.
@export var interval: float = 10.0

## Scene to spawn at the NPC's position on each production event (optional).
## Leave null to only use the signal.
@export var drop_scene: PackedScene = null

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted each time the production timer fires.
## `spawn_position` is the NPC's global_position at the moment of production.
signal produced(spawn_position: Vector2)

# ── Private ───────────────────────────────────────────────────────────────────

var _timer: Timer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot  = false
	_timer.autostart = false
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

	if interval > 0.0:
		_timer.wait_time = interval
		_timer.start()

# ── Public API ────────────────────────────────────────────────────────────────

## Change the interval at runtime.  Restarts the current countdown.
func set_interval(new_interval: float) -> void:
	interval = new_interval
	if interval > 0.0:
		_timer.wait_time = interval
		_timer.start()
	else:
		_timer.stop()

## Pause / resume production without changing the interval.
func set_active(active: bool) -> void:
	if active and interval > 0.0:
		_timer.start()
	else:
		_timer.stop()

# ── Private ───────────────────────────────────────────────────────────────────

func _on_timeout() -> void:
	var spawn_pos: Vector2 = get_parent().global_position
	emit_signal("produced", spawn_pos)

	if drop_scene != null:
		var drop := drop_scene.instantiate()
		# Spawn into the world (parent of the NPC), not inside the NPC itself
		get_parent().get_parent().add_child(drop)
		drop.global_position = spawn_pos
