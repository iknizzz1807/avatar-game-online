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
	sendButton.pressed.connect(_on_send_pressed);
	messageInput.text_submitted.connect(_on_text_submitted);
	messageInput.max_length = MAX_CHARS;

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
	_add_line("[Bạn]: %s" % text);

func _add_line(text: String) -> void:
	if messageList.get_child_count() >= MAX_DISPLAYED:
		messageList.get_child(0).queue_free();
	var lbl: Label = Label.new();
	lbl.text = text;
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	messageList.add_child(lbl);
	await get_tree().process_frame;
	scrollContainer.scroll_vertical = scrollContainer.get_v_scroll_bar().max_value;
