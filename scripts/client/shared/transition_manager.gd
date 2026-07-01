extends CanvasLayer

const FADE_DURATION: float = 0.4
var _busy: bool = false

@onready var _overlay: ColorRect = $Overlay


func _ready() -> void:
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func transition_to(scene_path: String) -> void:
	if _busy:
		push_warning("[TransitionManager] Transition already in progress — ignoring call to '%s'." % scene_path)
		return

	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	await _fade(1.0)

	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame

	await _fade(0.0)

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _fade(target_alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_overlay, "modulate:a", target_alpha, FADE_DURATION)
	await tween.finished
