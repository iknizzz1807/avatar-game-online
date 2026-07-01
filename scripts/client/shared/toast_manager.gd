extends CanvasLayer

enum Type {
	INFO,
	SUCCESS,
	WARNING,
	ERROR,
}

const MAX_TOASTS: int = 4
const DEFAULT_DURATION: float = 2.5
const TOAST_SCENE: PackedScene = preload("res://prefabs/ui/components/toast.tscn")
@onready var _container: VBoxContainer = $ToastContainer

func show_toast(message: String, type: Type = Type.INFO, duration: float = DEFAULT_DURATION) -> void:
	if _container.get_child_count() >= MAX_TOASTS:
		_container.get_child(0).queue_free()

	var toast: PanelContainer = TOAST_SCENE.instantiate()
	_container.add_child(toast)
	toast.setup(message, type)
	_animate(toast, duration)

func _animate(toast: PanelContainer, duration: float) -> void:
	await get_tree().process_frame;
	if not is_instance_valid(toast):
		return

	toast.modulate.a = 0;
	var tween : Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(toast, "modulate:a", 1.0, 0.18)
	tween.tween_interval(duration)
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast.queue_free)
