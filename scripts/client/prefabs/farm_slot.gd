extends ContextMenuTarget
class_name FarmSlot

# ═════════════════════════════════════════════════════════════════════════════
# FARM SLOT
# Extends ContextMenuTarget, which provides all right-click / context menu
# wiring. This class only needs to declare WHAT actions are available and
# HOW to react to them.
# ═════════════════════════════════════════════════════════════════════════════

enum PlotState {
	EMPTY,
	SEEDED,
	GROWING,
	READY
}

@onready var plantSprite: Sprite2D = $Plant
@onready var timerLabel: Label = $Timer

## How close (pixels) the player must be to interact with this plot.
## Adjust this in the Inspector without changing the collision shape.
@export var watering_distance: float = 80.0

# State variables
var plotId: int = -1
var currentState: int = PlotState.EMPTY
var readyAtUnixTime: int = 0
var currentSeedId: String = ""
var _ready_refresh_requested: bool = false

# For local testing, simulate a short growth time (e.g. 5 seconds)
var LOCAL_GROWTH_DURATION: int = 5

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if plotId == -1:
		plotId = get_index()
	super._ready()  # ← sets input_pickable, connects _on_input_event, adds to group
	add_to_group("farm_slots")
	_update_visuals()
	if plotId == 0:
		call_deferred("_load_farm_from_server")

func _process(_delta: float) -> void:
	if currentState == PlotState.GROWING:
		var currentTime: int = int(Time.get_unix_time_from_system())
		var timeLeft: int = readyAtUnixTime - currentTime
		
		if timeLeft > 0:
			timerLabel.text = _format_time(timeLeft)
			timerLabel.visible = true
			_update_visuals()  # refresh the growth-stage sprite every frame
		else:
			currentState = PlotState.READY
			_ready_refresh_requested = false
			_update_visuals()
	else:
		timerLabel.visible = false

# ─── INPUT ────────────────────────────────────────────────────────────────────
# Override to add left-click on top of the right-click from ContextMenuTarget.

