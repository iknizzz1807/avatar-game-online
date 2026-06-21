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
	USE_WATER,
	FISHING,
}

var stateMachine: StateMachine;

@onready var animationTree: AnimationTree = $AnimationTree;
@onready var sprite: Sprite2D = $Sprite2D;
@onready var normalState: PlayerNormalState = $States/Normal;
@onready var useWaterState: StateNode = $States/UseWater;
@onready var fishingState: StateNode = $States/Fishing;
@onready var camera: Camera2D = $Camera2D;
@onready var waterDetector: Area2D = $WaterDetector;

## True when the player is overlapping at least one FarmSlot Area2D.
var near_farm_slot: bool:
	get:
		for body in waterDetector.get_overlapping_areas():
			if body.is_in_group("farm_slots"):
				return true
		return false

## The farm slot that triggered the current USE_WATER action.
## Set by request_water(); cleared by PlayerUseWaterState after the animation.
var _pending_water_slot: Node = null

@onready var pet_spawn: Marker2D = $PetSpawner

const PET_SCENE: PackedScene = preload("res://prefabs/characters/pet.tscn")

func _ready() -> void:
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(multiplayer.get_unique_id())
		
	var pet : Node2D = PET_SCENE.instantiate()
	pet.follow_target = self
	pet.top_level = true
	add_child(pet)
	pet.global_position = pet_spawn.global_position;
	
	stateMachine = StateMachine.new(self);
	stateMachine.state_to_state_name = func(s: int) -> String: return State.keys()[s];

	stateMachine.add_states(State.NORMAL, normalState);
	stateMachine.add_states(State.USE_WATER, useWaterState);
	stateMachine.add_states(State.FISHING, fishingState);
	stateMachine.set_initial_state(State.NORMAL);

	# Enable the camera only for the local (authority) player.
	# Remote players must NOT have an active camera.
	camera.enabled = is_multiplayer_authority()

	# Tag the local-authority player so FarmSlot can find it via get_overlapping_bodies().
	if is_multiplayer_authority():
		add_to_group("local_player")


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
	# Keep sync vars up to date locally
	sync_position = global_position;
	
	# Send our state to the server if connected
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		var server_node = get_tree().root.get_node_or_null("ServerScene")
		if server_node:
			server_node.sync_player_state.rpc_id(1, sync_position, sync_anim_state, sync_facing, sync_flip_h)


# ─── Farming ─────────────────────────────────────────────────────────────────

## Called by FarmSlot when the player left-clicks or context-menus "water" on it.
## Stores the target slot and begins the USE_WATER animation state.
## Safe to call only while in NORMAL state and near the slot.
func request_water(slot: Node) -> void:
	if stateMachine.currentState != State.NORMAL:
		ToastManager.show_toast("Không thể tưới ngay lúc này.", ToastManager.Type.WARNING)
		return
	_pending_water_slot = slot
	stateMachine.change_state(State.USE_WATER, { "facing": normalState.lastFacingDir })


func start_fishing(facing: Vector2 = Vector2.DOWN) -> void:
	if stateMachine.currentState == State.FISHING:
		return
	stateMachine.change_state(State.FISHING, { "facing": facing })


func stop_fishing() -> void:
	if stateMachine.currentState == State.FISHING:
		stateMachine.change_state(State.NORMAL)
