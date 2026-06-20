## Chicken
## ─────────────────────────────────────────────────────────────────────────────
## Thin host script – all behaviour lives in child components:
##
##   WanderComponent         → random idle / walk movement
##   ProductionTimerComponent → periodic egg production
##
## To add a new animal (e.g. Cow), duplicate this scene, swap the sprite,
## and either reuse these same components or swap ProductionTimerComponent
## for a custom one.
## ─────────────────────────────────────────────────────────────────────────────
extends CharacterBody2D

# ── Signals ───────────────────────────────────────────────────────────────────

## Re-emitted from ProductionTimerComponent for convenience.
signal egg_laid(egg_position: Vector2)

# ── Child components ──────────────────────────────────────────────────────────

@onready var _wander: WanderComponent           = $WanderComponent
@onready var _production: ProductionTimerComponent = $ProductionTimerComponent

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_production.produced.connect(_on_egg_produced)


func _physics_process(_delta: float) -> void:
	velocity = _wander.velocity_wish
	move_and_slide()

# ── Handlers ──────────────────────────────────────────────────────────────────

func _on_egg_produced(pos: Vector2) -> void:
	emit_signal("egg_laid", pos)
