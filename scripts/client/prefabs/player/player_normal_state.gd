extends StateNode
class_name PlayerNormalState

var player: Player;
var lastFacingDir: Vector2 = Vector2.DOWN;

func ready_state() -> void:
	player = parent as Player;
func begin_state() -> void:
	pass;
func end_state() -> void:
	pass;
func update(_delta: float) -> void:
	pass

func fixed_update(delta: float) -> void:
	var inputDir: Vector2 = _handle_movement(delta);
	_update_animation(inputDir);
	player.move_and_slide();
	_write_sync_vars(inputDir);

func _handle_movement(delta: float) -> Vector2:
	var inputDir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down");

	if inputDir != Vector2.ZERO:
		var targetVelocity: Vector2 = inputDir.normalized() * player.MAX_SPEED;
		player.velocity = player.velocity.move_toward(targetVelocity, player.ACCELERATION * delta);
	else:
		player.velocity = player.velocity.move_toward(Vector2.ZERO, player.DECELERATION * delta);

	return inputDir;


func _update_animation(inputDir: Vector2) -> void:
	var playback: AnimationNodeStateMachinePlayback = player.animationTree["parameters/playback"];

	if inputDir != Vector2.ZERO:
		lastFacingDir = _snap_to_cardinal(inputDir.normalized());
		playback.travel("Run");
		player.animationTree["parameters/Run/blend_position"] = _mirror_blend(lastFacingDir);
	else:
		playback.travel("Idle");

	player.animationTree["parameters/Idle/blend_position"] = _mirror_blend(lastFacingDir);

	player.sprite.flip_h = lastFacingDir.x < 0.0;


func _write_sync_vars(inputDir: Vector2) -> void:
	player.sync_anim_state = "Run" if inputDir != Vector2.ZERO else "Idle";
	player.sync_facing     = _mirror_blend(lastFacingDir);
	player.sync_flip_h     = lastFacingDir.x < 0.0;

func _snap_to_cardinal(dir: Vector2) -> Vector2:
	if absf(dir.x) >= absf(dir.y):
		return Vector2(signf(dir.x), 0.0);
	else:
		return Vector2(0.0, signf(dir.y));

func _mirror_blend(dir: Vector2) -> Vector2:
	return Vector2(absf(dir.x), dir.y);
