## Toast
## ─────────────────────────────────────────────────────────────────────────────
## Individual toast notification node.
## Instantiated by ToastManager; visual defaults are set in toast.tscn so
## they can be tweaked in the editor without touching code.
##
## Call setup() right after instantiating to apply the message and type.
## ─────────────────────────────────────────────────────────────────────────────
extends PanelContainer
class_name Toast

# ── Per-type style overrides applied at runtime ───────────────────────────────
# These only override bg/border colour and the icon prefix.
# Font size, padding, corner radius, shadow — all live in the .tscn StyleBox.

var TYPE_STYLES: Dictionary = {
	0: { "bg": Color(0.15, 0.15, 0.20, 0.92), "border": Color(0.50, 0.50, 0.60, 0.80), "icon": "ℹ️" },
	1: { "bg": Color(0.10, 0.28, 0.15, 0.92), "border": Color(0.30, 0.75, 0.45, 0.90), "icon": "✅" },
	2: { "bg": Color(0.30, 0.22, 0.05, 0.92), "border": Color(0.90, 0.65, 0.15, 0.90), "icon": "⚠️" },
	3: { "bg": Color(0.30, 0.08, 0.08, 0.92), "border": Color(0.90, 0.30, 0.30, 0.90), "icon": "❌" },
}

@onready var _label: Label = $Label

## Apply message text and type-specific colour/icon.
## Called by ToastManager immediately after instantiation.
func setup(message: String, type: int) -> void:
	var style: Dictionary = TYPE_STYLES[type]

	# Colour the panel — duplicate the base StyleBox so each toast is independent
	var box := (get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.bg_color     = style["bg"]
	box.border_color = style["border"]
	add_theme_stylebox_override("panel", box)

	_label.text = "%s  %s" % [style["icon"], message]
