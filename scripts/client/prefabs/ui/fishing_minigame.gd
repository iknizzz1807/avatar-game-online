extends Control
class_name FishingMinigame

signal fishing_success()
signal fishing_failed(reason: String)

enum Phase { IDLE, WAITING, BITE, MINIGAME, RESULT }

const WAIT_MIN = 3.0
const WAIT_MAX = 8.0
const BITE_WINDOW = 1.8
const MINIGAME_DURATION = 7.0
const SUCCESS_THRESHOLD = 0.75
const GRAVITY = 180.0
const LIFT = 280.0
const FISH_SPEED_BASE = 40.0
const FISH_SPEED_RAND = 30.0
const BAR_HEIGHT = 200.0
const ZONE_HEIGHT = 56.0
const FISH_HEIGHT = 36.0

@onready var _wait_panel : Control = $WaitPanel
@onready var _bite_panel : Control = $BitePanel
@onready var _bite_label : Label = $BitePanel/BiteMargin/BiteLabel
@onready var _bar_panel : Control = $BarPanel
@onready var _bar_bg : Control = $BarPanel/BarContainer/BarBg
@onready var _fish_zone : TextureRect = $BarPanel/BarContainer/BarBg/FishZone
@onready var _player_zone : ColorRect = $BarPanel/BarContainer/BarBg/PlayerZone
@onready var _catch_bar : ProgressBar = $BarPanel/CatchProgress
@onready var _result_panel : Control = $ResultPanel
@onready var _result_label : Label = $ResultPanel/ResultMargin/ResultLabel
@onready var _bobber : Label = $WaitPanel/VBox/BobberLabel

var _phase : Phase  = Phase.IDLE
var _phase_timer : float  = 0.0
var _player_vel : float  = 0.0
var _player_y : float  = 0.0
var _fish_y : float  = 0.0
var _fish_vel : float  = 0.0
var _catch_progress : float  = 0.0
var _bobber_time : float  = 0.0
var _holding : bool   = false
var _result_timer : float  = 0.0

func _ready() -> void:
	_set_phase(Phase.IDLE)
	set_process(false)
	set_process_unhandled_input(false)


func _process(delta: float) -> void:
	match _phase:
		Phase.WAITING:   _process_waiting(delta)
		Phase.BITE:      _process_bite(delta)
		Phase.MINIGAME:  _process_minigame(delta)
		Phase.RESULT:    _process_result(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.BITE:
		if _is_action_event(event):
			get_viewport().set_input_as_handled()
			_enter_minigame()
	elif _phase == Phase.MINIGAME:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_holding = event.pressed
			get_viewport().set_input_as_handled()

func start() -> void:
	if _phase != Phase.IDLE:
		return
	_set_phase(Phase.WAITING)


func cancel() -> void:
	_set_phase(Phase.IDLE)


func _process_waiting(delta: float) -> void:
	_phase_timer -= delta
	_bobber_time  += delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.BITE)


func _process_bite(delta: float) -> void:
	_phase_timer -= delta
	var alpha: float = 0.6 + 0.4 * sin(_phase_timer * 8.0)
	_bite_label.modulate.a = alpha

	if _phase_timer <= 0.0:
		_phase_timer = 1.5
		_set_phase(Phase.RESULT)
		_finish(false, "Better luck next time!")


