extends ContextMenuTarget
class_name OtherPlayer

# ═════════════════════════════════════════════════════════════════════════════
# OTHER PLAYER
# Extends ContextMenuTarget, which provides all right-click / context menu
# wiring. This class only declares WHAT social actions are available and
# HOW to react to them.
#
# HOW TO ADD A NEW ACTION
# ───────────────────────
# 1. Add a dict to _build_actions().
# 2. Add a matching branch in _on_context_action().
# Done — no changes needed anywhere else.
# ═════════════════════════════════════════════════════════════════════════════

@export var playerName: String = "Unknown"
@export var playerId: int = -1

# ─── CONTEXT MENU — ContextMenuTarget interface ───────────────────────────────

func _build_actions() -> Array:
	return [
		{ "id": "view_profile", "label": "👤 Xem trang cá nhân" },
		{ "id": "trade",        "label": "🤝 Trao đổi vật phẩm" },
		{ "id": "whisper",      "label": "💬 Nhắn riêng" },
		# ── Add future social actions below ──
		# { "id": "invite_farm",  "label": "🌾 Mời đến nông trại" },
		# { "id": "report",       "label": "🚩 Báo cáo" },
	]

func _on_context_action(actionId: String, target: Object) -> void:
	if target != self:
		return
	match actionId:
		"view_profile":
			print("[OtherPlayer] View profile: %s (id=%d)" % [playerName, playerId])
			# TODO [SERVER SYNC]: NetworkManager.send_view_profile_request(playerId)
		"trade":
			print("[OtherPlayer] Trade request to: %s (id=%d)" % [playerName, playerId])
			# TODO [SERVER SYNC]: NetworkManager.send_trade_request(playerId)
		"whisper":
			print("[OtherPlayer] Whisper to: %s (id=%d)" % [playerName, playerId])
			# TODO [CHAT]: Open whisper panel targeting playerId
		_:
			print("[OtherPlayer] Unknown action: %s" % actionId)
