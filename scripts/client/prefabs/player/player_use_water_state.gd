extends StateNode
class_name PlayerUseWaterState

var player: Player
var _facing: Vector2 = Vector2.DOWN
var _anim_started: bool = false
var _anim_done: bool    = false

func ready_state() -> void:
	player = parent as Player


func begin_state() -> void:
	_anim_started = false
	_anim_done    = false

	_facing = stateMachine.stateDataTransfer.get("facing", Vector2.DOWN)

	player.velocity = Vector2.ZERO
	player.sprite.flip_h = _facing.x < 0.0

	var blendPos := Vector2(absf(_facing.x), _facing.y)
	player.animationTree["parameters/useWater/blend_position"] = blendPos

	var playback: AnimationNodeStateMachinePlayback = player.animationTree["parameters/playback"]
	playback.travel("useWater")
	player.sync_anim_state = "useWater"
	player.sync_facing     = blendPos
	player.sync_flip_h     = _facing.x < 0.0


func end_state() -> void:
	pass


func update(_delta: float) -> void:
	pass


func fixed_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	player.move_and_slide()

	if _anim_done:
		return

	var playback: AnimationNodeStateMachinePlayback = player.animationTree["parameters/playback"]

	if not _anim_started:
		if playback.get_current_node() == &"useWater":
			_anim_started = true
		return
	var length: float = playback.get_current_length()
	var pos: float    = playback.get_current_play_position()
	if length < 0.001:
		return

	if pos >= length - 0.05:
		_finish_watering()

func _finish_watering() -> void:
	_anim_done = true

	if player._pending_water_slot != null:
		player._pending_water_slot.water()
		player._pending_water_slot = null

	stateMachine.change_state(Player.State.NORMAL)
