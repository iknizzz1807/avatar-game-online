extends PanelContainer
class_name Toast

var TYPE_STYLES: Dictionary = {
	0: { "bg": Color(0.15, 0.15, 0.20, 0.92), "border": Color(0.50, 0.50, 0.60, 0.80), "icon": "ℹ️" },
	1: { "bg": Color(0.10, 0.28, 0.15, 0.92), "border": Color(0.30, 0.75, 0.45, 0.90), "icon": "✅" },
	2: { "bg": Color(0.30, 0.22, 0.05, 0.92), "border": Color(0.90, 0.65, 0.15, 0.90), "icon": "⚠️" },
	3: { "bg": Color(0.30, 0.08, 0.08, 0.92), "border": Color(0.90, 0.30, 0.30, 0.90), "icon": "❌" },
}

@onready var _label: Label = $Label

func setup(message: String, type: int) -> void:
	var style: Dictionary = TYPE_STYLES[type]
	_label.text = "%s  %s" % [style["icon"], message]
