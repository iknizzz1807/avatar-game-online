extends Node2D
class_name RemotePlayer

const FISHING_LINE_DRAWER_SCRIPT := preload("res://scripts/client/shared/fishing_line_drawer.gd")

@export var display_name_text: String = "":
	set(v):
		display_name_text = v
		if is_node_ready() and _name_label:
			_name_label.text = v

@export var peer_id: int = -1
@export var user_id: int = -1

var sync_position:   Vector2 = Vector2.ZERO
var sync_anim_state: String  = "Idle"
var sync_facing:     Vector2 = Vector2(0.0, 1.0)
var sync_flip_h:     bool    = false

var _fishing_line_key: String = ""

const INTERP_SPEED: float = 20.0

@onready var _sprite:    Sprite2D      = $Sprite2D
@onready var _anim_tree: AnimationTree = $AnimationTree
@onready var _name_label: Label        = $NameLabel
@onready var _context_target: Node = $ContextTarget


const PET_SCENE: PackedScene = preload("res://prefabs/characters/pet.tscn")

func _ready() -> void:
	var pet = PET_SCENE.instantiate()
	pet.follow_target = self
	pet.top_level = true
	add_child(pet)
	pet.global_position = sync_position
	
	global_position = sync_position
	if _name_label:
		_name_label.text = display_name_text
	configure_context_menu(user_id, display_name_text)
	_fishing_line_key = "remote:%s" % get_instance_id()


func configure_context_menu(target_user_id: int, target_name: String) -> void:
	if not is_node_ready() or _context_target == null:
		return
	_context_target.set("playerId", target_user_id)
	_context_target.set("playerName", target_name)


func _physics_process(delta: float) -> void:
	# Smooth position interpolation or teleport if distance is large
	if global_position.distance_to(sync_position) > 200.0:
		global_position = sync_position
	else:
		global_position = global_position.lerp(sync_position, INTERP_SPEED * delta)

	var playback: AnimationNodeStateMachinePlayback = \
		_anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback:
		var display_state := "Idle" if sync_anim_state == "Fishing" else sync_anim_state
		playback.travel(display_state)
		_anim_tree.set("parameters/Idle/blend_position", sync_facing)
		_anim_tree.set("parameters/Run/blend_position",  sync_facing)
		_anim_tree.set("parameters/useWater/blend_position", sync_facing)

	_sprite.flip_h = sync_flip_h
	_update_fishing_line(sync_anim_state == "Fishing", sync_facing, sync_flip_h)


func _exit_tree() -> void:
	_clear_fishing_line()


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
