extends Node

signal coins_changed(amount: int)

const API_BASE: String = "http://127.0.0.1:8080"

var auth_token: String = ""
var current_coins: int = 0


func set_auth_token(token: String) -> void:
	auth_token = token


func clear_auth_token() -> void:
	auth_token = ""


func has_auth_token() -> bool:
	return not auth_token.is_empty() and auth_token != "dummy_token"


func request_json(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray(["Content-Type: application/json"])
	if has_auth_token():
		headers.append("Authorization: Bearer " + auth_token)

	var payload := ""
	if method != HTTPClient.METHOD_GET and not body.is_empty():
		payload = JSON.stringify(body)

	var err := http.request(API_BASE + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return { "ok": false, "code": 0, "body": {}, "error": "request_failed" }

	var response = await http.request_completed
	http.queue_free()

	var result: int = response[0]
	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return { "ok": false, "code": response_code, "body": {}, "error": "http_error" }

	var parsed = JSON.parse_string(response_body.get_string_from_utf8())
	if not parsed is Dictionary:
		parsed = {}

	if parsed.has("coins"):
		current_coins = int(parsed.get("coins", current_coins))
		coins_changed.emit(current_coins)

	return {
		"ok": response_code >= 200 and response_code < 300,
		"code": response_code,
		"body": parsed,
		"error": parsed.get("error", "")
	}


func response_data(response: Dictionary) -> Dictionary:
	var body: Dictionary = response.get("body", {})
	return body.get("data", body)
