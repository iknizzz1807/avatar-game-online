extends Node

signal trade_updated(trade: Dictionary)
signal trade_closed()

const TRADE_SCREEN := preload("res://prefabs/ui/screens/trade.tscn")
const POLL_SECONDS: float = 2.0

var active_trade: Dictionary = {}
var _trade_ui: Control = null
var _trade_layer: CanvasLayer = null
var _poll_timer: Timer = null
var _prompted_trade_id: int = -1
var _pending_prompt_trade_id: int = -1
var _pending_prompt_dialog: ConfirmationDialog = null


func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_SECONDS
	_poll_timer.timeout.connect(_poll_active_trade)
	add_child(_poll_timer)
	_poll_timer.start()


func request_trade(target_user_id: int, target_name: String = "") -> void:
	if not ApiClient.has_auth_token():
		ToastManager.show_toast("Dang nhap de trao doi.", ToastManager.Type.WARNING)
		return
	var response: Dictionary = await ApiClient.request_json(
		"/api/trade/request",
		HTTPClient.METHOD_POST,
		{ "target_user_id": target_user_id }
	)
	if not response.get("ok", false):
		ToastManager.show_toast("Khong gui duoc loi moi trade.", ToastManager.Type.WARNING)
		return
	var trade: Dictionary = _extract_trade(response)
	active_trade = trade
	_show_trade(trade)
	var name: String = target_name
	if name.is_empty():
		name = str(trade.get("target_name", "player"))
	ToastManager.show_toast("Da gui loi moi trade toi " + name + ".")


func accept_trade(trade_id: int) -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/trade/%d/accept" % trade_id,
		HTTPClient.METHOD_POST
	)
	_handle_trade_response(response, "Da chap nhan trade.", "Khong chap nhan duoc trade.")


func cancel_trade(trade_id: int) -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/trade/%d/cancel" % trade_id,
		HTTPClient.METHOD_POST
	)
	if response.get("ok", false):
		active_trade = {}
		_hide_trade()
		ToastManager.show_toast("Da huy trade.")
		trade_closed.emit()
	else:
		ToastManager.show_toast("Khong huy duoc trade.", ToastManager.Type.WARNING)


func set_offer(trade_id: int, items: Array) -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/trade/%d/offer" % trade_id,
		HTTPClient.METHOD_POST,
		{ "items": items }
	)
	_handle_trade_response(response, "Da cap nhat vat pham.", "Khong cap nhat duoc vat pham.")


func set_ready(trade_id: int, ready: bool) -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/trade/%d/ready" % trade_id,
		HTTPClient.METHOD_POST,
		{ "ready": ready }
	)
	_handle_trade_response(response, "Da san sang.", "Trade that bai.")


func refresh_trade(trade_id: int) -> void:
	var response: Dictionary = await ApiClient.request_json("/api/trade/%d" % trade_id)
	_handle_trade_response(response, "", "Khong tai duoc trade.")


func _poll_active_trade() -> void:
	if not ApiClient.has_auth_token():
		return
	var response: Dictionary = await ApiClient.request_json("/api/trade/active")
	if not response.get("ok", false):
		return
	var trade: Dictionary = _extract_trade(response)
	if trade.is_empty():
		return
	active_trade = trade
	trade_updated.emit(trade)
	if _trade_ui != null and _trade_ui.visible:
		_trade_ui.set_trade(trade)
	if trade.get("status", "") == "pending" and trade.get("my_role", "") == "target":
		_prompt_incoming_trade(trade)


func _prompt_incoming_trade(trade: Dictionary) -> void:
	var trade_id: int = int(trade.get("id", -1))
	if trade_id <= 0 or _prompted_trade_id == trade_id:
		return
	_prompted_trade_id = trade_id
	_pending_prompt_trade_id = trade_id
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	_pending_prompt_dialog = dialog
	dialog.title = "Loi moi trade"
	dialog.dialog_text = "%s muon trao doi vat pham voi ban." % trade.get("requester_name", "Nguoi choi")
	dialog.confirmed.connect(_on_trade_prompt_confirmed)
	dialog.canceled.connect(_on_trade_prompt_canceled)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


func _show_trade(trade: Dictionary) -> void:
	if _trade_ui == null:
		_trade_layer = CanvasLayer.new()
		_trade_layer.layer = 100
		_trade_layer.name = "TradeLayer"
		get_tree().root.add_child(_trade_layer)
		_trade_ui = TRADE_SCREEN.instantiate()
		_trade_layer.add_child(_trade_ui)
		_trade_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trade_ui.show()
	_trade_ui.set_trade(trade)


func _hide_trade() -> void:
	if _trade_ui != null:
		_trade_ui.hide()
	for inv in get_tree().get_nodes_in_group("inventory"):
		if inv.has_method("load_inventory"):
			inv.load_inventory()


func _handle_trade_response(response: Dictionary, success_text: String, error_text: String) -> void:
	if not response.get("ok", false):
		if not error_text.is_empty():
			ToastManager.show_toast(error_text, ToastManager.Type.WARNING)
		return
	var trade: Dictionary = _extract_trade(response)
	active_trade = trade
	if not trade.is_empty():
		_show_trade(trade)
		trade_updated.emit(trade)
		if trade.get("status", "") == "completed":
			ToastManager.show_toast("Trade thanh cong.", ToastManager.Type.SUCCESS)
			_hide_trade()
		elif not success_text.is_empty():
			ToastManager.show_toast(success_text)


func _extract_trade(response: Dictionary) -> Dictionary:
	var data: Dictionary = ApiClient.response_data(response)
	var trade = data.get("trade", {})
	return trade if trade is Dictionary else {}


func _on_trade_prompt_confirmed() -> void:
	if _pending_prompt_trade_id > 0:
		accept_trade(_pending_prompt_trade_id)
	_cleanup_trade_prompt()


func _on_trade_prompt_canceled() -> void:
	if _pending_prompt_trade_id > 0:
		cancel_trade(_pending_prompt_trade_id)
	_cleanup_trade_prompt()


func _cleanup_trade_prompt() -> void:
	if _pending_prompt_dialog != null:
		_pending_prompt_dialog.queue_free()
	_pending_prompt_dialog = null
	_pending_prompt_trade_id = -1
