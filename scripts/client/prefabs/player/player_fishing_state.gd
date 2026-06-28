extends StateNode
class_name PlayerFishingState

# ═════════════════════════════════════════════════════════════════════════════
# PLAYER FISHING STATE
#
# Entered when the player starts fishing (player.start_fishing() is called).
# Responsible for:
#   1. Locking the player in place and playing the idle fishing pose.
#   2. Showing and driving the FishingMinigame UI overlay.
#   3. Forwarding success / fail results to the PondInputHandler so it can
#      call the server API.
# ═════════════════════════════════════════════════════════════════════════════

var player: Player
var _facing: Vector2 = Vector2.DOWN

## The live FishingMinigame instance (found in the player's CanvasLayer).
var _minigame: FishingMinigame = null


# ─── StateNode overrides ──────────────────────────────────────────────────────

func ready_state() -> void:
	player = parent as Player


func begin_state() -> void:
	_facing = stateMachine.stateDataTransfer.get("facing", Vector2.DOWN)

	# Lock movement
	player.velocity = Vector2.ZERO
	player.sprite.flip_h = _facing.x < 0.0

	# Set idle animation toward the water
	var blend_pos := Vector2(absf(_facing.x), _facing.y)
	var playback: AnimationNodeStateMachinePlayback = player.animationTree["parameters/playback"]
	playback.travel("Idle")
	player.animationTree["parameters/Idle/blend_position"] = blend_pos
	player.sync_anim_state = "Idle"
	player.sync_facing     = blend_pos
	player.sync_flip_h     = _facing.x < 0.0

	# Instantiate and show the minigame UI
	_spawn_minigame()


func end_state() -> void:
	player.velocity = Vector2.ZERO
	_destroy_minigame()


func update(_delta: float) -> void:
	pass


func fixed_update(_delta: float) -> void:
	# Player is frozen while fishing
	player.velocity = Vector2.ZERO
	player.move_and_slide()
	player.sync_position = player.global_position


# ─── Minigame lifecycle ───────────────────────────────────────────────────────

func _spawn_minigame() -> void:
	# Use the pre-existing FishingMinigame node added to the player's CanvasLayer in player.tscn
	var canvas: CanvasLayer = player.get_node_or_null("CanvasLayer")
	if canvas == null:
		push_error("[PlayerFishingState] Player has no CanvasLayer — cannot show minigame UI.")
		return

	_minigame = canvas.get_node_or_null("FishingMinigame") as FishingMinigame
	if _minigame == null:
		push_error("[PlayerFishingState] FishingMinigame node not found in CanvasLayer.")
		return

	_minigame.show()
	_minigame.fishing_success.connect(_on_fishing_success, CONNECT_ONE_SHOT)
	_minigame.fishing_failed.connect(_on_fishing_failed, CONNECT_ONE_SHOT)
	_minigame.start()


func _destroy_minigame() -> void:
	if _minigame == null:
		return
	# Disconnect any remaining signals before hiding
	if _minigame.fishing_success.is_connected(_on_fishing_success):
		_minigame.fishing_success.disconnect(_on_fishing_success)
	if _minigame.fishing_failed.is_connected(_on_fishing_failed):
		_minigame.fishing_failed.disconnect(_on_fishing_failed)
	_minigame.cancel()
	_minigame.hide()
	_minigame = null


# ─── Minigame callbacks ───────────────────────────────────────────────────────

func _on_fishing_success() -> void:
	# Forward to the pond handler that started this session
	var handler := _get_pond_handler()
	if handler and handler.has_method("on_minigame_success"):
		handler.on_minigame_success()
	else:
		ToastManager.show_toast(tr("CÂU_ĐƯỢC_CÁ"), ToastManager.Type.SUCCESS)

	# A brief delay so the result panel is readable, then return to normal
	await player.get_tree().create_timer(2.0).timeout
	if player.stateMachine.currentState == Player.State.FISHING:
		player.stop_fishing()


func _on_fishing_failed(reason: String) -> void:
	var handler := _get_pond_handler()
	if handler and handler.has_method("on_minigame_failed"):
		handler.on_minigame_failed(reason)

	await player.get_tree().create_timer(2.0).timeout
	if player.stateMachine.currentState == Player.State.FISHING:
		player.stop_fishing()


# ─── Helpers ─────────────────────────────────────────────────────────────────

## Find the PondInputHandler TileMapLayer in the current scene.
func _get_pond_handler() -> Node:
	return player.get_tree().get_first_node_in_group("pond_input_handler")
