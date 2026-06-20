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

# For local testing, simulate a short growth time (e.g. 5 seconds)
var LOCAL_GROWTH_DURATION: int = 5

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────

func _ready() -> void:
	super._ready()  # ← sets input_pickable, connects _on_input_event, adds to group
	add_to_group("farm_slots")
	_update_visuals()

func _process(_delta: float) -> void:
	if currentState == PlotState.GROWING:
		var currentTime: int = int(Time.get_unix_time_from_system())
		var timeLeft: int = readyAtUnixTime - currentTime
		
		if timeLeft > 0:
			timerLabel.text = _format_time(timeLeft)
			timerLabel.visible = true
		else:
			# --- LOCAL ONLY BEHAVIOR ---
			# Locally, we automatically transition to READY when the timer hits 0.
			# 
			# TODO [SERVER SYNC]: 
			# Do NOT auto-transition on the client! Phase 4 says Go Server runs a background 
			# job and will push the "READY" event to the client. 
			# We should just show "00:00" and wait for the network event.
			currentState = PlotState.READY
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
				ToastManager.show_toast("Lại gần hơn để trồng cây.", ToastManager.Type.WARNING)
				return
			print("Local: Planting seed.")
			# TODO [SERVER SYNC]: Send plant request to Go Server.
			# e.g., NetworkManager.send_plant_request(plotId, selectedSeedId)
			# Do NOT change state here in production, wait for the Server's "OK" response.
			currentState = PlotState.SEEDED
			currentSeedId = "tomato_seed"
			_update_visuals()
			
		PlotState.SEEDED:
			# Delegate to the nearby local player so the watering animation plays first.
			# The player's USE_WATER state calls water() when the animation finishes.
			_request_water_via_player()
			
		PlotState.GROWING:
			print("Local: Plot is growing, please wait.")
			
		PlotState.READY:
			print("Local: Harvesting plot.")
			# TODO [SERVER SYNC]: Send harvest request to Go Server.
			# e.g., NetworkManager.send_harvest_request(plotId)
			# The server will deduct the plant, add to inventory, and return "OK".
			currentState = PlotState.EMPTY
			currentSeedId = ""
			_update_visuals()

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
			print("[FarmSlot %d] Context: Planting seed." % plotId)
			# TODO [SERVER SYNC]: NetworkManager.send_plant_request(plotId, selectedSeedId)
			currentState = PlotState.SEEDED
			currentSeedId = "tomato_seed"
			_update_visuals()
		"water":
			# Delegate to the nearby local player so the watering animation plays first.
			_request_water_via_player()
		"remove_seed":
			print("[FarmSlot %d] Context: Removing seed." % plotId)
			# TODO [SERVER SYNC]: NetworkManager.send_remove_seed_request(plotId)
			currentState = PlotState.EMPTY
			currentSeedId = ""
			_update_visuals()
		"harvest":
			print("[FarmSlot %d] Context: Harvesting." % plotId)
			# TODO [SERVER SYNC]: NetworkManager.send_harvest_request(plotId)
			currentState = PlotState.EMPTY
			currentSeedId = ""
			_update_visuals()
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
	print("[FarmSlot %d] Watered." % plotId)
	# TODO [SERVER SYNC]: NetworkManager.send_water_request(plotId)
	currentState = PlotState.GROWING
	readyAtUnixTime = int(Time.get_unix_time_from_system()) + LOCAL_GROWTH_DURATION
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
