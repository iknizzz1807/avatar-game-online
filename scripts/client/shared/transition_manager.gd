extends CanvasLayer

# ═════════════════════════════════════════════════════════════════════════════
# TRANSITION MANAGER — Client Autoload Singleton
#
# Add to Project → Project Settings → Autoload (scene) as "TransitionManager".
#
# Usage from anywhere:
#   TransitionManager.transition_to("res://scenes/park.tscn")
#
# The call is safe to make from physics callbacks because the tween defers
# the actual scene change until after the fade-out animation completes.
# ═════════════════════════════════════════════════════════════════════════════

## Duration of each half (fade-out and fade-in) in seconds.
const FADE_DURATION: float = 0.4

## Prevent re-entrant or double transitions.
var _busy: bool = false

@onready var _overlay: ColorRect = $Overlay


func _ready() -> void:
	# Start fully transparent so it is invisible at launch.
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ─── Public API ───────────────────────────────────────────────────────────────

## Fade to black, change to `scene_path`, then fade back in.
## Safe to call from anywhere including physics callbacks.
func transition_to(scene_path: String) -> void:
	if _busy:
		push_warning("[TransitionManager] Transition already in progress — ignoring call to '%s'." % scene_path)
		return

	_busy = true
	# Block input during the transition so the player cannot interact.
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	await _fade(1.0)  # Fade out → black

	get_tree().change_scene_to_file(scene_path)

	# Wait two frames: one for the new scene to be set as current,
	# one for its _ready() calls to finish.
	await get_tree().process_frame
	await get_tree().process_frame

	await _fade(0.0)  # Fade in → transparent

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


# ─── Internals ────────────────────────────────────────────────────────────────

func _fade(target_alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_overlay, "modulate:a", target_alpha, FADE_DURATION)
	await tween.finished
