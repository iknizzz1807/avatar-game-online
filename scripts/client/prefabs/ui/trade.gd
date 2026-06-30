extends Control

@onready var title_label: Label = $Panel/Margin/VBox/TitleBar/Title
@onready var close_button: Button = $Panel/Margin/VBox/TitleBar/CloseButton
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var inventory_list: ItemList = $Panel/Margin/VBox/Lists/InventoryPanel/InventoryList
@onready var quantity_spin: SpinBox = $Panel/Margin/VBox/Lists/InventoryPanel/QuantityRow/QuantitySpin
@onready var add_button: Button = $Panel/Margin/VBox/Lists/InventoryPanel/ButtonRow/AddButton
@onready var clear_button: Button = $Panel/Margin/VBox/Lists/InventoryPanel/ButtonRow/ClearButton
@onready var my_offer_list: ItemList = $Panel/Margin/VBox/Lists/MyOfferPanel/MyOfferList
@onready var their_offer_list: ItemList = $Panel/Margin/VBox/Lists/TheirOfferPanel/TheirOfferList
@onready var accept_button: Button = $Panel/Margin/VBox/Actions/AcceptButton
@onready var ready_button: Button = $Panel/Margin/VBox/Actions/ReadyButton
@onready var refresh_button: Button = $Panel/Margin/VBox/Actions/RefreshButton
@onready var cancel_button: Button = $Panel/Margin/VBox/Actions/CancelButton
@onready var panel: PanelContainer = $Panel

