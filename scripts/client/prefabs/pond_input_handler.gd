extends TileMapLayer
## PondInputHandler — attach this script to the Water TileMapLayer in fish_pond.tscn.
##
## Handles:
##   • Left-click on any water tile  → start fishing immediately
##   • Right-click on any water tile → show a context menu with fishing actions
##
## Proximity check: the local player must be within FISH_RANGE pixels of the
## clicked tile, otherwise a warning toast is shown.

# ── Tuning ────────────────────────────────────────────────────────────────────
const FISH_RANGE: float = 90.0   ## Max distance (px) player can be to fish

# ── State ─────────────────────────────────────────────────────────────────────
var _is_fishing: bool = false


# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("pond_input_handler")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	# Check if the click landed on a filled water tile
	var local_pos: Vector2  = to_local(get_global_mouse_position())
	var cell:      Vector2i = local_to_map(local_pos)
	if get_cell_source_id(cell) == -1:
		return   # Not a water tile

	var world_pos: Vector2 = map_to_local(cell) + Vector2(8, 8)  # tile centre
	var player:    Node    = _get_local_player()

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_handle_left_click(world_pos, player)
		MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			_handle_right_click(world_pos, player, event.global_position)


# ─────────────────────────────────────────────────────────────────────────────
# CLICK HANDLERS
# ─────────────────────────────────────────────────────────────────────────────

func _handle_left_click(tile_world_pos: Vector2, player: Node) -> void:
	if not _check_proximity(tile_world_pos, player):
		return
	if _is_fishing:
		_stop_fishing()
	else:
		_start_fishing(tile_world_pos, player)


func _handle_right_click(tile_world_pos: Vector2, player: Node, screen_pos: Vector2) -> void:
	var menus := get_tree().get_nodes_in_group("context_menu")
	if menus.is_empty():
		return
	var menu: ContextMenu = menus[0] as ContextMenu

	if menu.action_selected.is_connected(_on_context_action):
		menu.action_selected.disconnect(_on_context_action)
	menu.action_selected.connect(_on_context_action.bind(tile_world_pos, player), CONNECT_ONE_SHOT)

	menu.show_menu(_build_actions(tile_world_pos, player), self, screen_pos)


# ─────────────────────────────────────────────────────────────────────────────
# CONTEXT MENU
# ─────────────────────────────────────────────────────────────────────────────

func _build_actions(tile_world_pos: Vector2, player: Node) -> Array:
	var in_range: bool = _check_proximity_silent(tile_world_pos, player)
	return [
		{
			"id": "start",
			"label": tr("CÂU_CÁ"),
			"enabled": in_range and not _is_fishing,
			"tooltip": tr("BẠN_ĐỨNG_QUÁ_XA_MẶT_NƯỚC") if not in_range else (tr("ĐANG_CÂU_RỒI") if _is_fishing else "")
		},
		{
			"id": "stop",
			"label": tr("DỪNG_CÂU"),
			"enabled": _is_fishing,
			"tooltip": tr("BẠN_CHƯA_CÂU") if not _is_fishing else ""
		},
		{
			"id": "buy_rod",
			"label": tr("MUA_CẦN_CÂU"),
			"enabled": ApiClient.has_auth_token(),
			"tooltip": tr("CẦN_ĐĂNG_NHẬP_SERVER")
		},
		{
			"id": "buy_bait",
			"label": tr("MUA_MỒI_CÂU"),
			"enabled": ApiClient.has_auth_token(),
			"tooltip": tr("CẦN_ĐĂNG_NHẬP_SERVER")
		},
	]


func _on_context_action(action_id: String, _target: Object, tile_world_pos: Vector2, player: Node) -> void:
	match action_id:
		"start":
			if _check_proximity(tile_world_pos, player):
				_start_fishing(tile_world_pos, player)
		"stop":
			_stop_fishing()
		"buy_rod":
			_buy_item("rod_bamboo")
		"buy_bait":
			_buy_item("bait_normal")


# ─────────────────────────────────────────────────────────────────────────────
# FISHING API
# ─────────────────────────────────────────────────────────────────────────────

func _start_fishing(tile_world_pos: Vector2, player: Node) -> void:
	if _is_fishing:
		return

	# Direction from player toward clicked tile
	var dir: Vector2 = Vector2.DOWN
	if player != null:
		var diff: Vector2 = tile_world_pos - player.global_position
		if diff.length() > 1.0:
			dir = diff.normalized()

	# Call server if connected
	if ApiClient.has_auth_token():
		var response: Dictionary = await ApiClient.request_json(
			"/api/fishing/start",
			HTTPClient.METHOD_POST,
			{ "seat_index": 0 }
		)
		if not response.get("ok", false):
			ToastManager.show_toast(_fishing_error_message(response.get("error", "")), ToastManager.Type.WARNING)
			return
		_sync_inventory(ApiClient.response_data(response))

	_is_fishing = true

	if player != null and player.has_method("start_fishing"):
		player.start_fishing(dir)