func _on_input_event(_viewport: Node, event: InputEvent, _shapeIdx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_click()
		MOUSE_BUTTON_RIGHT:
			_handle_right_click(event.global_position)  # inherited from ContextMenuTarget

# ─── LEFT-CLICK BEHAVIOUR ────────────────────────────────────────────────────

func _handle_click() -> void:
	match currentState:
		PlotState.EMPTY:
			if not _is_player_nearby():
				ToastManager.show_toast(tr("MOVE_CLOSER_TO_PLANT"), ToastManager.Type.WARNING)
				return
			_request_server_action("plant")
			
		PlotState.SEEDED:
			# Delegate to the nearby local player so the watering animation plays first.
			# The player's USE_WATER state calls water() when the animation finishes.
			_request_water_via_player()
			
		PlotState.GROWING:
			print("Local: Plot is growing, please wait.")
			
		PlotState.READY:
			_request_server_action("harvest")

# ─── CONTEXT MENU — ContextMenuTarget interface ───────────────────────────────

## Returns state-appropriate actions for this plot.
## Add new actions by appending dicts here; no other file needs changing.
func _build_actions() -> Array:
	var nearby := _is_player_nearby()
	match currentState:
		PlotState.EMPTY:
			return [
				{ "id": "plant", "label": tr("PLANT"),
				  "enabled": nearby,
				  "tooltip": "" if nearby else tr("MOVE_CLOSER_TO_PLANT") },
			]
		PlotState.SEEDED:
			return [
				{ "id": "water", "label": tr("WATER"),
				  "enabled": nearby,
				  "tooltip": "" if nearby else tr("MOVE_CLOSER_TO_WATER") },
				{ "id": "remove_seed", "label": tr("REMOVE_SEED"),
				  "enabled": nearby,
				  "tooltip": "" if nearby else tr("MOVE_CLOSER_TO_REMOVE_SEED") },
			]
		PlotState.GROWING:
			return [
				{ "id": "inspect", "label": tr("INSPECT_PLANT"), "enabled": false,
				  "tooltip": tr("PLANT_IS_GROWING_PLEASE_WAIT") },
			]
		PlotState.READY:
			return [
				{ "id": "harvest", "label": tr("HARVEST"),
				  "enabled": nearby,
				  "tooltip": "" if nearby else tr("MOVE_CLOSER_TO_HARVEST") },
			]
		_:
			return []

func _on_context_action(actionId: String, target: Object) -> void:
	if target != self:
		return
	match actionId:
		"plant":
			if not _is_player_nearby():
				ToastManager.show_toast(tr("MOVE_CLOSER_TO_PLANT"), ToastManager.Type.WARNING)
				return
			_request_server_action("plant")
		"water":
			# Delegate to the nearby local player so the watering animation plays first.
			_request_water_via_player()
		"remove_seed":
			ToastManager.show_toast(tr("REMOVING_SEED_NOT_SUPPORTED_ON"), ToastManager.Type.WARNING)
		"harvest":
			_request_server_action("harvest")
		"inspect":
			print("[FarmSlot %d] Context: Inspecting (GROWING – no action yet)." % plotId)

# ─── HELPER FUNCTIONS ─────────────────────────────────────────────────────────

## Returns true when the local-authority player is within [watering_distance] pixels.
## Uses a world-space distance check so the collision shape (click area) is unaffected.
func _is_player_nearby() -> bool:
	for node in get_tree().get_nodes_in_group("local_player"):
		if node is Node2D:
			if global_position.distance_to(node.global_position) <= watering_distance:
				return true
	return false


## Finds the local-authority player within [watering_distance] and asks them to
## perform the watering animation. The player will call water() when done.
func _request_water_via_player() -> void:
	if currentState != PlotState.SEEDED:
		return
	for node in get_tree().get_nodes_in_group("local_player"):
		if node is Node2D and node.has_method("request_water"):
			if global_position.distance_to(node.global_position) <= watering_distance:
				node.request_water(self)
				return
	ToastManager.show_toast(tr("MOVE_CLOSER_TO_WATER"), ToastManager.Type.WARNING)


## Called by PlayerUseWaterState after the watering animation finishes.
## This is the only place that actually advances the plot to GROWING.
func water() -> void:
	if currentState != PlotState.SEEDED:
		return
	_request_server_action("water")

func sync_state(new_state: int, new_seed: String, new_ready_at: int) -> void:
	currentState = new_state
	currentSeedId = new_seed
	readyAtUnixTime = new_ready_at
	_ready_refresh_requested = false
	_update_visuals()


func _update_visuals() -> void:
	var item_data: ItemData = Items.get_item_by_server_id(currentSeedId) if not currentSeedId.is_empty() else null
	var sprites: Array = item_data.growthSprites if item_data and not item_data.growthSprites.is_empty() else []

	match currentState:
		PlotState.EMPTY:
			plantSprite.visible = false
			$Background.modulate = Color(1.0, 1.0, 1.0)

		PlotState.SEEDED:
			if sprites.is_empty():
				plantSprite.visible = false
				$Background.modulate = Color(0.8, 0.6, 0.4)
			else:
				plantSprite.texture = sprites[0]
				plantSprite.visible = true
				$Background.modulate = Color(1.0, 1.0, 1.0)

		PlotState.GROWING:
			if sprites.is_empty():
				plantSprite.visible = false
				$Background.modulate = Color(0.5, 0.8, 0.5)
			else:
				# Map elapsed time fraction → sprite index within [0, last]
				var grow_secs: float = float(item_data.growSecs) if item_data.growSecs > 0 else 1.0
				var current_unix: int = int(Time.get_unix_time_from_system())
				# readyAtUnixTime was set when watering began
				var start_unix: float = float(readyAtUnixTime) - grow_secs
				var elapsed: float = clampf(float(current_unix) - start_unix, 0.0, grow_secs)
				var progress: float = elapsed / grow_secs            # 0.0 → 1.0
				var idx: int = int(progress * (sprites.size() - 1))  # 0 → last index
				idx = clampi(idx, 0, sprites.size() - 1)
				plantSprite.texture = sprites[idx]
				plantSprite.visible = true
				$Background.modulate = Color(1.0, 1.0, 1.0)

		PlotState.READY:
			if sprites.is_empty():
				plantSprite.visible = false
				$Background.modulate = Color(0.2, 0.9, 0.2)
			else:
				plantSprite.texture = sprites[sprites.size() - 1]
				plantSprite.visible = true
				$Background.modulate = Color(1.0, 1.0, 1.0)

func _format_time(seconds: int) -> String:
	var minutes: int = seconds / 60
	var remainingSeconds: int = seconds % 60
	return str(minutes).pad_zeros(2) + ":" + str(remainingSeconds).pad_zeros(2)


func _load_farm_from_server() -> void:
	if not ApiClient.has_auth_token():
		return
	var response: Dictionary = await ApiClient.request_json("/api/farm/plots")
	if not response.get("ok", false):
		ToastManager.show_toast(tr("FAILED_TO_LOAD_FARM"), ToastManager.Type.WARNING)
		return
	_apply_server_plots(ApiClient.response_data(response).get("plots", []), false)


func _request_server_action(action: String, seed_id: String = "") -> void:
	if not ApiClient.has_auth_token():
		ToastManager.show_toast(tr("MUST_LOG_IN_TO_THE_SERVER_TO_M"), ToastManager.Type.WARNING)
		return

	var endpoint := ""
	var body := { "plot_index": plotId }
	match action:
		"plant":
			if seed_id.is_empty():
				seed_id = _get_hotbar_seed_id()
			if seed_id.is_empty():
				seed_id = await _pick_available_seed_id()
			if seed_id.is_empty():
				ToastManager.show_toast(tr("YOU_NEED_TO_BUY_SEEDS_FIRST"), ToastManager.Type.WARNING)
				return
			endpoint = "/api/farm/seed"
			body["seed_id"] = seed_id
		"water":
			endpoint = "/api/farm/water"
		"harvest":
			endpoint = "/api/farm/harvest"
		_:
			return

	var response: Dictionary = await ApiClient.request_json(endpoint, HTTPClient.METHOD_POST, body)
	if not response.get("ok", false):
		ToastManager.show_toast(_farm_error_message(response), ToastManager.Type.WARNING)
		return

	var data: Dictionary = ApiClient.response_data(response)
	_apply_server_plots(data.get("plots", []), true)
	if data.has("inventory"):
		var raw_inv: Array = data.get("inventory", [])
		# Push to the inventory panel so its internal state stays current.
		for inv in get_tree().get_nodes_in_group("inventory"):
			if inv.has_method("set_server_inventory"):
				inv.set_server_inventory(raw_inv)

	# Always refresh the hotbar directly from the server after any successful
	# farm action — this works even when the inventory panel is closed and
	# regardless of whether the server response included inventory data.
	for hotbar in get_tree().get_nodes_in_group("hotbar"):
		if hotbar.has_method("refresh_from_server"):
			hotbar.refresh_from_server()


func _apply_server_plots(plots: Array, broadcast: bool) -> void:
	for plot in plots:
		if not plot is Dictionary:
			continue
		var plot_data: Dictionary = plot
		var index: int = int(plot_data.get("plot_index", -1))
		var state: int = _plot_status_to_state(plot_data.get("status", "EMPTY"))
		var seed_id: String = plot_data.get("seed_id", "")
		var ready_at: int = int(plot_data.get("ready_at", 0))
		for slot in get_tree().get_nodes_in_group("farm_slots"):
			if slot.plotId == index:
				slot.sync_state(state, seed_id, ready_at)
				break


func _plot_status_to_state(status: String) -> int:
	match status:
		"SEEDED":
			return PlotState.SEEDED
		"GROWING":
			return PlotState.GROWING
		"READY":
			return PlotState.READY
		_:
			return PlotState.EMPTY


func _farm_error_message(response: Dictionary) -> String:
	var error_code: String = response.get("error", "")
	if error_code.is_empty():
		var body: Dictionary = response.get("body", {})
		var debug_message: String = body.get("message", "")
		if debug_message == "INVALID_INPUT":
			return tr("YOU_NEED_TO_BUY_SEEDS_OR_ARE_I")
		if not debug_message.is_empty():
			return debug_message
	match error_code:
		"INVALID_INPUT":
			return tr("YOU_NEED_TO_BUY_SEEDS_OR_ARE_I")
		"PLOT_NOT_EMPTY":
			return tr("THIS_PLOT_HAS_ALREADY_BEEN_PLA")
		"PLOT_NOT_SEEDED":
			return tr("THIS_PLOT_IS_NOT_SEEDED")
		"PLOT_NOT_READY":
			return tr("PLANT_IS_NOT_READY_FOR_HARVEST")
		"INVENTORY_FULL":
			return tr("INVENTORY_IS_FULL")
		_:
			return tr("FARM_ACTION_FAILED")


func _pick_available_seed_id() -> String:
	var preferred := ["seed_beetroot", "seed_cabbage", "seed_carrot", "seed_cauliflower", "seed_kale", "seed_parsnip", "seed_potato", "seed_pumpkin", "seed_radish", "seed_sunflower", "seed_wheat"]
	var seed_counts := {}
	for inv in get_tree().get_nodes_in_group("inventory"):
		if "inventoryData" in inv:
			for slot in inv.inventoryData:
				if slot is Dictionary and not slot.is_empty():
					var server_id: String = slot.get("server_id", "")
					if server_id.begins_with("seed_"):
						seed_counts[server_id] = int(slot.get("quantity", 0))
	for seed_id in preferred:
		if int(seed_counts.get(seed_id, 0)) > 0:
			return seed_id

	var response: Dictionary = await ApiClient.request_json("/api/inventory")
	if not response.get("ok", false):
		return ""
	var items: Array = ApiClient.response_data(response).get("inventory", [])
	for item in items:
		if item is Dictionary:
			var item_id: String = item.get("item_id", "")
			if item_id.begins_with("seed_") and int(item.get("quantity", 0)) > 0:
				return item_id
	return ""


## Reads the currently selected seed_id from the player's hotbar.
## Returns an empty string if no seed is selected (caller should fall back to auto-pick).
func _get_hotbar_seed_id() -> String:
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("get_hotbar"):
			var hb = hud.get_hotbar()
			if hb and not hb.selected_seed_id.is_empty():
				return hb.selected_seed_id
	return ""
