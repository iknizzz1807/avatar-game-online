extends Area2D
class_name FishingSpot

@export var seat_index: int = 0

var _claiming: bool = false


func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shapeIdx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var menus := get_tree().get_nodes_in_group("context_menu")
	if menus.is_empty():
		return
	var menu = menus[0]
	if menu.action_selected.is_connected(_on_context_action):
		menu.action_selected.disconnect(_on_context_action)
	menu.action_selected.connect(_on_context_action, CONNECT_ONE_SHOT)
	menu.show_menu(_build_actions(), self, event.global_position)


func _build_actions() -> Array:
	return [
		{ "id": "start", "label": tr("CÂU_CÁ") },
		{ "id": "stop", "label": tr("DỪNG_CÂU") },
		{ "id": "buy_rod", "label": tr("MUA_CẦN_CÂU") },
		{ "id": "buy_bait", "label": tr("MUA_MỒI_CÂU") },
	]


func _on_context_action(action_id: String, target: Object) -> void:
	if target != self:
		return
	if not ApiClient.has_auth_token():
		ToastManager.show_toast(tr("MUST_LOG_IN_TO_THE_SERVER_TO_F"), ToastManager.Type.WARNING)
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
		var data := ApiClient.response_data(response)
		var finish_at := int(data.get("finish_at", data.get("fishing_status", {}).get("finish_at", 0)))
		ToastManager.show_toast(tr("FISHING"))
		_sync_inventory(data)
		_set_local_player_fishing(true)
		_wait_then_claim(finish_at)
	else:
		ToastManager.show_toast(tr("CANNOT_START_FISHING"), ToastManager.Type.WARNING)


func _stop_fishing() -> void:
	var response: Dictionary = await ApiClient.request_json("/api/fishing/stop", HTTPClient.METHOD_POST)
	if response.get("ok", false):
		ToastManager.show_toast(tr("STOPPED_FISHING"))
		_sync_inventory(ApiClient.response_data(response))
		_set_local_player_fishing(false)
	else:
		ToastManager.show_toast(tr("YOU_ARE_NOT_CURRENTLY_FISHING"), ToastManager.Type.WARNING)


func _buy_item(item_id: String) -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/shop/buy",
		HTTPClient.METHOD_POST,
		{ "item_id": item_id, "quantity": 1 }
	)
	if response.get("ok", false):
		ToastManager.show_toast(tr("ITEM_PURCHASED"))
		_sync_inventory(ApiClient.response_data(response))
	else:
		ToastManager.show_toast(tr("FAILED_TO_PURCHASE_ITEM"), ToastManager.Type.WARNING)


func _sync_inventory(data: Dictionary) -> void:
	if not data.has("inventory"):
		return
	for inv in get_tree().get_nodes_in_group("inventory"):
		if inv.has_method("set_server_inventory"):
			inv.set_server_inventory(data.get("inventory", []))


func _wait_then_claim(finish_at: int) -> void:
	if finish_at <= 0 or _claiming:
		return
	_claiming = true
	var wait_seconds: int = maxi(0, finish_at - int(Time.get_unix_time_from_system()))
	if wait_seconds > 0:
		ToastManager.show_toast("Ca se can cau sau %d giay." % wait_seconds)
		await get_tree().create_timer(wait_seconds).timeout
	_claiming = false
	_claim_fishing()


func _claim_fishing() -> void:
	var response: Dictionary = await ApiClient.request_json("/api/fishing/claim", HTTPClient.METHOD_POST)
	_set_local_player_fishing(false)
	if not response.get("ok", false):
		ToastManager.show_toast("Chua co ca can cau.", ToastManager.Type.WARNING)
		return
	var data: Dictionary = ApiClient.response_data(response)
	_sync_inventory(data)
	var result: Dictionary = data.get("result", {})
	var item_id: String = result.get("item_id", "")
	if item_id.is_empty():
		ToastManager.show_toast(tr("CA_CHAY_MAT_ROI"), ToastManager.Type.WARNING)
	else:
		var item: ItemData = Items.get_item_by_server_id(item_id)
		var item_name: String = tr(item.itemName) if item else item_id
		ToastManager.show_toast(tr("CAUGHT_FORMAT") % item_name)


func _set_local_player_fishing(enabled: bool) -> void:
	for player in get_tree().get_nodes_in_group("local_player"):
		if enabled and player.has_method("start_fishing"):
			player.start_fishing(Vector2.UP)
		elif not enabled and player.has_method("stop_fishing"):
			player.stop_fishing()
		return
