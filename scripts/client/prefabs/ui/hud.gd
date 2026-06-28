extends Control
class_name HUD

# ═════════════════════════════════════════════════════════════════════════════
# SIGNALS
# Emitted when the player clicks the Inventory or Map-change buttons.
# Parent scenes connect these to open the relevant UI panels / trigger map
# transitions — HUD itself does NOT own that logic.
# ═════════════════════════════════════════════════════════════════════════════

signal inventory_requested();
signal map_change_requested();

# ═════════════════════════════════════════════════════════════════════════════
# NODES
# ═════════════════════════════════════════════════════════════════════════════

@onready var xuLabel: Label = $XuContainer/XuLabel;
@onready var inventoryButton: Button = $InventoryButton
@onready var hotbar: Hotbar = $Hotbar;

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("hud")
	inventoryButton.pressed.connect(_on_inventory_button_pressed);
	ApiClient.coins_changed.connect(update_xu)
	if ApiClient.current_coins > 0:
		update_xu(ApiClient.current_coins)

# ═════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# Call this every time the Go Server returns a fresh Xu balance.
# ═════════════════════════════════════════════════════════════════════════════

## Update the Xu counter shown in the HUD.
## [param amount] is the current balance returned by the Go Server.
func update_xu(amount: int) -> void:
	xuLabel.text = str(amount);

## Returns the Hotbar node so callers (e.g. FarmSlot) can read selected_seed_id.
func get_hotbar() -> Hotbar:
	return hotbar;

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE HANDLERS
# ═════════════════════════════════════════════════════════════════════════════

func _on_inventory_button_pressed() -> void:
	inventory_requested.emit();
