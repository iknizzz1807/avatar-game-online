extends Control
class_name ShopUI

@onready var item_container: VBoxContainer = $Panel/MarginContainer/VBox/ScrollContainer/VBoxContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/TitleBar/CloseButton

func _ready() -> void:
	close_button.pressed.connect(hide)
	add_to_group("shop_ui")
	hide()

func open_shop() -> void:
	if ApiClient.has_auth_token():
		_load_server_shop()
	else:
		_populate_shop()
	show()


func _load_server_shop() -> void:
	var response: Dictionary = await ApiClient.request_json("/api/shop/seeds")
	if not response.get("ok", false):
		ToastManager.show_toast("Không tải được cửa hàng.", ToastManager.Type.WARNING)
		return
	var data: Dictionary = ApiClient.response_data(response)
	_populate_server_shop(data.get("seeds", []))


func _populate_server_shop(items: Array) -> void:
	for child in item_container.get_children():
		child.queue_free()

	for server_item in items:
		if not server_item is Dictionary:
			continue
		var item_data: Dictionary = server_item
		var item_id: String = item_data.get("item_id", "")
		var local_item: ItemData = Items.build_item_from_server(item_data)
		_add_shop_row(item_id, local_item, int(item_data.get("buy_price", 0)))

func _populate_shop() -> void:
	for child in item_container.get_children():
		child.queue_free()

	for item: ItemData in Items.CATALOGUE:
		if item.buyPrice > 0:
			_add_shop_row(Items.get_server_id(item.id), item, item.buyPrice)


const SHOP_ROW_PREFAB = preload("res://prefabs/ui/components/shop_row.tscn")

func _add_shop_row(item_id: String, item: ItemData, price: int) -> void:
	var row = SHOP_ROW_PREFAB.instantiate() as ShopRow
	item_container.add_child(row)
	row.setup(item_id, item, price)
	row.buy_requested.connect(_on_buy_requested)

func _on_buy_requested(item_id: String, price: int) -> void:
	if ApiClient.has_auth_token() and not item_id.is_empty():
		var response: Dictionary = await ApiClient.request_json(
			"/api/shop/buy",
			HTTPClient.METHOD_POST,
			{ "item_id": item_id, "quantity": 1 }
		)
		if response.get("ok", false):
			ToastManager.show_toast("Đã mua vật phẩm.")
			for inv in get_tree().get_nodes_in_group("inventory"):
				if inv.has_method("load_inventory"):
					inv.load_inventory()
		else:
			ToastManager.show_toast("Không mua được vật phẩm.", ToastManager.Type.WARNING)
		return

	var inventories = get_tree().get_nodes_in_group("inventory")
	if inventories.is_empty():
		push_error("Inventory not found!")
		return

	var inv = inventories[0]
	if inv.coins >= price:
		var local_item_id: int = int(Items.INT_ID_BY_SERVER_ID.get(item_id, 0))
		if local_item_id != 0 and inv.add_item(local_item_id, 1):
			inv.coins -= price
			inv.coins_changed.emit(inv.coins)
			if ToastManager:
				var bought_item = Items.get_item(local_item_id)
				var msg = "Đã mua " + bought_item.itemName if bought_item else "Đã mua vật phẩm"
				ToastManager.show_toast(msg)
		else:
			if ToastManager:
				ToastManager.show_toast("Túi đồ đã đầy!")
	else:
		if ToastManager:
			ToastManager.show_toast("Không đủ tiền!")
