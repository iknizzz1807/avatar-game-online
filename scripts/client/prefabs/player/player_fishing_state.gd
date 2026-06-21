extends StateNode
class_name PlayerFishingState

var player: Player
var _facing: Vector2 = Vector2.DOWN


func ready_state() -> void:
	player = parent as Player


func begin_state() -> void:
	_facing = stateMachine.stateDataTransfer.get("facing", Vector2.DOWN)
	player.velocity = Vector2.ZERO
	player.sprite.flip_h = _facing.x < 0.0

	var blend_pos := Vector2(absf(_facing.x), _facing.y)
	var playback: AnimationNodeStateMachinePlayback = player.animationTree["parameters/playback"]
	playback.travel("Idle")
	player.animationTree["parameters/Idle/blend_position"] = blend_pos
	player.sync_anim_state = "Idle"
	player.sync_facing = blend_pos
	player.sync_flip_h = _facing.x < 0.0


func end_state() -> void:
	player.velocity = Vector2.ZERO


func update(_delta: float) -> void:
	pass


func fixed_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	player.move_and_slide()
	player.sync_position = player.global_position
