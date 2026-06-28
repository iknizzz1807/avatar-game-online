extends VBoxContainer
class_name ContextMenuItem

signal action_pressed(action_id: String)

@onready var action_btn: Button = $ActionBtn
@onready var hint_label: Label = $HintLabel

var _action_id: String

func _ready() -> void:
	action_btn.pressed.connect(func() -> void: action_pressed.emit(_action_id))
	action_btn.mouse_entered.connect(_on_mouse_entered)
	action_btn.mouse_exited.connect(_on_mouse_exited)

func setup(action_id: String, label: String, enabled: bool, tooltip: String) -> void:
	_action_id = action_id
	action_btn.text = label
	action_btn.disabled = not enabled
	
	if enabled and tooltip != "":
		action_btn.tooltip_text = tooltip
	else:
		action_btn.tooltip_text = ""
		
	if not enabled and tooltip != "":
		hint_label.text = "  ⚠ " + tooltip
	else:
		hint_label.text = ""

func _on_mouse_entered() -> void:
	if not action_btn.disabled:
		return
	if hint_label.text != "":
		hint_label.show()

func _on_mouse_exited() -> void:
	hint_label.hide()
