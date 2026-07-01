extends Node

signal friends_updated(friends: Array)

const POLL_SECONDS: float = 30.0

var _poll_timer: Timer = null
var _prompted_request_ids: Dictionary = {}
var _pending_prompt_request_id: int = -1
var _pending_prompt_dialog: ConfirmationDialog = null


func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_SECONDS
	_poll_timer.timeout.connect(_poll_friend_requests)
	add_child(_poll_timer)
	_poll_timer.start()


func send_friend_request(target_user_id: int, target_name: String = "") -> void:
	if not ApiClient.has_auth_token():
		ToastManager.show_toast("Login to send friend requests.", ToastManager.Type.WARNING)
		return
	var response: Dictionary = await ApiClient.request_json(
		"/api/friends/request",
		HTTPClient.METHOD_POST,
		{ "target_user_id": target_user_id }
	)
	if not response.get("ok", false):
		ToastManager.show_toast("Failed to send friend request.", ToastManager.Type.WARNING)
		return
	var data: Dictionary = ApiClient.response_data(response)
	var request: Dictionary = data.get("request", {})
	var status: String = str(request.get("status", "pending"))
	if status == "accepted":
		ToastManager.show_toast("Friend request accepted.", ToastManager.Type.SUCCESS)
	else:
		var name: String = target_name
		if name.is_empty():
			name = str(request.get("target_name", "nguoi choi"))
		ToastManager.show_toast("Friend request sent to " + name + ".")
		
		var server_node = get_tree().root.get_node_or_null("ServerScene")
		if server_node and MultiplayerManager.multiplayer.has_multiplayer_peer():
			server_node.send_friend_request_notification.rpc_id(1, target_user_id, request)


func accept_request(request_id: int) -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/friends/%d/accept" % request_id,
		HTTPClient.METHOD_POST
	)
	if response.get("ok", false):
		ToastManager.show_toast("Friend request accepted.", ToastManager.Type.SUCCESS)
		load_friends()
	else:
		ToastManager.show_toast("Failed to accept friend request.", ToastManager.Type.WARNING)


func decline_request(request_id: int) -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/friends/%d/decline" % request_id,
		HTTPClient.METHOD_POST
	)
	if response.get("ok", false):
		ToastManager.show_toast("Friend request declined.", ToastManager.Type.SUCCESS)
	else:
		ToastManager.show_toast("Failed to decline friend request.", ToastManager.Type.WARNING)


func remove_friend(friend_id: int) -> void:
	var response: Dictionary = await ApiClient.request_json(
		"/api/friends/%d" % friend_id,
		HTTPClient.METHOD_DELETE
	)
	if response.get("ok", false):
		ToastManager.show_toast("Friend removed.", ToastManager.Type.SUCCESS)
		load_friends()
	else:
		ToastManager.show_toast("Failed to remove friend.", ToastManager.Type.WARNING)


func load_friends() -> void:
	var response: Dictionary = await ApiClient.request_json("/api/friends")
	if not response.get("ok", false):
		return
	var friends: Array = ApiClient.response_data(response).get("friends", [])
	friends_updated.emit(friends)


func _poll_friend_requests() -> void:
	if not ApiClient.has_auth_token():
		return
	var response: Dictionary = await ApiClient.request_json("/api/friends/requests")
	if not response.get("ok", false):
		return
	var requests: Array = ApiClient.response_data(response).get("requests", [])
	for request in requests:
		if request is Dictionary:
			_prompt_friend_request(request)


func _prompt_friend_request(request: Dictionary) -> void:
	var request_id: int = int(request.get("id", -1))
	if request_id <= 0 or _prompted_request_ids.has(request_id):
		return
	_prompted_request_ids[request_id] = true

	_pending_prompt_request_id = request_id
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	_pending_prompt_dialog = dialog
	dialog.title = "Friend Request"
	dialog.dialog_text = "%s wants to be your friend." % request.get("requester_name", "Player")
	dialog.confirmed.connect(_on_friend_prompt_confirmed)
	dialog.canceled.connect(_on_friend_prompt_canceled)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


func _on_friend_prompt_confirmed() -> void:
	if _pending_prompt_request_id > 0:
		accept_request(_pending_prompt_request_id)
	_cleanup_friend_prompt()


func _on_friend_prompt_canceled() -> void:
	if _pending_prompt_request_id > 0:
		decline_request(_pending_prompt_request_id)
	_cleanup_friend_prompt()


func _cleanup_friend_prompt() -> void:
	if _pending_prompt_dialog != null:
		_pending_prompt_dialog.queue_free()
	_pending_prompt_dialog = null
	_pending_prompt_request_id = -1


func handle_rpc_friend_request(request_data: Dictionary) -> void:
	_prompt_friend_request(request_data)
