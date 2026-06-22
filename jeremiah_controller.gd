extends CharacterBody3D

@onready var anim_player: AnimationPlayer = $JeremiahUnity/Skeleton3D/Mesh_0/AnimationPlayer
@onready var cam: Camera3D = get_node_or_null("../Camera3D")

const SPEED := 4.0
const ACCEL := 10.0
const DECEL := 12.0
const ROT_SPEED := 8.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_moving: bool = false
var snap := Vector3.DOWN

func _ready():
	if anim_player:
		print("Available animations:", anim_player.get_animation_list())
		if anim_player.has_animation("Idle"):
			anim_player.play("Idle")

func _physics_process(delta):
	# INPUT VECTOR
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	# CAMERA-RELATIVE MOVEMENT
	var move_dir := Vector3.ZERO
	if cam:
		var forward := -cam.global_transform.basis.z
		var right := cam.global_transform.basis.x
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		move_dir = (right * input_vec.x + forward * input_vec.y).normalized()
	else:
		move_dir = Vector3(input_vec.x, 0, input_vec.y).normalized()

	# MOVEMENT + ANIMATION
	if move_dir.length() > 0.1:
		velocity.x = lerp(velocity.x, move_dir.x * SPEED, ACCEL * delta)
		velocity.z = lerp(velocity.z, move_dir.z * SPEED, ACCEL * delta)

		var target_rot := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, ROT_SPEED * delta)

		# Walking animation
		if anim_player and not is_moving:
			var walk_anim = find_animation(["Walking", "Walk", "Run", "moving", "Move"])
			if walk_anim != "":
				anim_player.play(walk_anim)
				is_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0, DECEL * delta)

		# Idle animation
		if anim_player and is_moving:
			var idle_anim = find_animation(["Idle", "idle", "Stand", "stand", "Rest"])
			if idle_anim != "":
				anim_player.play(idle_anim)
				is_moving = false

	# GRAVITY AND GROUND SNAP - FIXES HOVERING
	if not is_on_floor():
		velocity.y -= gravity * delta
		snap = Vector3.ZERO
	else:
		velocity.y = 0
		snap = Vector3.DOWN  # Snaps character to ground

	# Small downward force to prevent floating
	if is_on_floor() and velocity.y >= 0:
		velocity.y = -0.01

	move_and_slide()

func find_animation(possible_names: Array) -> String:
	if not anim_player:
		return ""
	
	for name in possible_names:
		if anim_player.has_animation(name):
			return name
	
	var all_anims = anim_player.get_animation_list()
	for possible in possible_names:
		for anim in all_anims:
			if possible.to_lower() in anim.to_lower():
				return anim
	
	return ""
