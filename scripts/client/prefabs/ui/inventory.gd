extends Control
class_name Inventory

# ═════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═════════════════════════════════════════════════════════════════════════════

signal sell_requested(itemId: String, quantity: int);
signal close_requested();
signal coins_changed(amount: int);
## Fired whenever inventoryData changes so the Hotbar (and other listeners) can refresh.
signal inventory_updated(data: Array);

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

# TODO(Backend): Sync coins from the Go server instead of local simulation
var coins: int = 1000;

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("inventory");
	closeButton.pressed.connect(_on_close_pressed);
	tooltipSellButton.pressed.connect(_on_sell_pressed);
	_collect_slots();
	# Connect hotbar nodes so they refresh whenever the inventory changes.
	inventory_updated.connect(_on_inventory_updated_hotbar);
	if ApiClient.has_auth_token():
		load_inventory()
	else:
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
	if ApiClient.has_auth_token():
		load_inventory()
	visible = true;


func load_inventory() -> void:
	var response: Dictionary = await ApiClient.request_json("/api/inventory")
	if not response.get("ok", false):
		ToastManager.show_toast(tr("FAILED_TO_LOAD_INVENTORY"), ToastManager.Type.WARNING)
		return
	var data: Dictionary = ApiClient.response_data(response)
	set_server_inventory(data.get("inventory", []))


func set_server_inventory(items: Array) -> void:
	var data: Array = []
	for server_item in items:
		if not server_item is Dictionary:
			continue
		var item_data: Dictionary = server_item
		data.append({
			"resource": Items.build_item_from_server(item_data),
			"quantity": int(item_data.get("quantity", 1)),
			"server_id": item_data.get("item_id", ""),
		})
	set_inventory(data)

## Attempts to add an item to the inventory. Returns true if successful.
func add_item(item_id: int, quantity: int) -> bool:
	var item_res = Items.get_item(item_id);
	if not item_res:
		return false;

	# Try to find an existing stack if stackable
	if item_res.stackable:
		for i in range(inventoryData.size()):
			if not inventoryData[i].is_empty() and inventoryData[i]["resource"].id == item_id:
				# TODO(Backend): Sync item addition with Go server
				inventoryData[i]["quantity"] += quantity;
				_refresh_slots();
				return true;
				
	# Find an empty slot
	for i in range(inventoryData.size()):
		if inventoryData[i].is_empty():
			# TODO(Backend): Sync item addition with Go server
			inventoryData[i] = { "resource": item_res, "quantity": quantity };
			_refresh_slots();
			return true;
			
	return false;

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
	inventory_updated.emit(inventoryData);

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
	tooltipName.text = tr(res.itemName);
	tooltipSellButton.visible = res.sellable or inventoryData[idx].get("server_id", "").begins_with("harvest_") or inventoryData[idx].get("server_id", "").begins_with("fish_");
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
	var server_id: String = inventoryData[selectedSlot].get("server_id", Items.get_server_id(res.id));
	if ApiClient.has_auth_token() and not server_id.is_empty():
		var response: Dictionary = await ApiClient.request_json(
			"/api/inventory/sell",
			HTTPClient.METHOD_POST,
			{ "item_id": server_id, "quantity": qty }
		)
		if response.get("ok", false):
			ToastManager.show_toast(tr("ITEM_SOLD"))
			load_inventory()
		else:
			ToastManager.show_toast(tr("FAILED_TO_SELL_ITEM"), ToastManager.Type.WARNING)
	else:
		sell_requested.emit(server_id, qty);
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

func _on_inventory_updated_hotbar(data: Array) -> void:
	for hotbar in get_tree().get_nodes_in_group("hotbar"):
		if hotbar.has_method("populate"):
			hotbar.populate(data)