var trade: Dictionary = {}
var inventory_items: Array = []
var offer_items: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360.0
	panel.offset_top = -205.0
	panel.offset_right = 360.0
	panel.offset_bottom = 205.0
	close_button.pressed.connect(_on_close_pressed)
	inventory_list.item_selected.connect(_on_inventory_item_selected)
	inventory_list.item_activated.connect(_on_inventory_item_activated)
	my_offer_list.item_activated.connect(_on_my_offer_item_activated)
	add_button.pressed.connect(_on_add_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	accept_button.pressed.connect(_on_accept_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	hide()


func set_trade(data: Dictionary) -> void:
	trade = data
	offer_items = []
	for item in trade.get("my_offer", []):
		if item is Dictionary:
			offer_items.append({
				"item_id": item.get("item_id", ""),
				"quantity": int(item.get("quantity", 1)),
			})
	_update_header()
	_update_offer_lists()
	_load_inventory()


func _update_header() -> void:
	var other_name: String = str(trade.get("target_name", ""))
	if trade.get("my_role", "") == "target":
		other_name = str(trade.get("requester_name", ""))
	title_label.text = "Trade voi " + str(other_name)
	var status: String = str(trade.get("status", ""))
	var my_ready: bool = bool(trade.get("requester_ready", false))
	var their_ready: bool = bool(trade.get("target_ready", false))
	if trade.get("my_role", "") == "target":
		my_ready = bool(trade.get("target_ready", false))
		their_ready = bool(trade.get("requester_ready", false))
	var my_ready_text: String = "chua ready"
	var their_ready_text: String = "chua ready"
	if my_ready:
		my_ready_text = "ready"
	if their_ready:
		their_ready_text = "ready"
	if status == "pending":
		if trade.get("my_role", "") == "target":
			status_label.text = "Co loi moi trade. Bam Nhan loi moi de bat dau."
		else:
			status_label.text = "Dang cho doi phuong nhan loi moi trade."
	else:
		status_label.text = "Trang thai: %s | Ban: %s | Doi phuong: %s" % [
			status,
			my_ready_text,
			their_ready_text,
		]
	accept_button.visible = status == "pending" and trade.get("my_role", "") == "target"
	ready_button.visible = status == "active"
	add_button.disabled = status != "active"
	clear_button.disabled = status != "active"
	ready_button.disabled = status != "active"


func _load_inventory() -> void:
	var response: Dictionary = await ApiClient.request_json("/api/inventory")
	if not response.get("ok", false):
		ToastManager.show_toast("Khong tai duoc tui do.", ToastManager.Type.WARNING)
		return
	inventory_items = ApiClient.response_data(response).get("inventory", [])
	_refresh_inventory_list()


func _refresh_inventory_list() -> void:
	inventory_list.clear()
	quantity_spin.max_value = 1.0
	quantity_spin.value = 1.0
	for item in inventory_items:
		if not item is Dictionary:
			continue
		var item_id: String = str(item.get("item_id", ""))
		var total_quantity: int = int(item.get("quantity", 0))
		
		var offered_quantity: int = 0
		for offer in offer_items:
			if offer.get("item_id", "") == item_id:
				offered_quantity = int(offer.get("quantity", 0))
				break
		
		var remaining_quantity: int = total_quantity - offered_quantity
		if remaining_quantity <= 0:
			continue
			
		var label: String = "%s x%d" % [item.get("name", item_id), remaining_quantity]
		var index: int = inventory_list.add_item(label)
		inventory_list.set_item_metadata(index, item)


func _update_offer_lists() -> void:
	my_offer_list.clear()
	for item in trade.get("my_offer", []):
		if item is Dictionary:
			var idx: int = my_offer_list.add_item("%s x%d" % [item.get("name", item.get("item_id", "")), int(item.get("quantity", 0))])
			my_offer_list.set_item_metadata(idx, item)
	their_offer_list.clear()
	for item in trade.get("their_offer", []):
		if item is Dictionary:
			their_offer_list.add_item("%s x%d" % [item.get("name", item.get("item_id", "")), int(item.get("quantity", 0))])


func _on_inventory_item_selected(index: int) -> void:
	var item: Dictionary = inventory_list.get_item_metadata(index)
	var item_id: String = str(item.get("item_id", ""))
	var total_quantity: int = int(item.get("quantity", 0))
	
	var offered_quantity: int = 0
	for offer in offer_items:
		if offer.get("item_id", "") == item_id:
			offered_quantity = int(offer.get("quantity", 0))
			break
			
	var remaining_quantity: int = total_quantity - offered_quantity
	quantity_spin.max_value = remaining_quantity
	quantity_spin.value = min(quantity_spin.value, remaining_quantity)


func _on_inventory_item_activated(index: int) -> void:
	_on_add_pressed()


func _on_my_offer_item_activated(index: int) -> void:
	var item: Dictionary = my_offer_list.get_item_metadata(index)
	var item_id: String = str(item.get("item_id", ""))
	if item_id.is_empty():
		return
	
	for i in range(offer_items.size()):
		if offer_items[i].get("item_id", "") == item_id:
			offer_items.remove_at(i)
			break
			
	TradeManager.set_offer(int(trade.get("id", 0)), offer_items)


func _on_add_pressed() -> void:
	var selected: PackedInt32Array = inventory_list.get_selected_items()
	if selected.is_empty():
		return
	var item: Dictionary = inventory_list.get_item_metadata(selected[0])
	var item_id: String = str(item.get("item_id", ""))
	var total_owned: int = int(item.get("quantity", 0))
	
	var offered_quantity: int = 0
	for offer in offer_items:
		if offer.get("item_id", "") == item_id:
			offered_quantity = int(offer.get("quantity", 0))
			break
			
	var remaining_owned: int = total_owned - offered_quantity
	var quantity: int = clampi(int(quantity_spin.value), 1, remaining_owned)
	if item_id.is_empty() or quantity <= 0:
		return
	var found: bool = false
	for offer in offer_items:
		if offer.get("item_id", "") == item_id:
			offer["quantity"] = clampi(int(offer.get("quantity", 0)) + quantity, 1, total_owned)
			found = true
	if not found:
		offer_items.append({ "item_id": item_id, "quantity": quantity })
	TradeManager.set_offer(int(trade.get("id", 0)), offer_items)


func _on_clear_pressed() -> void:
	offer_items = []
	TradeManager.set_offer(int(trade.get("id", 0)), offer_items)


func _on_accept_pressed() -> void:
	TradeManager.accept_trade(int(trade.get("id", 0)))


func _on_ready_pressed() -> void:
	TradeManager.set_ready(int(trade.get("id", 0)), true)


func _on_refresh_pressed() -> void:
	TradeManager.refresh_trade(int(trade.get("id", 0)))


func _on_cancel_pressed() -> void:
	TradeManager.cancel_trade(int(trade.get("id", 0)))


func _on_close_pressed() -> void:
	hide()
