extends CharacterBody2D
class_name Player

# ═════════════════════════════════════════════════════════════════════════════
# TUNABLE CONSTANTS
# ALL_CAPS signals these are designer-facing constants – treat as read-only
# at runtime. Adjust them only through the Inspector or scene overrides.
# ═════════════════════════════════════════════════════════════════════════════

@export_group("Movement")
## Top movement speed in any direction (px / s)
@export var MAX_SPEED: float = 200.0;
## How fast the player reaches MAX_SPEED (px / s²)
@export var ACCELERATION: float = 1200.0;
## How fast the player comes to a stop when no input is held (px / s²)
@export var DECELERATION: float = 1600.0;

# ═════════════════════════════════════════════════════════════════════════════
# MULTIPLAYER SYNC VARS
# Written every frame by PlayerNormalState so MultiplayerSynchronizer can
# replicate them to all other peers. RemotePlayer reads these on their side.
# ═════════════════════════════════════════════════════════════════════════════

## World position broadcast to other peers (replicated by MultiplayerSynchronizer).
var sync_position:   Vector2 = Vector2.ZERO
## Current animation state ("Idle" or "Run").
var sync_anim_state: String  = "Idle"
## Blend-space facing direction (x always positive, see _mirror_blend in state).
var sync_facing:     Vector2 = Vector2(0.0, 1.0)
## Whether the sprite is flipped horizontally.
var sync_flip_h:     bool    = false

# ═════════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ═════════════════════════════════════════════════════════════════════════════

enum State {
	NORMAL,
}

var stateMachine: StateMachine;

@onready var animationTree: AnimationTree = $AnimationTree;
@onready var sprite: Sprite2D = $Sprite2D;
@onready var normalState: PlayerNormalState = $States/Normal;
@onready var camera: Camera2D = $Camera2D;


func _ready() -> void:
	stateMachine = StateMachine.new(self);
	stateMachine.state_to_state_name = func(s: int) -> String: return State.keys()[s];

	stateMachine.add_states(State.NORMAL, normalState);
	stateMachine.set_initial_state(State.NORMAL);

	# Enable the camera only for the local (authority) player.
	# Remote players must NOT have an active camera.
	camera.enabled = is_multiplayer_authority();


func _process(delta: float) -> void:
	# Only the local player (authority) drives its own state machine.
	# Non-authority instances are driven by RemotePlayer via sync vars.
	if not is_multiplayer_authority():
		return;
	stateMachine.update(delta);


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return;
	stateMachine.physics_update(delta);
	# Keep sync vars up to date so MultiplayerSynchronizer can broadcast them.
	sync_position = global_position;
