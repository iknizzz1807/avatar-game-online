extends Control
class_name Inventory

# ═════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═════════════════════════════════════════════════════════════════════════════

signal sell_requested(itemId: int, quantity: int);
signal close_requested();

# ═════════════════════════════════════════════════════════════════════════════
# INSPECTOR — Example data (editable in the Godot editor)
# Assign ItemData resources and quantities directly in the Inspector.
# These are loaded on _ready() and used until the Go Server sends real data.
# ═════════════════════════════════════════════════════════════════════════════

@export_group("Example Data")
@export var EXAMPLE_SLOTS: Array[InventorySlot] = [];

# ═════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═════════════════════════════════════════════════════════════════════════════

const SLOT_COUNT: int = 20;

# ═════════════════════════════════════════════════════════════════════════════
# NODES
# ═════════════════════════════════════════════════════════════════════════════

@onready var gridContainer: GridContainer = $Panel/MC/VBox/GridContainer;
@onready var closeButton: Button = $Panel/MC/VBox/TitleBar/CloseButton;
@onready var tooltipSection: VBoxContainer = $Panel/MC/VBox/TooltipSection;
@onready var tooltipName: Label = $Panel/MC/VBox/TooltipSection/TooltipName;
@onready var tooltipSellButton: Button = $Panel/MC/VBox/TooltipSection/SellButton;

# ═════════════════════════════════════════════════════════════════════════════
# STATE
# ═════════════════════════════════════════════════════════════════════════════

## 20-element array. Each element is one of:
##   { "resource": ItemData, "quantity": int }  — filled slot
##   {}                                          — empty slot
var inventoryData: Array = [];
var slots: Array[ItemSlot] = [];
var selectedSlot: int = -1;

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	closeButton.pressed.connect(_on_close_pressed);
	tooltipSellButton.pressed.connect(_on_sell_pressed);
	_collect_slots();
	_load_example_slots();

# ═════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═════════════════════════════════════════════════════════════════════════════

## Load fresh inventory from Go Server.
## [param data] Array of { "resource": ItemData, "quantity": int } or {}.
## Automatically padded / trimmed to exactly SLOT_COUNT.
func set_inventory(data: Array) -> void:
	inventoryData = data.duplicate();
	while inventoryData.size() < SLOT_COUNT:
		inventoryData.append({});
	inventoryData.resize(SLOT_COUNT);
	_refresh_slots();

func open_inventory() -> void:
	visible = true;

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE — build & refresh
# ═════════════════════════════════════════════════════════════════════════════

## Gather the 20 ItemSlot instances already placed in the scene by the editor.
func _collect_slots() -> void:
	for child: Node in gridContainer.get_children():
		var slot: ItemSlot = child as ItemSlot;
		if slot == null:
			continue;
		slot.slotIndex = slots.size();
		slot.slot_clicked.connect(_on_slot_clicked);
		slot.swap_requested.connect(_on_slot_swap);
		slots.append(slot);

## Convert EXAMPLE_SLOTS export array into inventoryData and display it.
func _load_example_slots() -> void:
	var data: Array = [];
	for s: InventorySlot in EXAMPLE_SLOTS:
		if s != null and s.item != null:
			data.append({"resource": s.item, "quantity": s.quantity});
		else:
			data.append({});
	set_inventory(data);

func _refresh_slots() -> void:
	for i: int in range(slots.size()):
		slots[i].set_item(inventoryData[i] if i < inventoryData.size() else {});
	_hide_tooltip();

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE — event handlers
# ═════════════════════════════════════════════════════════════════════════════

func _on_slot_clicked(idx: int) -> void:
	if selectedSlot >= 0:
		slots[selectedSlot].set_selected(false);

	if selectedSlot == idx or inventoryData[idx].is_empty():
		selectedSlot = -1;
		_hide_tooltip();
		return ;

	selectedSlot = idx;
	slots[selectedSlot].set_selected(true);

	var res: ItemData = inventoryData[idx]["resource"] as ItemData;
	tooltipName.text = res.itemName;
	tooltipSellButton.visible = res.sellable;
	tooltipSection.visible = true;

func _on_slot_swap(fromIndex: int, toIndex: int) -> void:
	if fromIndex == toIndex:
		return ;
	var fromData: Dictionary = inventoryData[fromIndex];
	var toData: Dictionary = inventoryData[toIndex];
	inventoryData[fromIndex] = toData;
	inventoryData[toIndex] = fromData;
	slots[fromIndex].set_item(toData);
	slots[toIndex].set_item(fromData);
	_hide_tooltip();

func _on_sell_pressed() -> void:
	if selectedSlot < 0:
		return ;
	var res: ItemData = inventoryData[selectedSlot]["resource"] as ItemData;
	var qty: int = inventoryData[selectedSlot].get("quantity", 0);
	sell_requested.emit(res.id, qty);
	_hide_tooltip();

func _on_close_pressed() -> void:
	_hide_tooltip();
	close_requested.emit();
	hide();

func _hide_tooltip() -> void:
	if selectedSlot >= 0:
		slots[selectedSlot].set_selected(false);
	tooltipSection.visible = false;
	selectedSlot = -1;
