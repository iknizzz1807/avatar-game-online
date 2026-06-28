extends PanelContainer
class_name ItemSlot

# ═════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═════════════════════════════════════════════════════════════════════════════

## Fired on a plain click (no drag). Inventory uses this to show the tooltip.
signal slot_clicked(slotIndex: int);
## Fired when another slot's item is dropped onto this one.
signal swap_requested(fromIndex: int, toIndex: int);

# ═════════════════════════════════════════════════════════════════════════════
# STATE
# ═════════════════════════════════════════════════════════════════════════════

var slotIndex: int = -1;
## Slot data dict: { "resource": ItemData, "quantity": int }
## Empty dict {} means the slot is empty.
var slotData: Dictionary = {};

var isSelected: bool = false;
var wasDragging: bool = false;
# ═════════════════════════════════════════════════════════════════════════════
# NODES
# ═════════════════════════════════════════════════════════════════════════════

@onready var iconRect: TextureRect = $Overlay/MarginContainer/TextureRect;
@onready var iconLabel: Label = $Overlay/IconLabel;
@onready var quantityLabel: Label = $Overlay/QuantityLabel;

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Ensure this root node is the sole mouse-event receiver.
	# Children use MOUSE_FILTER_IGNORE so clicks/hover pass through to us.
	mouse_filter = Control.MOUSE_FILTER_STOP;
	_ignore_mouse_on_children(self);
	mouse_entered.connect(_on_mouse_entered);
	mouse_exited.connect(_on_mouse_exited);
	_refresh();

# ═════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═════════════════════════════════════════════════════════════════════════════

## Show [param data] in this slot.
## [param data] must be { "resource": ItemData, "quantity": int } or {} for empty.
func set_item(data: Dictionary) -> void:
	slotData = data;
	_refresh();

## Toggle the selection highlight on this slot.
func set_selected(selected: bool) -> void:
	isSelected = selected;

# ═════════════════════════════════════════════════════════════════════════════
# DRAG-AND-DROP
# ═════════════════════════════════════════════════════════════════════════════

func _get_drag_data(atPosition: Vector2) -> Variant:
	if slotData.is_empty():
		return null;
	wasDragging = true;
	var res: ItemData = slotData["resource"] as ItemData;
	var preview: Control = Control.new();
	preview.custom_minimum_size = Vector2(48, 48);
	if res.texture != null:
		var previewRect: TextureRect = TextureRect.new();
		previewRect.texture = res.texture;
		previewRect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED;
		previewRect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;
		previewRect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);
		preview.add_child(previewRect);
	else:
		var previewLabel: Label = Label.new();
		previewLabel.text = res.icon;
		previewLabel.add_theme_font_size_override("font_size", 28);
		previewLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
		previewLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;
		previewLabel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);
		preview.add_child(previewLabel);
	set_drag_preview(preview);
	return {"from_index": slotIndex};

func _can_drop_data(atPosition: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false;
	return data.has("from_index") and data["from_index"] != slotIndex;

func _drop_data(atPosition: Vector2, data: Variant) -> void:
	swap_requested.emit(data["from_index"], slotIndex);

# ═════════════════════════════════════════════════════════════════════════════
# CLICK
# ═════════════════════════════════════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return ;
	var mb: InputEventMouseButton = event as InputEventMouseButton;
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return ;
	if mb.pressed:
		wasDragging = false;
	else:
		if not wasDragging:
			slot_clicked.emit(slotIndex);

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE
# ═════════════════════════════════════════════════════════════════════════════

## Recursively set mouse_filter = IGNORE on every child Control
## so all mouse events fall through to the root PanelContainer.
func _ignore_mouse_on_children(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE;
		_ignore_mouse_on_children(child);

func _refresh() -> void:
	if not is_node_ready():
		return ;
	if slotData.is_empty() or not slotData.has("resource"):
		iconRect.texture = null;
		iconRect.visible = false;
		iconLabel.visible = false;
		quantityLabel.visible = false;
		return ;
	var res: ItemData = slotData["resource"] as ItemData;
	var hasTexture: bool = res.texture != null;
	iconRect.texture = res.texture;
	iconRect.visible = hasTexture;
	iconLabel.text = res.icon;
	iconLabel.visible = not hasTexture;
	var qty: int = slotData.get("quantity", 0);
	quantityLabel.visible = qty > 1;
	quantityLabel.text = "x%d" % qty;

func _on_mouse_entered() -> void:
	if not isSelected:
		modulate = Color.GRAY;

func _on_mouse_exited() -> void:
	if not isSelected:
		modulate = Color.WHITE;
