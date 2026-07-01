
extends CharacterBody2D

@onready var _wander: WanderComponent = $WanderComponent

func _physics_process(_delta: float) -> void:
	velocity = _wander.velocity_wish
	move_and_slide()
