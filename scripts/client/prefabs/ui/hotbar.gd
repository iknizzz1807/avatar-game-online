extends Control
class_name Hotbar

# ═════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═════════════════════════════════════════════════════════════════════════════

const SLOT_COUNT: int = 5

# ═════════════════════════════════════════════════════════════════════════════
# STATE
# ═════════════════════════════════════════════════════════════════════════════

## The server_id of the currently selected seed (e.g. "seed_carrot").
## Empty string means nothing is selected — FarmSlot will fall back to auto-pick.
var selected_seed_id: String = ""

## Internal list of { "resource": ItemData, "quantity": int, "server_id": String }
## for the seeds currently shown in the hotbar.
var _seed_slots: Array = []

## The index within _seed_slots that is selected (-1 = none).
var _selected_index: int = -1

# ═════════════════════════════════════════════════════════════════════════════
# NODES
# ═════════════════════════════════════════════════════════════════════════════

@onready var _slot_container: HBoxContainer = $PanelContainer/VBox/SlotContainer

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("hotbar")
	_collect_slot_signals()
	# Populate from inventory once the scene tree is stable.
	call_deferred("_populate_from_inventory")


# ═════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═════════════════════════════════════════════════════════════════════════════

## Fetch fresh inventory from the server and repopulate the hotbar.
## Call this after any action that changes the player's inventory
## (planting, harvesting, buying) so the hotbar stays up-to-date
## even when the inventory panel is closed.
func refresh_from_server() -> void:
	if not ApiClient.has_auth_token():
		return
	var response: Dictionary = await ApiClient.request_json("/api/inventory")
	if not response.get("ok", false):
		return
	var items: Array = ApiClient.response_data(response).get("inventory", [])
	var converted: Array = []
	for server_item in items:
		if server_item is Dictionary:
			converted.append({
				"resource": Items.build_item_from_server(server_item),
				"quantity": int(server_item.get("quantity", 1)),
				"server_id": server_item.get("item_id", ""),
			})
	populate(converted)


## Refresh hotbar contents from [param inventory_data].
## [param inventory_data] is the same Array used by Inventory:
##   each element is { "resource": ItemData, "quantity": int, "server_id": String } or {}.
func populate(inventory_data: Array) -> void:
	# Extract seed entries only, keeping server_id.
	var seeds: Array = []
	for entry in inventory_data:
		if entry is Dictionary and not entry.is_empty() and entry.has("resource"):
			var res: ItemData = entry["resource"] as ItemData
			if res and res.type == Items.TYPE_SEED and entry.get("quantity", 0) > 0:
				seeds.append(entry)

	_seed_slots = seeds

	# Try to preserve the current selection by server_id.
	var keep_id: String = selected_seed_id
	selected_seed_id = ""
	_selected_index = -1

	var slot_nodes: Array[Node] = _slot_container.get_children()
	for i in range(SLOT_COUNT):
		var slot: ItemSlot = slot_nodes[i] as ItemSlot
		if i < seeds.size():
			slot.set_item(seeds[i])
			# Restore selection if the seed is still present.
			if not keep_id.is_empty() and seeds[i].get("server_id", "") == keep_id:
				_selected_index = i
				selected_seed_id = keep_id
				slot.set_selected(true)
			else:
				slot.set_selected(false)
		else:
			slot.set_item({})
			slot.set_selected(false)


# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE
# ═════════════════════════════════════════════════════════════════════════════

func _collect_slot_signals() -> void:
	var children: Array[Node] = _slot_container.get_children()
	for i in range(children.size()):
		var slot: ItemSlot = children[i] as ItemSlot
		if slot == null:
			continue
		slot.slotIndex = i
		slot.slot_clicked.connect(_on_slot_clicked)


func _populate_from_inventory() -> void:
	for inv in get_tree().get_nodes_in_group("inventory"):
		if "inventoryData" in inv:
			populate(inv.inventoryData)
			return


func _on_slot_clicked(idx: int) -> void:
	if idx >= _seed_slots.size():
		# Clicked an empty slot — deselect.
		_clear_selection()
		return

	if _selected_index == idx:
		# Clicking the same slot again deselects it.
		_clear_selection()
		return

	# Deselect previous.
	_clear_selection(false)

	_selected_index = idx
	selected_seed_id = _seed_slots[idx].get("server_id", "")

	var slot: ItemSlot = _slot_container.get_children()[idx] as ItemSlot
	if slot:
		slot.set_selected(true)


func _clear_selection(reset_id: bool = true) -> void:
	if _selected_index >= 0:
		var children: Array[Node] = _slot_container.get_children()
		if _selected_index < children.size():
			var prev: ItemSlot = children[_selected_index] as ItemSlot
			if prev:
				prev.set_selected(false)
	_selected_index = -1
	if reset_id:
		selected_seed_id = ""
