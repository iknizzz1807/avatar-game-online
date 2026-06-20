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
	if plotId == -1:
		plotId = get_index()
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
			timerLabel.text = "00:00"
			timerLabel.visible = true
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
			MultiplayerManager.send_farm_action(plotId, "plant", "tomato_seed")
			
		PlotState.SEEDED:
			# Delegate to the nearby local player so the watering animation plays first.
			# The player's USE_WATER state calls water() when the animation finishes.
			_request_water_via_player()
			
		PlotState.GROWING:
			print("Local: Plot is growing, please wait.")
			
		PlotState.READY:
			print("Local: Harvesting plot.")
			MultiplayerManager.send_farm_action(plotId, "harvest")

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
			MultiplayerManager.send_farm_action(plotId, "plant", "tomato_seed")
		"water":
			# Delegate to the nearby local player so the watering animation plays first.
			_request_water_via_player()
		"remove_seed":
			print("[FarmSlot %d] Context: Removing seed." % plotId)
			MultiplayerManager.send_farm_action(plotId, "remove")
		"harvest":
			print("[FarmSlot %d] Context: Harvesting." % plotId)
			MultiplayerManager.send_farm_action(plotId, "harvest")
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
	MultiplayerManager.send_farm_action(plotId, "water")

func sync_state(new_state: int, new_seed: String, new_ready_at: int) -> void:
	currentState = new_state
	currentSeedId = new_seed
	readyAtUnixTime = new_ready_at
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
