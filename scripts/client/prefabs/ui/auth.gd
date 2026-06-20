extends Control

# ═════════════════════════════════════════════════════════════════════════════
# AUTH SCREEN
#
# Handles login and sign-up against the Go REST server.
# On successful login:
#   1. Stores JWT + user info in MultiplayerManager
#   2. Connects to the Godot dedicated server
#   3. Transitions to game.tscn
# ═════════════════════════════════════════════════════════════════════════════

const API_BASE: String   = "http://127.0.0.1:8080"
const GAME_SCENE: String = "res://scenes/game.tscn"

# ─── Nodes ────────────────────────────────────────────────────────────────────
@onready var _login_panel: Control  = $Login
@onready var _signup_panel: Control = $SignUp

# Login panel
@onready var _login_user:  LineEdit = $Login/VBoxContainer/GridContainer/TextEdit
@onready var _login_pass:  LineEdit = $Login/VBoxContainer/GridContainer/TextEdit2
@onready var _login_btn:   Button   = $Login/VBoxContainer/Button
@onready var _skip_btn:    Button   = $Login/VBoxContainer/SkipButton

# Sign-up panel
@onready var _signup_user: LineEdit = $SignUp/VBoxContainer/GridContainer/TextEdit
@onready var _signup_pass: LineEdit = $SignUp/VBoxContainer/GridContainer/TextEdit2
@onready var _signup_btn:  Button   = $SignUp/VBoxContainer/Button

@onready var _http: HTTPRequest = $HTTPRequest


func _ready() -> void:
	_login_pass.secret = true
	_signup_pass.secret = true

	_login_btn.pressed.connect(_on_login_pressed)
	_signup_btn.pressed.connect(_on_signup_pressed)
	_skip_btn.pressed.connect(_on_skip_login_pressed)
	_http.request_completed.connect(_on_request_completed)

	_login_panel.visible  = true
	_signup_panel.visible = false

	# If this is the dedicated server, hide the auth UI to avoid confusion!
	if "--server" in OS.get_cmdline_args():
		_login_panel.visible = false
		_signup_panel.visible = false
		var label = Label.new()
		label.text = "DEDICATED SERVER\n(Do not login here)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(label)


# ─── Button handlers ──────────────────────────────────────────────────────────

func _on_login_pressed() -> void:
	_send_request(
		API_BASE + "/api/auth/login",
		{ "username": _login_user.text.strip_edges(), "password": _login_pass.text }
	)

func _on_skip_login_pressed() -> void:
	var random_id = randi() % 10000 + 1
	var dummy_data = {
		"token": "dummy_token",
		"user": {
			"id": random_id,
			"display_name": "TestPlayer_" + str(random_id),
			"current_map": "game"
		}
	}
	_on_login_success(dummy_data)


func _on_signup_pressed() -> void:
	_send_request(
		API_BASE + "/api/auth/register",
		{ "username": _signup_user.text.strip_edges(), "password": _signup_pass.text }
	)


func _send_request(url: String, body: Dictionary) -> void:
	var json_body: String  = JSON.stringify(body)
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json"
	])
	_http.request(url, headers, HTTPClient.METHOD_POST, json_body)


# ─── HTTP response ────────────────────────────────────────────────────────────

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[Auth] HTTP error: result=%d" % result)
		return

	var json_text: String = body.get_string_from_utf8()
	var parsed = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		push_error("[Auth] Invalid JSON response")
		return

	if response_code != 200:
		push_error("[Auth] Server error %d: %s" % [response_code, parsed.get("error", "unknown")])
		return

	_on_login_success(parsed)


func _on_login_success(data: Dictionary) -> void:
	# Go server returns: { token, user: { id, username, display_name, current_map, ... } }
	var token: String       = data.get("token", "")
	var user: Dictionary    = data.get("user", {})
	var user_id: int        = int(user.get("id", -1))
	var display_name: String = user.get("display_name", user.get("username", "Player"))
	
	var map_id: String      = user.get("current_map", "game")
	if map_id == "world" or map_id == "": # Backwards compatibility if backend returned "world"
		map_id = "game"

	print("[Auth] Logged in as %s (id=%d)" % [display_name, user_id])

	# Store info in the multiplayer manager
	MultiplayerManager.set_local_player(user_id, display_name, map_id)

	# Connect to the Godot dedicated server
	MultiplayerManager.connected_to_server.connect(_on_server_connected, CONNECT_ONE_SHOT)
	MultiplayerManager.connection_failed.connect(_on_server_connection_failed, CONNECT_ONE_SHOT)
	MultiplayerManager.connect_to_server()


func _on_server_connected() -> void:
	print("[Auth] Connected to game server — loading map: " + MultiplayerManager.local_scene_name)
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % MultiplayerManager.local_scene_name)


func _on_server_connection_failed() -> void:
	push_warning("[Auth] Could not connect to game server — loading offline.")
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % MultiplayerManager.local_scene_name)
