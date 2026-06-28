## ToastManager — global singleton for in-game toast notifications.
## ─────────────────────────────────────────────────────────────────────────────
## Registered as an Autoload (scene) named "ToastManager" in Project Settings.
## Open toast_manager.tscn to move/resize the ToastContainer and change where
## toasts appear on screen.
##
## Usage from anywhere:
##   ToastManager.show_toast("Move closer to plant a seed.")
##   ToastManager.show_toast("Item collected!", ToastManager.Type.SUCCESS)
##   ToastManager.show_toast("Cannot do that!", ToastManager.Type.ERROR)
## ─────────────────────────────────────────────────────────────────────────────
extends CanvasLayer

enum Type {
	INFO,
	SUCCESS,
	WARNING,
	ERROR,
}

## How many toasts can stack vertically at once.
const MAX_TOASTS: int = 4

## Default display duration in seconds.
const DEFAULT_DURATION: float = 2.5

## The toast scene — edit toast.tscn to change padding, font, corners, shadow.
const TOAST_SCENE: PackedScene = preload("res://prefabs/ui/components/toast.tscn")

## Container node positioned in toast_manager.tscn — move it in the editor to
## control where toasts appear on screen.
@onready var _container: VBoxContainer = $ToastContainer

# ── Public API ────────────────────────────────────────────────────────────────

## Show a toast notification.
## [param message]  The text to display.
## [param type]     One of ToastManager.Type (INFO, SUCCESS, WARNING, ERROR).
## [param duration] Seconds before the toast fades out (default 2.5 s).
func show_toast(message: String, type: Type = Type.INFO, duration: float = DEFAULT_DURATION) -> void:
	# Drop the oldest toast if we're at the cap
	if _container.get_child_count() >= MAX_TOASTS:
		_container.get_child(0).queue_free()

	var toast: PanelContainer = TOAST_SCENE.instantiate()
	_container.add_child(toast)
	toast.setup(message, type)
	_animate(toast, duration)

# ── Private ───────────────────────────────────────────────────────────────────

func _animate(toast: PanelContainer, duration: float) -> void:
	# Wait one frame for the container to position the toast
	await get_tree().process_frame;
	if not is_instance_valid(toast):
		return

	toast.modulate.a = 0;
	#var target_y: float = get_viewport().get_visible_rect().size.y;
	var tween : Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)

	# Slide in + fade in from slightly above the target layout position
	tween.tween_property(toast, "modulate:a", 1.0, 0.18)
	#tween.parallel().tween_property(toast, "position:y", target_y, 0.18)

	# Hold
	tween.tween_interval(duration)

	# Fade out
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast.queue_free)
