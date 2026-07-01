extends CharacterBody2D
class_name Player

const FISHING_LINE_DRAWER_SCRIPT := preload("res://scripts/client/shared/fishing_line_drawer.gd")

@export_group("Movement")
@export var MAX_SPEED: float = 200.0;
@export var ACCELERATION: float = 1200.0;
@export var DECELERATION: float = 1600.0;

var sync_position:   Vector2 = Vector2.ZERO
var sync_anim_state: String  = "Idle"
var sync_facing:     Vector2 = Vector2(0.0, 1.0)
var sync_flip_h:     bool    = false

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

var _fishing_line_key: String = ""

var near_farm_slot: bool:
	get:
		for body in waterDetector.get_overlapping_areas():
			if body.is_in_group("farm_slots"):
				return true
		return false

var _pending_water_slot: Node = null

@onready var pet_spawn: Marker2D = $PetSpawner

const PET_SCENE: PackedScene = preload("res://prefabs/characters/pet.tscn")

func _ready() -> void:
	if _has_active_multiplayer_peer():
		set_multiplayer_authority(multiplayer.get_unique_id())
		
	stateMachine = StateMachine.new(self);
	stateMachine.state_to_state_name = func(s: int) -> String: return State.keys()[s];

	stateMachine.add_states(State.NORMAL, normalState);
	stateMachine.add_states(State.USE_WATER, useWaterState);
	stateMachine.add_states(State.FISHING, fishingState);
	stateMachine.set_initial_state(State.NORMAL);

	camera.enabled = is_local_authority()

	if is_local_authority():
		add_to_group("local_player")
		
		var hud_node = get_node_or_null("CanvasLayer/HUD")
		if hud_node:
			hud_node.visible = true

		if TeleportData.spawn_position != Vector2.ZERO:
			global_position = TeleportData.spawn_position
			TeleportData.spawn_position = Vector2.ZERO
		else:
			var path := MultiplayerManager.get_profile_save_path()
			var config := ConfigFile.new()
			var err := config.load(path)
			if err == OK:
				var saved_scene = config.get_value("position", "scene", "")
				if saved_scene == MultiplayerManager.local_scene_name:
					var x = config.get_value("position", "x", 0.0)
					var y = config.get_value("position", "y", 0.0)
					if x != 0.0 or y != 0.0:
						global_position = Vector2(x, y)

	var pet : Node2D = PET_SCENE.instantiate()
	pet.follow_target = self
	pet.top_level = true
	add_child(pet)
	force_update_transform()
	pet.global_position = pet_spawn.global_position;
	_fishing_line_key = "local:%s" % get_instance_id()


func _process(delta: float) -> void:
	if not is_local_authority():
		return;
	stateMachine.update(delta);


func _physics_process(delta: float) -> void:
	if not is_local_authority():
		return;
	stateMachine.physics_update(delta);
	_update_fishing_line(sync_anim_state == "Fishing", sync_facing, sync_flip_h)
	sync_position = global_position;
	if _has_active_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		var server_node = get_tree().root.get_node_or_null("ServerScene")
		if server_node and MultiplayerManager:
			server_node.sync_player_state.rpc_id(1, MultiplayerManager.local_map_id, sync_position, sync_anim_state, sync_facing, sync_flip_h)

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
		_update_fishing_line(false, sync_facing, sync_flip_h)


func _exit_tree() -> void:
	_clear_fishing_line()


func is_local_authority() -> bool:
	return not _has_active_multiplayer_peer() or is_multiplayer_authority()


func _has_active_multiplayer_peer() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _update_fishing_line(active: bool, facing: Vector2, flip_h: bool) -> void:
	if not active:
		_clear_fishing_line()
		return
	var drawer := _get_fishing_line_drawer()

	var dir := _fishing_direction(facing, flip_h)
	var rod_tip := global_position + Vector2(0, -8) + dir * 13.0
	var bobber := global_position + Vector2(0, -8) + dir * 58.0 + Vector2(0, 10)
	var distance := rod_tip.distance_to(bobber)
	var sag := clampf(distance * 0.25, 4.0, 30.0)
	drawer.update_line_points(_fishing_line_key, _generate_fishing_line_points(rod_tip, bobber, 20, sag))


func _fishing_direction(facing: Vector2, flip_h: bool) -> Vector2:
	var x := -absf(facing.x) if flip_h else absf(facing.x)
	var dir := Vector2(x, facing.y)
	if dir.length() < 0.1:
		return Vector2.DOWN
	return dir.normalized()


func _generate_fishing_line_points(start: Vector2, end: Vector2, segments: int, sag: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments = maxi(segments, 1)
	for i in range(safe_segments + 1):
		var t := float(i) / float(safe_segments)
		var base_point := start.lerp(end, t)
		# 4t(1-t) is 0 at both ends and peaks at 1 in the middle.
		var parabola_factor := 4.0 * t * (1.0 - t)
		points.append(base_point + Vector2(0, sag * parabola_factor))
	return points


func _get_fishing_line_drawer() -> FishingLineDrawer:
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var drawer := root.get_node_or_null("FishingLineDrawer") as FishingLineDrawer
	if drawer == null:
		drawer = FISHING_LINE_DRAWER_SCRIPT.new() as FishingLineDrawer
		drawer.name = "FishingLineDrawer"
		drawer.z_index = 200
		root.add_child(drawer)
	return drawer


func _clear_fishing_line() -> void:
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var drawer := root.get_node_or_null("FishingLineDrawer") as FishingLineDrawer
	if drawer:
		drawer.clear_line(_fishing_line_key)
