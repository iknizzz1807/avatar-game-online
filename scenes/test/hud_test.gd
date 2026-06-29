extends Control
class_name HUDTest

signal inventory_requested()
signal map_requested()

@onready var xu_label: Label = $TopBar/XuContainer/XuLabel
@onready var inventory_button: Button = $BottomBar/InventoryButton
@onready var map_button: Button = $BottomBar/MapButton


func _ready() -> void:
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	map_button.pressed.connect(_on_map_button_pressed)
	if get_node_or_null("/root/ApiClient"):
		ApiClient.coins_changed.connect(update_xu)
		if ApiClient.current_coins > 0:
			update_xu(ApiClient.current_coins)


func update_xu(amount: int) -> void:
	xu_label.text = "%d Xu" % amount


func _on_inventory_button_pressed() -> void:
	inventory_requested.emit()


func _on_map_button_pressed() -> void:
	map_requested.emit()
