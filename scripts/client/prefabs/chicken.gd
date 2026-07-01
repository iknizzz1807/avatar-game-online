extends CharacterBody2D

signal egg_laid(egg_position: Vector2)

@onready var _wander: WanderComponent           = $WanderComponent
@onready var _production: ProductionTimerComponent = $ProductionTimerComponent

func _ready() -> void:
	_production.produced.connect(_on_egg_produced)

func _physics_process(_delta: float) -> void:
	velocity = _wander.velocity_wish
	move_and_slide()

func _on_egg_produced(pos: Vector2) -> void:
	emit_signal("egg_laid", pos)
