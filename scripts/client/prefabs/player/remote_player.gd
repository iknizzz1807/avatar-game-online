extends Node2D
class_name RemotePlayer

# ═════════════════════════════════════════════════════════════════════════════
# REMOTE PLAYER — Display-only node for other players in the world.
#
# Position and animation state are driven by MultiplayerSynchronizer, which
# writes directly to `sync_position`, `sync_anim_state`, `sync_facing`, and
# `sync_flip_h`. This script applies those values each frame with smooth
# interpolation for position.
#
# The owning peer ID and display name are set by PlayerRegistry when this
# node is spawned.
# ═════════════════════════════════════════════════════════════════════════════

## Set by PlayerRegistry after spawning.
@export var display_name_text: String = "":
	set(v):
		display_name_text = v
		if is_node_ready() and _name_label:
			_name_label.text = v

## Set by PlayerRegistry — used for context menu identification.
@export var peer_id: int = -1
@export var user_id: int = -1

# ─── Sync vars (written by MultiplayerSynchronizer on the owning side) ────────
var sync_position:   Vector2 = Vector2.ZERO
var sync_anim_state: String  = "Idle"    # "Idle" or "Run"
var sync_facing:     Vector2 = Vector2(0.0, 1.0)  # blend position
var sync_flip_h:     bool    = false

# ─── Interpolation ────────────────────────────────────────────────────────────
const INTERP_SPEED: float = 20.0

@onready var _sprite:    Sprite2D      = $Sprite2D
@onready var _anim_tree: AnimationTree = $AnimationTree
@onready var _name_label: Label        = $NameLabel


func _ready() -> void:
	# Initialise position immediately so we don't lerp from world origin.
	global_position = sync_position
	if _name_label:
		_name_label.text = display_name_text


func _physics_process(delta: float) -> void:
	# Smooth position interpolation
	global_position = global_position.lerp(sync_position, INTERP_SPEED * delta)

	# Apply animation state
	var playback: AnimationNodeStateMachinePlayback = \
		_anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback:
		playback.travel(sync_anim_state)
		_anim_tree.set("parameters/Idle/blend_position", sync_facing)
		_anim_tree.set("parameters/Run/blend_position",  sync_facing)

	_sprite.flip_h = sync_flip_h
