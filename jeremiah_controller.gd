extends CharacterBody3D

@onready var anim_player: AnimationPlayer = get_node_or_null("JeremiahCon/Jeremiah/Skeleton3D/AnimationPlayer")
@onready var cam: Camera3D = $Camera3D

const SPEED := 4.0
const ACCEL := 10.0
const DECEL := 12.0
const ROT_SPEED := 8.0

var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	if anim_player == null:
		push_warning("AnimationPlayer not found at path: JeremiahCon/Jeremiah/Skeleton3D/AnimationPlayer")

func _physics_process(delta):
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

	var move_dir := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()

	# Movement
	if move_dir.length() > 0.1:
		velocity.x = lerp(velocity.x, move_dir.x * SPEED, ACCEL * delta)
		velocity.z = lerp(velocity.z, move_dir.z * SPEED, ACCEL * delta)

		# Smooth rotation
		var target_rot := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, ROT_SPEED * delta)

		if anim_player:
			anim_player.play("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0, DECEL * delta)

		if anim_player:
			anim_player.play("Idle")

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	move_and_slide()
