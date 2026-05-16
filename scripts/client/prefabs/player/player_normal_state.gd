extends StateNode
class_name PlayerNormalState

# ─── Typed reference to the parent Player node ───────────────────────────────
var player: Player;

# ─── Last non-zero input direction used to keep facing when idle ──────────────
var lastFacingDir: Vector2 = Vector2.DOWN;

# ─────────────────────────────────────────────────────────────────────────────

func ready_state() -> void:
	player = parent as Player;


func begin_state() -> void:
	pass ;


func end_state() -> void:
	pass ;


# ─── Process (non-physics) ───────────────────────────────────────────────────

func update(_delta: float) -> void:
	pass ;


# ─── Physics update ──────────────────────────────────────────────────────────

func fixed_update(delta: float) -> void:
	var inputDir: Vector2 = _handle_movement(delta);
	_update_animation(inputDir);
	player.move_and_slide();


# ─── Private helpers ─────────────────────────────────────────────────────────

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

	# Always keep Idle blend position synced so the transition is seamless
	player.animationTree["parameters/Idle/blend_position"] = _mirror_blend(lastFacingDir);

	# Flip based on the snapped cardinal — never on a raw diagonal
	print(lastFacingDir);
	player.sprite.flip_h = lastFacingDir.x < 0.0;


	# Pick whichever axis is dominant and snap to a unit cardinal vector
func _snap_to_cardinal(dir: Vector2) -> Vector2:
	if absf(dir.x) >= absf(dir.y):
		return Vector2(signf(dir.x), 0.0);
	else:
		return Vector2(0.0, signf(dir.y));


# Strip the sign from X so we always sample the right-facing side of the BlendSpace
func _mirror_blend(dir: Vector2) -> Vector2:
	return Vector2(absf(dir.x), dir.y);
