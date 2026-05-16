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
# STATE MACHINE
# ═════════════════════════════════════════════════════════════════════════════

enum State {
	NORMAL,
}

var stateMachine: StateMachine;

@onready var animationTree: AnimationTree = $AnimationTree;
@onready var sprite: Sprite2D = $Sprite2D;
@onready var normalState: PlayerNormalState = $States/Normal;

func _ready() -> void:
	stateMachine = StateMachine.new(self);
	stateMachine.state_to_state_name = func(s: int) -> String: return State.keys()[s];

	stateMachine.add_states(State.NORMAL, normalState);
	stateMachine.set_initial_state(State.NORMAL);


func _process(delta: float) -> void:
	stateMachine.update(delta);


func _physics_process(delta: float) -> void:
	stateMachine.physics_update(delta);
