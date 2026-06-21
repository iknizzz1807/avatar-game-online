extends ContextMenuTarget
class_name FishingSpot

@export var seat_index: int = 0


func _build_actions() -> Array:
	return [
		{ "id": "start", "label": "Cau ca" },
		{ "id": "stop", "label": "Dung cau" },
		{ "id": "buy_rod", "label": "Mua can cau" },
		{ "id": "buy_bait", "label": "Mua moi cau" },
	]


func _on_context_action(action_id: String, target: Object) -> void:
	if target != self:
		return
	if not ApiClient.has_auth_token():
		ToastManager.show_toast("Can dang nhap server de cau ca.", ToastManager.Type.WARNING)
		return

	match action_id:
		"start":
			_start_fishing()
		"stop":
			_stop_fishing()
		"buy_rod":
			_buy_item("rod_bamboo")
		"buy_bait":
			_buy_item("bait_normal")


func _start_fishing() -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/fishing/start",
		HTTPClient.METHOD_POST,
		{ "seat_index": seat_index }
	)
	if response.get("ok", false):
		ToastManager.show_toast("Dang cau ca...")
		_sync_inventory(ApiClient.response_data(response))
	else:
		ToastManager.show_toast("Khong the bat dau cau ca.", ToastManager.Type.WARNING)


func _stop_fishing() -> void:
	var response: Dictionary = await ApiClient.request_json("/api/fishing/stop", HTTPClient.METHOD_POST)
	if response.get("ok", false):
		ToastManager.show_toast("Da dung cau ca.")
		_sync_inventory(ApiClient.response_data(response))
	else:
		ToastManager.show_toast("Ban chua dang cau ca.", ToastManager.Type.WARNING)


func _buy_item(item_id: String) -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/shop/buy",
		HTTPClient.METHOD_POST,
		{ "item_id": item_id, "quantity": 1 }
	)
	if response.get("ok", false):
		ToastManager.show_toast("Da mua vat pham.")
		_sync_inventory(ApiClient.response_data(response))
	else:
		ToastManager.show_toast("Khong mua duoc vat pham.", ToastManager.Type.WARNING)


func _sync_inventory(data: Dictionary) -> void:
	if not data.has("inventory"):
		return
	for inv in get_tree().get_nodes_in_group("inventory"):
		if inv.has_method("set_server_inventory"):
			inv.set_server_inventory(data.get("inventory", []))
