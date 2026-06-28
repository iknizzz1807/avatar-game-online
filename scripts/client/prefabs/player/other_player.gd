extends Area2D
class_name OtherPlayer

# ═════════════════════════════════════════════════════════════════════════════
# OTHER PLAYER
# Extends ContextMenuTarget, which provides all right-click / context menu
# wiring. This class only declares WHAT social actions are available and
# HOW to react to them.
#
# HOW TO ADD A NEW ACTION
# ───────────────────────
# 1. Add a dict to _build_actions().
# 2. Add a matching branch in _on_context_action().
# Done — no changes needed anywhere else.
# ═════════════════════════════════════════════════════════════════════════════

@export var playerName: String = "Unknown"
@export var playerId: int = -1


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

# ─── CONTEXT MENU — ContextMenuTarget interface ───────────────────────────────

func _build_actions() -> Array:
	return [
		{ "id": "view_profile", "label": tr("XEM_TRANG_CÁ_NHÂN") },
		{ "id": "trade",        "label": tr("TRAO_ĐỔI_VẬT_PHẨM") },
		{ "id": "whisper",      "label": tr("NHẮN_RIÊNG") },
		# ── Add future social actions below ──
		# { "id": "invite_farm",  "label": tr("MỜI_ĐẾN_NÔNG_TRẠI") },
		# { "id": "report",       "label": tr("BÁO_CÁO") },
	]

func _on_context_action(actionId: String, target: Object) -> void:
	if target != self:
		return
	match actionId:
		"view_profile":
			_show_profile()
		"trade":
			print("[OtherPlayer] Trade request to: %s (id=%d)" % [playerName, playerId])
			# TODO [SERVER SYNC]: NetworkManager.send_trade_request(playerId)
		"whisper":
			ToastManager.show_toast("Whisper se lam o phase sau.", ToastManager.Type.INFO)
		_:
			print("[OtherPlayer] Unknown action: %s" % actionId)


func _show_profile() -> void:
	if playerId <= 0:
		_show_profile_dialog({ "display_name": playerName, "id": playerId })
		return
	var response: Dictionary = await ApiClient.request_json("/api/user/%d/profile" % playerId)
	if response.get("ok", false):
		_show_profile_dialog(ApiClient.response_data(response))
	else:
		ToastManager.show_toast("Khong tai duoc ho so nguoi choi.", ToastManager.Type.WARNING)


func _show_profile_dialog(profile: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Ho so nguoi choi"
	dialog.dialog_text = "Ten: %s\nID: %s\nXu: %s\nMap: %s" % [
		profile.get("display_name", playerName),
		str(profile.get("id", playerId)),
		str(profile.get("coins", "?")),
		profile.get("current_map", "?"),
	]
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
