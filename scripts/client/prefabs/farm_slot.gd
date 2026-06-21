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
		else:
			timerLabel.text = "00:00"
			timerLabel.visible = true
			if not _ready_refresh_requested and ApiClient.has_auth_token():
				_ready_refresh_requested = true
				call_deferred("_load_farm_from_server")
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
				ToastManager.show_toast("Lại gần hơn để trồng cây.", ToastManager.Type.WARNING)
				return
			_request_server_action("plant", "seed_tomato")
			
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
				{ "id": "plant", "label": "🌱 Trồng cây",
				  "enabled": nearby,
				  "tooltip": "" if nearby else "Lại gần hơn để trồng cây" },
			]
		PlotState.SEEDED:
			return [
				{ "id": "water", "label": "💧 Tưới nước",
				  "enabled": nearby,
				  "tooltip": "" if nearby else "Lại gần hơn để tưới nước" },
				{ "id": "remove_seed", "label": "🗑 Nhổ hạt giống",
				  "enabled": nearby,
				  "tooltip": "" if nearby else "Lại gần hơn để nhổ hạt giống" },
			]
		PlotState.GROWING:
			return [
				{ "id": "inspect", "label": "🔍 Kiểm tra cây", "enabled": false,
				  "tooltip": "Cây đang phát triển, hãy đợi thêm" },
			]
		PlotState.READY:
			return [
				{ "id": "harvest", "label": "🌾 Thu hoạch",
				  "enabled": nearby,
				  "tooltip": "" if nearby else "Lại gần hơn để thu hoạch" },
			]
		_:
			return []

func _on_context_action(actionId: String, target: Object) -> void:
	if target != self:
		return
	match actionId:
		"plant":
			if not _is_player_nearby():
				ToastManager.show_toast("Lại gần hơn để trồng cây.", ToastManager.Type.WARNING)
				return
			_request_server_action("plant", "seed_tomato")
		"water":
			# Delegate to the nearby local player so the watering animation plays first.
			_request_water_via_player()
		"remove_seed":
			ToastManager.show_toast("Chưa hỗ trợ nhổ hạt giống trên server.", ToastManager.Type.WARNING)
		"harvest":
			_request_server_action("harvest")
		"inspect":
			print("[FarmSlot %d] Context: Inspecting (GROWING – no action yet)." % plotId)

# ─── HELPER FUNCTIONS ─────────────────────────────────────────────────────────

## Returns true when the local-authority player is overlapping this slot.
func _is_player_nearby() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("local_player"):
			return true
	return false


## Finds the local-authority player overlapping this slot and asks them to
## perform the watering animation. The player will call water() when done.
func _request_water_via_player() -> void:
	if currentState != PlotState.SEEDED:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("local_player") and body.has_method("request_water"):
			body.request_water(self)
			return
	ToastManager.show_toast("Lại gần hơn để tưới nước.", ToastManager.Type.WARNING)


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
	match currentState:
		PlotState.EMPTY:
			plantSprite.visible = false
			# Remove any modulate trick we use for local testing
			$Background.modulate = Color(1.0, 1.0, 1.0)
			
		PlotState.SEEDED:
			# TODO: Once you have sprites, assign the SeedBag or DirtMound texture
			# plantSprite.texture = load("...")
			# plantSprite.visible = true
			# Local debug visual: darken the background a bit to show it's seeded/watered
			$Background.modulate = Color(0.8, 0.6, 0.4)
			
		PlotState.GROWING:
			# TODO: Assign the sprout texture
			# plantSprite.texture = load("...")
			# plantSprite.visible = true
			# Local debug visual: make it a bit green
			$Background.modulate = Color(0.5, 0.8, 0.5)
			
		PlotState.READY:
			# TODO: Assign the mature crop texture
			# plantSprite.texture = load("...")
			# plantSprite.visible = true
			# Local debug visual: make it very green
			$Background.modulate = Color(0.2, 0.9, 0.2)

func _format_time(seconds: int) -> String:
	var minutes: int = seconds / 60
	var remainingSeconds: int = seconds % 60
	return str(minutes).pad_zeros(2) + ":" + str(remainingSeconds).pad_zeros(2)


func _load_farm_from_server() -> void:
	if not ApiClient.has_auth_token():
		return
	var response: Dictionary = await ApiClient.request_json("/api/farm/plots")
	if not response.get("ok", false):
		ToastManager.show_toast("Không tải được nông trại.", ToastManager.Type.WARNING)
		return
	_apply_server_plots(ApiClient.response_data(response).get("plots", []), false)


func _request_server_action(action: String, seed_id: String = "") -> void:
	if not ApiClient.has_auth_token():
		ToastManager.show_toast("Cần đăng nhập server để thao tác nông trại.", ToastManager.Type.WARNING)
		return

	var endpoint := ""
	var body := { "plot_index": plotId }
	match action:
		"plant":
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
		ToastManager.show_toast("Thao tác nông trại thất bại.", ToastManager.Type.WARNING)
		return

	var data: Dictionary = ApiClient.response_data(response)
	_apply_server_plots(data.get("plots", []), true)
	if data.has("inventory"):
		for inv in get_tree().get_nodes_in_group("inventory"):
			if inv.has_method("set_server_inventory"):
				inv.set_server_inventory(data.get("inventory", []))


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
		if broadcast and index == plotId:
			MultiplayerManager.notify_farm_changed(index)


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
