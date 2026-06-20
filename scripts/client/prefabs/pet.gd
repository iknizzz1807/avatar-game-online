extends CharacterBody2D
class_name Pet

@export var follow_target: Node2D
@export var follow_speed: float = 180.0
@export var follow_distance: float = 30.0

@onready var sprite: AnimatedSprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	if not follow_target:
		sprite.play("idle")
		return
		
	var target_pos = follow_target.global_position
	var distance = global_position.distance_to(target_pos)
	
	if distance > follow_distance:
		var dir = global_position.direction_to(target_pos)
		# Smooth follow via velocity
		velocity = velocity.lerp(dir * follow_speed, 10.0 * delta)
		move_and_slide()
		
		# Animation
		sprite.play("walk")
		# Flip sprite based on direction
		if abs(velocity.x) > 5.0:
			sprite.flip_h = velocity.x < 0.0
	else:
		# Decelerate when close
		velocity = velocity.lerp(Vector2.ZERO, 15.0 * delta)
		move_and_slide()
		
		if velocity.length() < 10.0:
			sprite.play("idle")
		else:
			sprite.play("walk")
