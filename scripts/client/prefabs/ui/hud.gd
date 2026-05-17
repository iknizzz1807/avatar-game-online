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

@onready var xuLabel: Label = $TopBar/XuContainer/XuLabel;
@onready var inventoryButton: Button = $BottomBar/InventoryButton;
@onready var mapButton: Button = $BottomBar/MapButton;

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	inventoryButton.pressed.connect(_on_inventory_button_pressed);
	mapButton.pressed.connect(_on_map_button_pressed);

# ═════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# Call this every time the Go Server returns a fresh Xu balance.
# ═════════════════════════════════════════════════════════════════════════════

## Update the Xu counter shown in the HUD.
## [param amount] is the current balance returned by the Go Server.
func update_xu(amount: int) -> void:
	xuLabel.text = "%d Xu" % amount;

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE HANDLERS
# ═════════════════════════════════════════════════════════════════════════════

func _on_inventory_button_pressed() -> void:
	inventory_requested.emit();

func _on_map_button_pressed() -> void:
	map_change_requested.emit();