func _stop_fishing() -> void:
	if not _is_fishing:
		return
	_is_fishing = false

	# Tell the player to stop
	for p in get_tree().get_nodes_in_group("local_player"):
		if p.has_method("stop_fishing"):
			p.stop_fishing()
		break

	if ApiClient.has_auth_token():
		var response: Dictionary = await ApiClient.request_json(
			"/api/fishing/stop",
			HTTPClient.METHOD_POST
		)
		if response.get("ok", false):
			_sync_inventory(ApiClient.response_data(response))
			ToastManager.show_toast("Stopped fishing.")
		else:
			ToastManager.show_toast("You are not fishing.", ToastManager.Type.WARNING)
	else:
		ToastManager.show_toast("Stopped fishing.")


## Called by PlayerFishingState after the minigame is won.
func on_minigame_success() -> void:
	_is_fishing = false
	if ApiClient.has_auth_token():
		var response: Dictionary = await ApiClient.request_json(
			"/api/fishing/claim",
			HTTPClient.METHOD_POST
		)
		if response.get("ok", false):
			var data: Dictionary = ApiClient.response_data(response)
			_sync_inventory(data)
			var result: Dictionary = data.get("result", {})
			var item_id: String = result.get("item_id", "")
			if item_id.is_empty():
				ToastManager.show_toast(tr("CÁ_CHẠY_MẤT_RỒI"), ToastManager.Type.WARNING)
			else:
				var item_name: String = item_id
				if Engine.has_singleton("Items"):
					var item = Items.get_item_by_server_id(item_id)
					if item:
						item_name = tr(item.itemName)
				ToastManager.show_toast(tr("CÂU_ĐƯỢC") % item_name, ToastManager.Type.SUCCESS)
		else:
			ToastManager.show_toast(tr("CHƯA_CÓ_CÁ_CẮN_CÂU"), ToastManager.Type.WARNING)
	else:
		# Offline / no auth — give a placeholder reward toast
		ToastManager.show_toast(tr("CÂU_ĐƯỢC_CÁ"), ToastManager.Type.SUCCESS)


## Called by PlayerFishingState after the minigame is lost.
func on_minigame_failed(_reason: String) -> void:
	_is_fishing = false
	if ApiClient.has_auth_token():
		var response: Dictionary = await ApiClient.request_json(
			"/api/fishing/fail",
			HTTPClient.METHOD_POST
		)
		if response.get("ok", false):
			_sync_inventory(ApiClient.response_data(response))


func _buy_item(item_id: String) -> void:
	if not ApiClient.has_auth_token():
		ToastManager.show_toast("Cần đăng nhập server để mua vật phẩm.", ToastManager.Type.WARNING)
		return
	var response: Dictionary = await ApiClient.request_json(
		"/api/shop/buy",
		HTTPClient.METHOD_POST,
		{ "item_id": item_id, "quantity": 1 }
	)
	if response.get("ok", false):
		ToastManager.show_toast("Fish rod acquired.")
		_sync_inventory(ApiClient.response_data(response))
	else:
		ToastManager.show_toast(_shop_error_message(response.get("error", "")), ToastManager.Type.WARNING)


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _check_proximity(tile_world_pos: Vector2, player: Node) -> bool:
	if not _check_proximity_silent(tile_world_pos, player):
		ToastManager.show_toast("Lại gần mặt nước hơn để câu cá.", ToastManager.Type.WARNING)
		return false
	return true


func _check_proximity_silent(tile_world_pos: Vector2, player: Node) -> bool:
	if player == null:
		return false
	return player.global_position.distance_to(tile_world_pos) <= FISH_RANGE


func _get_local_player() -> Node:
	var players := get_tree().get_nodes_in_group("local_player")
	return players[0] if not players.is_empty() else null


func _sync_inventory(data: Dictionary) -> void:
	if not data.has("inventory"):
		return
	for inv in get_tree().get_nodes_in_group("inventory"):
		if inv.has_method("set_server_inventory"):
			inv.set_server_inventory(data.get("inventory", []))


func _fishing_error_message(error_code: String) -> String:
	match error_code:
		"NO_FISHING_ROD":
			return "You need a fishing rod."
		"NO_BAIT":
			return "You need baits."
		"SEAT_OCCUPIED":
			return "Seat acquired."
		"INVALID_INPUT":
			return "Out of range."
		_:
			return "Cannot fish."


func _shop_error_message(error_code: String) -> String:
	match error_code:
		"INSUFFICIENT_FUNDS":
			return tr("BẠN_KHÔNG_ĐỦ_XU_ĐỂ_MUA_VẬT_PHẨ")
		"INVENTORY_FULL":
			return tr("INVENTORY_IS_FULL_DOT")
		"INVALID_INPUT":
			return tr("VẬT_PHẨM_NÀY_KHÔNG_BÁN_TRONG_S")
		_:
			return tr("KHÔNG_MUA_ĐƯỢC_VẬT_PHẨM")
