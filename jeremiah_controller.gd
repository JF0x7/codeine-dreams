extends CharacterBody3D
class_name JeremiahController

@onready var anims: AnimationManager = $JeremiahUnity/Skeleton3D/Mesh_0/AnimationPlayer
@onready var camera_pivot: CameraPivot = get_node("../CameraPivot")

const SPEED := 5.0
const ACCEL := 15.0
const DECEL := 18.0
const ROT_SPEED := 12.0
const JUMP_FORCE := 6.5
const AIR_CONTROL := 0.6
const GROUND_SNAP := 0.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_moving := false
var snap := Vector3.DOWN
var was_on_floor := true
var current_speed := 0.0

func _ready():
	anims.attack_finished.connect(_on_attack_finished)
	anims.idle()

func _physics_process(delta):
	# ------------------------------------------------------------
	# INPUT
	# ------------------------------------------------------------
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)

	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	# ------------------------------------------------------------
	# MOVEMENT DIRECTION
	# ------------------------------------------------------------
	var forward := camera_pivot.get_forward_direction()
	var right := camera_pivot.get_right_direction()
	var move_dir := (right * input_vec.x + forward * input_vec.y)
	
	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
	
	var is_moving_input := move_dir.length() > 0.1

	# ------------------------------------------------------------
	# ATTACK
	# ------------------------------------------------------------
	if Input.is_action_just_pressed("attack") and not anims.is_attacking() and is_on_floor():
		anims.attack()
		return

	# ------------------------------------------------------------
	# JUMP
	# ------------------------------------------------------------
	if Input.is_action_just_pressed("jump") and is_on_floor() and not anims.is_attacking():
		velocity.y = JUMP_FORCE
		anims.jump()
		snap = Vector3.ZERO

	# ------------------------------------------------------------
	# MOVEMENT
	# ------------------------------------------------------------
	if not anims.is_attacking():
		if is_moving_input:
			# Calculate target velocity
			var target_velocity := move_dir * SPEED
			
			# Different acceleration based on whether on ground or in air
			var acceleration := ACCEL if is_on_floor() else ACCEL * AIR_CONTROL
			
			# Smoothly accelerate toward target
			velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
			velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)

			# Smooth rotation
			var target_rot := atan2(move_dir.x, move_dir.z)
			var rotation_speed := ROT_SPEED * (1.5 if is_on_floor() else 0.8)
			rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)

			# Animation selection
			if is_on_floor():
				if move_dir.dot(forward) < -0.3:
					anims.backwards()
				else:
					anims.walk()

			is_moving = true
			current_speed = velocity.length()
			
		else:
			# Decelerate to stop
			var deceleration := DECEL if is_on_floor() else DECEL * 0.5
			velocity.x = move_toward(velocity.x, 0, deceleration * delta)
			velocity.z = move_toward(velocity.z, 0, deceleration * delta)

			# Only play idle if on ground and not jumping
			if is_moving and is_on_floor() and anims.current_anim != AnimationManager.ANIM_JUMP:
				anims.idle()
				is_moving = false
				current_speed = 0.0

	# ------------------------------------------------------------
	# GRAVITY & GROUND HANDLING
	# ------------------------------------------------------------
	was_on_floor = is_on_floor()
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		snap = Vector3.ZERO
		velocity.y = max(velocity.y, -20.0)
	else:
		if velocity.y < 0:
			velocity.y = -0.01
		
		snap = Vector3.DOWN * GROUND_SNAP

		# Landing transition from jump
		if not was_on_floor and anims.is_playing_anim(AnimationManager.ANIM_JUMP) and not anims.is_attacking():
			if is_moving_input:
				anims.walk()
			else:
				anims.idle()
		
		# Ensure animations keep playing if moving
		elif is_moving_input and not anims.is_attacking() and is_on_floor():
			if anims.current_anim == AnimationManager.ANIM_IDLE:
				if move_dir.dot(forward) < -0.3:
					anims.backwards()
				else:
					anims.walk()

	# ------------------------------------------------------------
	# APPLY MOVEMENT
	# ------------------------------------------------------------
	move_and_slide()

	# Fix floating issue
	if is_on_floor() and velocity.y >= 0:
		velocity.y = -0.01

func _on_attack_finished():
	var moving := (
		Input.get_action_strength("move_forward") > 0.1 or
		Input.get_action_strength("move_back") > 0.1 or
		Input.get_action_strength("move_left") > 0.1 or
		Input.get_action_strength("move_right") > 0.1
	)

	if moving:
		anims.walk()
	else:
		anims.idle()

# Extra features
func get_speed_ratio() -> float:
	return clamp(current_speed / SPEED, 0.0, 1.0)

func is_character_moving() -> bool:
	return is_moving

func force_stop():
	velocity = Vector3.ZERO
	is_moving = false
	current_speed = 0.0
	anims.idle()
