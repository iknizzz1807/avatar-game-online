extends Control

@onready var hud: HUDTest = $HUDTest
@onready var map_select: MapSelectTest = $MapSelectTest
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	hud.map_requested.connect(map_select.open_map_menu)
	hud.inventory_requested.connect(func() -> void: status_label.text = "Tui do se mo o day")
	map_select.map_selected.connect(_on_map_selected)


func _on_map_selected(scene_name: String) -> void:
	status_label.text = "Da chon map: %s" % scene_name
