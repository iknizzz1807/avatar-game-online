extends Control
class_name FarmMap

signal plot_action_requested(plotIndex: int, currentState: String);
signal close_requested();

const PLOT_COUNT: int = 16;
const COLUMNS: int = 4;

@onready var gridContainer: GridContainer = $Panel/MC/VBox/GridContainer;
@onready var closeButton: Button = $Panel/MC/VBox/TitleBar/CloseButton;

var plotData: Array = [];
var plotButtons: Array[Button] = [];
var growTimers: Array[float] = [];

func _ready() -> void:
	closeButton.pressed.connect(_on_close_pressed);
	_build_plots();

func _process(delta: float) -> void:
	_tick_countdowns(delta);

func set_plots(data: Array) -> void:
	plotData = data;
	_refresh_plots();

func update_plot(plotDict: Dictionary) -> void:
	var idx: int = plotDict.get("index", -1);
	if idx < 0 or idx >= PLOT_COUNT:
		return;
	if idx < plotData.size():
		plotData[idx] = plotDict;
	_apply_plot(idx, plotDict);

func open_map() -> void:
	visible = true;

func _build_plots() -> void:
	for i: int in range(PLOT_COUNT):
		var btn: Button = Button.new();
		btn.custom_minimum_size = Vector2(72, 72);
		btn.name = "Plot%d" % i;
		btn.text = tr("EMPTY");
		var idx: int = i;
		btn.pressed.connect(func() -> void: _on_plot_pressed(idx));
		gridContainer.add_child(btn);
		plotButtons.append(btn);
		growTimers.append(0.0);

func _refresh_plots() -> void:
	var nowUnix: float = Time.get_unix_time_from_system();
	for i: int in range(PLOT_COUNT):
		var plot: Dictionary = plotData[i] if i < plotData.size() else {};
		var remaining: float = 0.0;
		if plot.get("state", "EMPTY") == "GROWING":
			remaining = max(0.0, float(plot.get("ready_at", 0.0)) - nowUnix);
		growTimers[i] = remaining;
		_apply_plot(i, plot);

func _apply_plot(idx: int, plot: Dictionary) -> void:
	var state: String = plot.get("state", "EMPTY");
	var seedType: String = plot.get("seed_type", "");
	var nowUnix: float = Time.get_unix_time_from_system();
	var remaining: float = max(0.0, float(plot.get("ready_at", 0.0)) - nowUnix);
	if state == "GROWING":
		growTimers[idx] = remaining;
	else:
		growTimers[idx] = 0.0;
	_set_display(idx, state, seedType, remaining);

func _tick_countdowns(delta: float) -> void:
	for i: int in range(PLOT_COUNT):
		if growTimers[i] <= 0.0:
			continue;
		growTimers[i] -= delta;
		if growTimers[i] <= 0.0:
			growTimers[i] = 0.0;
			plotButtons[i].text = tr("READY");
		else:
			var mins: int = int(growTimers[i]) / 60;
			var secs: int = int(growTimers[i]) % 60;
			plotButtons[i].text = "🌿\n%02d:%02d" % [mins, secs];

func _set_display(idx: int, state: String, seedType: String, remaining: float) -> void:
	var btn: Button = plotButtons[idx];
	match state:
		"EMPTY":
			btn.text = tr("EMPTY");
		"SEEDED":
			btn.text = "🌱\n%s" % tr(seedType);
		"GROWING":
			var mins: int = int(remaining) / 60;
			var secs: int = int(remaining) % 60;
			btn.text = "🌿\n%02d:%02d" % [mins, secs];
		"READY":
			btn.text = tr("READY");
		_:
			btn.text = "❓\n???";

func _on_plot_pressed(idx: int) -> void:
	var state: String = "EMPTY";
	if idx < plotData.size():
		state = plotData[idx].get("state", "EMPTY");
	plot_action_requested.emit(idx, state);

func _on_close_pressed() -> void:
	close_requested.emit();
	hide();