func _process_minigame(delta: float) -> void:
	_phase_timer -= delta

	_holding = Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _holding:
		_player_vel -= LIFT * delta
	else:
		_player_vel += GRAVITY * delta

	_player_y = clampf(_player_y + _player_vel * delta,
		0.0, BAR_HEIGHT - ZONE_HEIGHT)
	_player_vel = clampf(_player_vel, -LIFT, GRAVITY)

	# Fish zone movement
	_fish_y += _fish_vel * delta
	if _fish_y <= 0.0:
		_fish_y   = 0.0
		_fish_vel = absf(_fish_vel) + randf_range(20.0, 50.0)
	elif _fish_y >= BAR_HEIGHT - FISH_HEIGHT:
		_fish_y   = BAR_HEIGHT - FISH_HEIGHT
		_fish_vel = -(absf(_fish_vel) + randf_range(20.0, 50.0))

	if randf() < 0.015:
		_fish_vel += randf_range(-FISH_SPEED_RAND, FISH_SPEED_RAND)
	_fish_vel = clampf(_fish_vel,
		-(FISH_SPEED_BASE + FISH_SPEED_RAND),
		 FISH_SPEED_BASE + FISH_SPEED_RAND)

	var overlap: bool = _zones_overlap()
	if overlap:
		_catch_progress = minf(_catch_progress + delta * 0.25, 1.0)
	else:
		_catch_progress = maxf(_catch_progress - delta * 0.20, 0.0)
	_catch_bar.value = _catch_progress * 100.0

	_player_zone.position.y = _player_y
	_fish_zone.position.y   = _fish_y
	_player_zone.modulate   = Color(0.2, 0.85, 0.35, 0.85) if overlap else Color(0.3, 0.6, 0.95, 0.85)

	if _catch_progress >= SUCCESS_THRESHOLD:
		_finish(true, "")
	elif _phase_timer <= 0.0:
		_finish(false, "Better luck next time!")


func _process_result(delta: float) -> void:
	_result_timer -= delta
	if _result_timer <= 0.0:
		_set_phase(Phase.IDLE)

func _set_phase(p: Phase) -> void:
	_phase = p
	_wait_panel.hide()
	_bite_panel.hide()
	_bar_panel.hide()
	_result_panel.hide()

	match p:
		Phase.IDLE:
			set_process(false)
			set_process_unhandled_input(false)
			hide()

		Phase.WAITING:
			_phase_timer = randf_range(WAIT_MIN, WAIT_MAX)
			_bobber_time = 0.0
			_wait_panel.show()
			show()
			set_process(true)
			set_process_unhandled_input(false)

		Phase.BITE:
			_phase_timer = BITE_WINDOW
			_bite_panel.show()
			_bite_label.modulate.a = 1.0
			set_process_unhandled_input(true)

		Phase.MINIGAME:
			_phase_timer    = MINIGAME_DURATION
			_player_y       = (BAR_HEIGHT - ZONE_HEIGHT) * 0.5
			_fish_y         = (BAR_HEIGHT - FISH_HEIGHT) * 0.3
			_player_vel     = 0.0
			_fish_vel       = FISH_SPEED_BASE
			_catch_progress = 0.0
			_catch_bar.value = 0.0
			_player_zone.position.y = _player_y
			_fish_zone.position.y   = _fish_y
			_bar_panel.show()
			set_process_unhandled_input(true)

		Phase.RESULT:
			set_process_unhandled_input(false)
			_result_panel.show()


func _enter_minigame() -> void:
	_set_phase(Phase.MINIGAME)


func _finish(success: bool, reason: String) -> void:
	_set_phase(Phase.RESULT)
	_result_timer = 1.8
	if success:
		_result_label.text     = tr("CÁ_CẮN_CÂU")
		_result_label.modulate = Color(0.3, 1.0, 0.4)
		fishing_success.emit()
	else:
		_result_label.text     = "💨 " + reason
		_result_label.modulate = Color(1.0, 0.4, 0.35)
		fishing_failed.emit(reason)

func _zones_overlap() -> bool:
	var pTop:    float = _player_y
	var pBottom: float = _player_y + ZONE_HEIGHT
	var fTop:    float = _fish_y
	var fBottom: float = _fish_y + FISH_HEIGHT
	return pBottom > fTop and pTop < fBottom


func _is_action_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_SPACE
	if event is InputEventMouseButton and event.pressed:
		return event.button_index == MOUSE_BUTTON_LEFT
	return false
