extends Area2D
class_name FarmSlot

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

func _ready() -> void:
	# Ensure Area2D can detect clicks
	input_pickable = true
	input_event.connect(_on_input_event)
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

# ─── USER INTERACTION ─────────────────────────────────────────────────────────

func _on_input_event(_viewport: Node, event: InputEvent, _shapeIdx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click()

func _handle_click() -> void:
	match currentState:
		PlotState.EMPTY:
			print("Local: Planting seed.")
			# TODO [SERVER SYNC]: Send plant request to Go Server.
			# e.g., NetworkManager.send_plant_request(plotId, selectedSeedId)
			# Do NOT change state here in production, wait for the Server's "OK" response.
			currentState = PlotState.SEEDED
			currentSeedId = "tomato_seed"
			_update_visuals()
			
		PlotState.SEEDED:
			print("Local: Watering plot.")
			# TODO [SERVER SYNC]: Send water request to Go Server.
			# e.g., NetworkManager.send_water_request(plotId)
			# The server response should include the `readyAt` unix timestamp.
			currentState = PlotState.GROWING
			readyAtUnixTime = int(Time.get_unix_time_from_system()) + LOCAL_GROWTH_DURATION
			_update_visuals()
			
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

# ─── HELPER FUNCTIONS ─────────────────────────────────────────────────────────

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
