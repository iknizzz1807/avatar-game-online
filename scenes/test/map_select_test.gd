extends Control
class_name MapSelectTest

signal map_selected(scene_name: String)

@onready var close_button: Button = $Panel/Margin/VBox/TitleRow/CloseButton
@onready var farm_button: Button = $Panel/Margin/VBox/Grid/FarmButton
@onready var park_button: Button = $Panel/Margin/VBox/Grid/ParkButton
@onready var fishing_button: Button = $Panel/Margin/VBox/Grid/FishingButton
@onready var town_button: Button = $Panel/Margin/VBox/Grid/TownButton


func _ready() -> void:
	hide()
	close_button.pressed.connect(hide)
	farm_button.pressed.connect(func() -> void: _select_map("game"))
	park_button.pressed.connect(func() -> void: _select_map("park"))
	fishing_button.pressed.connect(func() -> void: _select_map("fish_pond"))
	town_button.pressed.connect(func() -> void: _select_map("town"))


func open_map_menu() -> void:
	show()


func _select_map(scene_name: String) -> void:
	hide()
	map_selected.emit(scene_name)
