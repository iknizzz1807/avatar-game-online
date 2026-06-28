extends Control
class_name Chat

# ═════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═════════════════════════════════════════════════════════════════════════════

## Fired when the local player submits a message.
## Connect to: Go Server sender AND Player node (to trigger chat bubble).
signal message_sent(text: String);

# ═════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═════════════════════════════════════════════════════════════════════════════

const MAX_CHARS: int = 100;
const MAX_DISPLAYED: int = 50;
## Seconds the bubble stays visible above the player's head.
const BUBBLE_DURATION: float = 4.0;
const MESSAGE_LIFETIME: float = 10.0;

# ═════════════════════════════════════════════════════════════════════════════
# VARIABLES
# ═════════════════════════════════════════════════════════════════════════════

var fade_speed: float = 4.0
var ui_alpha: float = 1.0

# ═════════════════════════════════════════════════════════════════════════════
# NODES
# ═════════════════════════════════════════════════════════════════════════════

@onready var messageList: VBoxContainer = $Panel/VBox/Scroll/MessageList;
@onready var scrollContainer: ScrollContainer = $Panel/VBox/Scroll;
@onready var messageInput: LineEdit = $Panel/VBox/InputRow/MessageInput;
@onready var sendButton: Button = $Panel/VBox/InputRow/SendButton;

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("chat_ui")
	sendButton.pressed.connect(_on_send_pressed);
	messageInput.text_submitted.connect(_on_text_submitted);
	messageInput.max_length = MAX_CHARS;
	message_sent.connect(MultiplayerManager.send_chat_message)
	MultiplayerManager.chat_received.connect(receive_message)

func _process(delta: float) -> void:
	var is_active = messageInput.has_focus() or $Panel.get_global_rect().has_point(get_global_mouse_position())
	var target_alpha = 1.0 if is_active else 0.0
	
	if ui_alpha != target_alpha:
		ui_alpha = move_toward(ui_alpha, target_alpha, delta * fade_speed)
		$Panel.self_modulate.a = ui_alpha
		$Panel/VBox/TitleLabel.modulate.a = ui_alpha
		$Panel/VBox/InputRow.modulate.a = ui_alpha
		
		if ui_alpha < 0.99:
			scrollContainer.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		else:
			scrollContainer.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			
	for lbl in messageList.get_children():
		if not lbl.has_meta("time_left"):
			continue
		var time_left = lbl.get_meta("time_left") as float
		if not is_active:
			time_left -= delta
			lbl.set_meta("time_left", time_left)
		else:
			lbl.set_meta("time_left", MESSAGE_LIFETIME)
			
		if is_active:
			lbl.modulate.a = move_toward(lbl.modulate.a, 1.0, delta * fade_speed)
		else:
			if time_left <= 0.0:
				lbl.modulate.a = move_toward(lbl.modulate.a, 0.0, delta * fade_speed)
			else:
				lbl.modulate.a = move_toward(lbl.modulate.a, 1.0, delta * fade_speed)

# ═════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═════════════════════════════════════════════════════════════════════════════

## Add a message received from the Godot Server (broadcast from another player).
## [param senderName] display name. [param text] message body.
func receive_message(senderName: String, text: String) -> void:
	_add_line("[%s]: %s" % [senderName, text]);

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE
# ═════════════════════════════════════════════════════════════════════════════

func _on_send_pressed() -> void:
	_submit();

func _on_text_submitted(_t: String) -> void:
	_submit();

func _submit() -> void:
	var text: String = messageInput.text.strip_edges();
	if text.is_empty():
		return;
	messageInput.text = "";
	message_sent.emit(text);
	_add_line(tr("BẠN_S") % text);

func _add_line(text: String) -> void:
	if messageList.get_child_count() >= MAX_DISPLAYED:
		messageList.get_child(0).queue_free();
	var lbl: Label = Label.new();
	lbl.text = text;
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	lbl.set_meta("time_left", MESSAGE_LIFETIME)
	messageList.add_child(lbl);
	await get_tree().process_frame;
	scrollContainer.scroll_vertical = scrollContainer.get_v_scroll_bar().max_value;
