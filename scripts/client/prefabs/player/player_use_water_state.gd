extends StateNode
class_name PlayerUseWaterState

# ─── Typed reference to the parent Player node ────────────────────────────────
var player: Player

# The facing direction at the moment watering starts (passed via stateDataTransfer)
var _facing: Vector2 = Vector2.DOWN

# Animation completion tracking
var _anim_started: bool = false
var _anim_done: bool    = false

# ─────────────────────────────────────────────────────────────────────────────

func ready_state() -> void:
	player = parent as Player


func begin_state() -> void:
	_anim_started = false
	_anim_done    = false

	# Read the facing direction handed off by NormalState / request_water
	_facing = stateMachine.stateDataTransfer.get("facing", Vector2.DOWN)

	# Freeze movement
	player.velocity = Vector2.ZERO

	# Mirror sprite the same way NormalState does
	player.sprite.flip_h = _facing.x < 0.0

	# Set the useWater blend position and travel to the useWater anim node
	var blendPos := Vector2(absf(_facing.x), _facing.y)
	player.animationTree["parameters/useWater/blend_position"] = blendPos

	var playback: AnimationNodeStateMachinePlayback = player.animationTree["parameters/playback"]
	playback.travel("useWater")

	# Update sync vars so other peers see the animation
	player.sync_anim_state = "useWater"
	player.sync_facing     = blendPos
	player.sync_flip_h     = _facing.x < 0.0


func end_state() -> void:
	pass


func update(_delta: float) -> void:
	pass


func fixed_update(_delta: float) -> void:
	# Keep the player still while watering
	player.velocity = Vector2.ZERO
	player.move_and_slide()

	# Guard: don't finish twice
	if _anim_done:
		return

	var playback: AnimationNodeStateMachinePlayback = player.animationTree["parameters/playback"]

	# Step 1: wait until the AnimationTree has actually entered the useWater node
	if not _anim_started:
		if playback.get_current_node() == &"useWater":
			_anim_started = true
		return

	# Step 2: poll play position — finish when we reach (or pass) the end
	var length: float = playback.get_current_length()
	var pos: float    = playback.get_current_play_position()

	# length == 0 can happen for one frame before the clip is loaded; skip it
	if length < 0.001:
		return

	if pos >= length - 0.05:
		_finish_watering()


# ─── Private ──────────────────────────────────────────────────────────────────

func _finish_watering() -> void:
	_anim_done = true

	# Actually water the pending slot now that the animation has played
	if player._pending_water_slot != null:
		player._pending_water_slot.water()
		player._pending_water_slot = null

	stateMachine.change_state(Player.State.NORMAL)
