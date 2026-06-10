@abstract
extends Area2D
class_name ContextMenuTarget

# ═════════════════════════════════════════════════════════════════════════════
# CONTEXT MENU TARGET — Abstract Base Class
#
# Attach this to any Area2D-based entity that should support a right-click
# context menu (farm slots, other players, NPCs, chests, …).
#
# SUBCLASS CONTRACT
# ─────────────────
# Your subclass MUST override:
#   • _build_actions() -> Array      — return the list of action dicts
#   • _on_context_action(id, target) — handle the chosen action
#
# Your subclass CAN override:
#   • _on_input_event()              — to also handle left-click / other input
#     If you do, call super._on_input_event() OR call _handle_right_click()
#     yourself so right-click still works.
#
# HOW TO ADD A NEW ENTITY TYPE (NPC, chest, etc.)
# ────────────────────────────────────────────────
# 1. Create a script that `extends ContextMenuTarget`.
# 2. Implement _build_actions() with that entity's action list.
# 3. Implement _on_context_action() to react to each action id.
# 4. That's it — all input wiring, menu lookup, and signal management
#    is handled here.
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	input_pickable = true;
	input_event.connect(_on_input_event);
	add_to_group("interactable");

# ─── INPUT ───────────────────────────────────────────────────────────────────

func _on_input_event(_viewport: Node, event: InputEvent, _shapeIdx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return;
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(event.global_position);

## Finds the shared ContextMenu, wires a one-shot signal, and opens the menu.
## Called automatically on right-click. Subclasses rarely need to call this
## directly, but can if they want to open the menu programmatically.
func _handle_right_click(screenPos: Vector2) -> void:
	var menu: ContextMenu = _get_context_menu();
	if not menu:
		push_warning(
			"ContextMenuTarget (%s): No node in group 'context_menu' found. " \
			% [get_script().resource_path] +
			"Make sure a ContextMenu node is present in the scene."
		);
		return;

	# Always disconnect first to prevent duplicate callbacks if the player
	# right-clicks a second entity before dismissing the previous menu.
	if menu.action_selected.is_connected(_on_context_action):
		menu.action_selected.disconnect(_on_context_action);
	menu.action_selected.connect(_on_context_action, CONNECT_ONE_SHOT);

	menu.show_menu(_build_actions(), self, screenPos);

# ─── VIRTUAL METHODS — Override these in your subclass ───────────────────────

## Return the list of actions to show for this entity.
## Each element is a Dictionary with the shape:
##   { "id": String, "label": String, "enabled": bool }
## "enabled" is optional and defaults to true.
##
## Example:
##   return [
##       { "id": "talk",  "label": "💬 Nói chuyện" },
##       { "id": "trade", "label": "🤝 Trao đổi", "enabled": false },
##   ]
func _build_actions() -> Array:
	push_error(
		"ContextMenuTarget: _build_actions() not implemented in '%s'. " \
		% [get_script().resource_path] +
		"Override this method and return an Array of action dicts."
	);
	return [];

## Called when the player selects an action from the context menu.
## Always guard with `if target != self: return` — the signal is shared.
##
## Example:
##   func _on_context_action(actionId: String, target: Object) -> void:
##       if target != self: return
##       match actionId:
##           "talk":  ...
##           "trade": ...
func _on_context_action(_actionId: String, _target: Object) -> void:
	push_error(
		"ContextMenuTarget: _on_context_action() not implemented in '%s'. " \
		% [get_script().resource_path] +
		"Override this method to handle context menu selections."
	);

# ─── PRIVATE ─────────────────────────────────────────────────────────────────

func _get_context_menu() -> ContextMenu:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("context_menu");
	if nodes.is_empty():
		return null;
	return nodes[0] as ContextMenu;
