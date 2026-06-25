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

const GAME_SCENE: String = "res://scenes/game.tscn"

# ─── Nodes ────────────────────────────────────────────────────────────────────
@onready var _login_panel: Control  = $Login
@onready var _signup_panel: Control = $SignUp
@onready var _menu_panel: Panel = $Panel
@onready var _menu_login_btn: Button = $Panel/VBoxContainer/Login
@onready var _menu_register_btn: Button = $Panel/VBoxContainer/Register
@onready var _menu_guest_btn: Button = $Panel/VBoxContainer/Guest

# Login panel
@onready var _login_form: Control = $Login/VBoxContainer
@onready var _login_user:       LineEdit = $Login/VBoxContainer/GridContainer/TextEdit
@onready var _login_pass:       LineEdit = $Login/VBoxContainer/GridContainer/TextEdit2
@onready var _login_btn:        Button   = $Login/VBoxContainer/Button
@onready var _login_back_btn:   Button   = $Login/VBoxContainer/Button2

# Sign-up panel
@onready var _signup_form: Control = $SignUp/VBoxContainer
@onready var _signup_user:      LineEdit = $SignUp/VBoxContainer/GridContainer/TextEdit
@onready var _signup_pass:      LineEdit = $SignUp/VBoxContainer/GridContainer/TextEdit2
@onready var _signup_btn:       Button   = $SignUp/VBoxContainer/Button
@onready var _signup_back_btn:  Button   = $SignUp/VBoxContainer/Button2

@onready var _http: HTTPRequest = $HTTPRequest


func _ready() -> void:
	_login_pass.secret = true
	_signup_pass.secret = true

	_menu_login_btn.pressed.connect(_show_login)
	_menu_register_btn.pressed.connect(_show_signup)
	_menu_guest_btn.pressed.connect(_on_skip_login_pressed)
	_login_btn.pressed.connect(_on_login_pressed)
	_login_back_btn.pressed.connect(_show_menu)
	_signup_btn.pressed.connect(_on_signup_pressed)
	_signup_back_btn.pressed.connect(_show_menu)
	_show_menu()

	# If this is the dedicated server, hide the auth UI to avoid confusion!
	if "--server" in OS.get_cmdline_args():
		_set_branch_visible(_menu_panel, false)
		_set_branch_visible(_login_panel, false)
		_set_branch_visible(_signup_panel, false)
		var label = Label.new()
		label.text = "DEDICATED SERVER\n(Do not login here)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(label)


# ─── Panel toggle helpers ─────────────────────────────────────────────────────

func _show_menu() -> void:
	_set_branch_visible(_menu_panel, true)
	_set_branch_visible(_login_panel, false)
	_set_branch_visible(_signup_panel, false)


func _show_signup() -> void:
	_set_branch_visible(_menu_panel, false)
	_set_branch_visible(_login_panel, false)
	_set_branch_visible(_signup_panel, true)
	_signup_user.text = ""
	_signup_pass.text = ""
	_signup_user.grab_focus()


func _show_login() -> void:
	_set_branch_visible(_menu_panel, false)
	_set_branch_visible(_signup_panel, false)
	_set_branch_visible(_login_panel, true)
	_login_user.grab_focus()


func _set_branch_visible(node: Node, visible: bool) -> void:
	if node is CanvasItem:
		node.visible = visible
	for child in node.get_children():
		_set_branch_visible(child, visible)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _login_panel.visible and not _login_form.get_global_rect().has_point(event.position):
		_show_menu()
	elif _signup_panel.visible and not _signup_form.get_global_rect().has_point(event.position):
		_show_menu()


# ─── Button handlers ──────────────────────────────────────────────────────────

func _on_login_pressed() -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/auth/login",
		HTTPClient.METHOD_POST,
		{ "username": _login_user.text.strip_edges(), "password": _login_pass.text }
	)
	_handle_auth_response(response)

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
	var username := _signup_user.text.strip_edges()
	var response: Dictionary = await ApiClient.request_json(
		"/api/auth/register",
		HTTPClient.METHOD_POST,
		{ "username": username, "password": _signup_pass.text, "display_name": username }
	)
	_handle_auth_response(response)


func _handle_auth_response(response: Dictionary) -> void:
	if not response.get("ok", false):
		push_error("[Auth] Server error %d: %s" % [response.get("code", 0), response.get("error", "unknown")])
		return
	_on_login_success(response.get("body", {}))


func _on_login_success(data: Dictionary) -> void:
	# Go server returns: { token, user: { id, username, display_name, current_map, ... } }
	var token: String       = data.get("token", "")
	var user: Dictionary    = data.get("user", {})
	var user_id: int        = int(user.get("id", -1))
	var display_name: String = user.get("display_name", user.get("username", "Player"))
	
	var map_id: String      = user.get("current_map", "game")

	print("[Auth] Logged in as %s (id=%d)" % [display_name, user_id])

	# Store info in the multiplayer manager
	ApiClient.set_auth_token(token)
	MultiplayerManager.set_auth_token(token)
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
