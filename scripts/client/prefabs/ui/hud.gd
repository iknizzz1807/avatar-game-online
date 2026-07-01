extends Control
class_name HUD

signal inventory_requested();
signal map_change_requested();

@onready var xuLabel: Label = $XuContainer/XuLabel;
@onready var inventoryButton: Button = $InventoryButton
@onready var hotbar: Hotbar = $Hotbar;

func _ready() -> void:
	add_to_group("hud")
	inventoryButton.pressed.connect(_on_inventory_button_pressed);
	ApiClient.coins_changed.connect(update_xu)
	if ApiClient.current_coins > 0:
		update_xu(ApiClient.current_coins)

func update_xu(amount: int) -> void:
	xuLabel.text = str(amount);

func get_hotbar() -> Hotbar:
	return hotbar;

func _on_inventory_button_pressed() -> void:
	inventory_requested.emit();
