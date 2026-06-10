extends PanelContainer
class_name ContextMenu

# ═════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═════════════════════════════════════════════════════════════════════════════

## Emitted when the player clicks an action item.
## [param action_id]  String key for the chosen action (e.g. "plant", "harvest").
## [param target]     The game-world object that was right-clicked (FarmSlot,
##                    OtherPlayer, NPC, etc.) – cast to the type you expect.
signal action_selected(action_id: String, target: Object);

# ═════════════════════════════════════════════════════════════════════════════
# NODES
# ═════════════════════════════════════════════════════════════════════════════

@onready var itemList: VBoxContainer = $MarginContainer/VBoxContainer;

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE STATE
# ═════════════════════════════════════════════════════════════════════════════

## The world object that opened this menu (FarmSlot, OtherPlayer, …).
var _target: Object = null;

## Whether the menu is currently visible and consuming input.
var _active: bool = false;

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	hide();
	add_to_group("context_menu");
	# Process input even when paused, so the menu can always be dismissed.
	process_mode = Node.PROCESS_MODE_ALWAYS;

# ═════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═════════════════════════════════════════════════════════════════════════════

## Show the context menu at [param screen_pos] with [param actions].
##
## [param actions]    Array of Dictionaries. Each dict shape:
##     {
##         "id":      String   – unique action key, e.g. "plant"
##         "label":   String   – display text, e.g. "🌱 Trồng cây"
##         "enabled": bool     – (optional, default true) greys out the button
##     }
##
## [param target]     The game object that was right-clicked. Passed back via
##                    [signal action_selected] so callers know which object
##                    the action should apply to.
##
## To add a new target type (NPC, chest, etc.) just call this method from
## that object with its own action list — no changes needed here.
func show_menu(actions: Array, target: Object, screen_pos: Vector2) -> void:
	_target = target;
	_clear_items();

	for actionData: Dictionary in actions:
		var id: String = actionData.get("id", "");
		var label: String = actionData.get("label", id);
		var enabled: bool = actionData.get("enabled", true);

		var btn: Button = Button.new();
		btn.text = label;
		btn.disabled = not enabled;
		btn.flat = false;
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT;
		btn.focus_mode = Control.FOCUS_NONE;

		# Capture loop variable
		var capturedId: String = id;
		btn.pressed.connect(func() -> void: _on_action_pressed(capturedId));

		itemList.add_child(btn);

	# Position the menu; clamp so it never goes off-screen.
	_place_at(screen_pos);

	show();
	_active = true;

## Close the menu without selecting any action.
func dismiss() -> void:
	_active = false;
	hide();
	_clear_items();
	_target = null;

# ═════════════════════════════════════════════════════════════════════════════
# INPUT HANDLING
# ═════════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return;

	# Dismiss on Escape
	if event.is_action_pressed("ui_cancel"):
		dismiss();
		get_viewport().set_input_as_handled();
		return;

	# Dismiss when clicking anywhere outside the panel
	if event is InputEventMouseButton and event.pressed:
		var localPos: Vector2 = get_local_mouse_position();
		var menuRect: Rect2 = Rect2(Vector2.ZERO, size);
		if not menuRect.has_point(localPos):
			dismiss();
			get_viewport().set_input_as_handled();

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE HELPERS
# ═════════════════════════════════════════════════════════════════════════════

func _on_action_pressed(actionId: String) -> void:
	var target: Object = _target;
	dismiss();
	action_selected.emit(actionId, target);
	print("[ContextMenu] Action '%s' selected on %s" % [actionId, target]);

func _clear_items() -> void:
	for child: Node in itemList.get_children():
		child.queue_free();

## Place the menu at [param pos], clamping so it stays fully within the viewport.
func _place_at(pos: Vector2) -> void:
	# We need the panel to be the right size before clamping, so force a layout pass.
	await get_tree().process_frame;

	var vpSize: Vector2 = get_viewport_rect().size;
	var menuSize: Vector2 = size;

	var clampedX: float = clampf(pos.x, 0.0, vpSize.x - menuSize.x);
	var clampedY: float = clampf(pos.y, 0.0, vpSize.y - menuSize.y);
	global_position = Vector2(clampedX, clampedY);
