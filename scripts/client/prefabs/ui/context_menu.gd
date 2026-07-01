extends PanelContainer
class_name ContextMenu


const ITEM_PREFAB = preload("res://prefabs/ui/components/context_menu_item.tscn")
signal action_selected(action_id: String, target: Object);
@onready var itemList: VBoxContainer = $MarginContainer/VBoxContainer;

var _target: Object = null;
var _screen_pos: Vector2 = Vector2.ZERO;
var _last_actions_signature: String = "";
var _refresh_elapsed: float = 0.0;
var _active: bool = false;


func _ready() -> void:
	hide();
	add_to_group("context_menu");
	process_mode = Node.PROCESS_MODE_ALWAYS;
	set_process(false);


func _process(delta: float) -> void:
	if not _active or _target == null or not _can_refresh_target_actions():
		return;
	_refresh_elapsed += delta;
	if _refresh_elapsed < 0.15:
		return;
	_refresh_elapsed = 0.0;
	var actions: Array = _target.call("_build_actions");
	var signature := JSON.stringify(actions);
	if signature != _last_actions_signature:
		_set_actions(actions);

func show_menu(actions: Array, target: Object, screen_pos: Vector2) -> void:
	_target = target;
	_screen_pos = screen_pos;
	_refresh_elapsed = 0.0;
	_set_actions(actions);
	_place_at(screen_pos);

	show();
	_active = true;
	set_process(true);

func dismiss() -> void:
	_active = false;
	set_process(false);
	hide();
	_clear_items();
	_target = null;
	_last_actions_signature = "";


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return;
	if event.is_action_pressed("ui_cancel"):
		dismiss();
		get_viewport().set_input_as_handled();
		return;

	if event is InputEventMouseButton and event.pressed:
		var localPos: Vector2 = get_local_mouse_position();
		var menuRect: Rect2 = Rect2(Vector2.ZERO, size);
		if not menuRect.has_point(localPos):
			dismiss();
			get_viewport().set_input_as_handled();

func _on_action_pressed(actionId: String) -> void:
	var target: Object = _target;
	dismiss();
	action_selected.emit(actionId, target);
	print("[ContextMenu] Action '%s' selected on %s" % [actionId, target]);

func _clear_items() -> void:
	for child: Node in itemList.get_children():
		child.queue_free();


func _set_actions(actions: Array) -> void:
	_last_actions_signature = JSON.stringify(actions);
	_clear_items();

	for actionData: Dictionary in actions:
		var id: String      = actionData.get("id", "");
		var label: String   = actionData.get("label", id);
		var enabled: bool   = actionData.get("enabled", true);
		var tooltip: String = actionData.get("tooltip", "");

		var item = ITEM_PREFAB.instantiate() as ContextMenuItem
		itemList.add_child(item)
		item.setup(id, label, enabled, tooltip)
		item.action_pressed.connect(_on_action_pressed)


func _can_refresh_target_actions() -> bool:
	if not _target.has_method("_build_actions"):
		return false
	for method in _target.get_method_list():
		if method.get("name", "") == "_build_actions":
			return method.get("args", []).size() == 0
	return false

func _place_at(pos: Vector2) -> void:
	await get_tree().process_frame;

	var vpSize: Vector2 = get_viewport_rect().size;
	var menuSize: Vector2 = size;

	var clampedX: float = clampf(pos.x, 0.0, vpSize.x - menuSize.x);
	var clampedY: float = clampf(pos.y, 0.0, vpSize.y - menuSize.y);
	global_position = Vector2(clampedX, clampedY);
