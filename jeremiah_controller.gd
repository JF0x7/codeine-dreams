extends CharacterBody3D
class_name JeremiahController

# ============================================================================
# REFERENCES
# ============================================================================
@onready var anims: AnimationManager = $JeremiahUnity/Skeleton3D/Mesh_0/AnimationPlayer
@onready var camera_pivot: CameraPivot = get_node("../CameraPivot")

# ============================================================================
# MOVEMENT SETTINGS - TWEAK THESE!
# ============================================================================
# Base movement speed (units per second)
const SPEED: float = 5.0

# How quickly the character accelerates when moving
const ACCEL: float = 15.0

# How quickly the character decelerates when stopping
const DECEL: float = 18.0

# Character rotation speed (higher = snappier turns)
const ROT_SPEED: float = 12.0

# How fast the character jumps
const JUMP_FORCE: float = 6.5

# Air control multiplier (0.0 = no control in air, 1.0 = full control)
const AIR_CONTROL: float = 0.6

# How strongly the character snaps to the ground (prevents floating)
# Increase this if character floats above ground
const GROUND_SNAP: float = 1.5

# Maximum downward velocity (prevents falling too fast)
const MAX_FALL_SPEED: float = -20.0

# Small negative velocity to keep character on ground
const GROUND_CLING: float = -0.01

# Character collision offset (adjusts where character stands relative to collision shape)
# INCREASE THIS if character is sinking into ground
# DECREASE if character is floating
@export var collision_offset: float = 0.0

# ============================================================================
# INTERNAL STATE
# ============================================================================
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_moving: bool = false
var snap: Vector3 = Vector3.DOWN
var was_on_floor: bool = true
var current_speed: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Set physics mode for better ground detection
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	
	# Connect animation signals
	anims.attack_finished.connect(_on_attack_finished)
	anims.idle()
	
	print("JeremiahController initialized - Ready for gameplay!")
	
	# Apply collision offset if the node exists
	if has_node("CollisionShape3D"):
		var collision: CollisionShape3D = get_node("CollisionShape3D")
		collision.position.y = collision_offset
		print("Character ground offset set to: ", collision_offset)
	else:
		print("Warning: CollisionShape3D not found - collision offset not applied")

# ============================================================================
# PHYSICS UPDATE (Main game loop)
# ============================================================================
func _physics_process(delta: float) -> void:
	# --------
	# INPUT
	# --------
	var input_vec: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	
	# Normalize diagonal input so it's not faster
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()
	
	# --------
	# MOVEMENT DIRECTION (Camera-relative)
	# --------
	var forward: Vector3 = camera_pivot.get_forward_direction()
	var right: Vector3 = camera_pivot.get_right_direction()
	var move_dir: Vector3 = (right * input_vec.x + forward * input_vec.y)
	
	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
	
	var is_moving_input: bool = move_dir.length() > 0.1
	
	# --------
	# ATTACK (Can't move/jump while attacking)
	# --------
	if Input.is_action_just_pressed("attack") and not anims.is_attacking() and is_on_floor():
		anims.attack()
		return  # Skip rest of movement this frame
	
	# --------
	# JUMP
	# --------
	if Input.is_action_just_pressed("jump") and is_on_floor() and not anims.is_attacking():
		velocity.y = JUMP_FORCE
		anims.jump()
		snap = Vector3.ZERO  # Disable snap while jumping
	
	# --------
	# MOVEMENT & ROTATION
	# --------
	if not anims.is_attacking():
		if is_moving_input:
			# Calculate target velocity based on move direction
			var target_velocity: Vector3 = move_dir * SPEED
			
			# Use different acceleration on ground vs air
			var acceleration: float = ACCEL if is_on_floor() else ACCEL * AIR_CONTROL
			
			# Smoothly accelerate toward target (makes movement feel fluid)
			velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
			velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)
			
			# Smoothly rotate character to face movement direction
			var target_rot: float = atan2(move_dir.x, move_dir.z)
			var rotation_speed: float = ROT_SPEED * (1.5 if is_on_floor() else 0.8)
			rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
			
			# Play appropriate animation based on movement direction
			if is_on_floor():
				if move_dir.dot(forward) < -0.3:
					anims.backwards()  # Walking backwards
				else:
					anims.walk()  # Walking forward/sideways
			
			is_moving = true
			current_speed = velocity.length()
			
		else:
			# DECELERATION - Stop the character smoothly
			var deceleration: float = DECEL if is_on_floor() else DECEL * 0.5
			velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
			
			# Play idle animation when stopped
			if is_moving and is_on_floor() and anims.current_anim != AnimationManager.ANIM_JUMP:
				anims.idle()
				is_moving = false
				current_speed = 0.0
	
	# --------
	# GRAVITY & GROUND HANDLING
	# --------
	was_on_floor = is_on_floor()
	
	if not is_on_floor():
		# Apply gravity when in the air
		velocity.y -= gravity * delta
		snap = Vector3.ZERO  # Disable snap while airborne
		
		# Clamp fall speed (prevents falling infinitely fast)
		velocity.y = max(velocity.y, MAX_FALL_SPEED)
	else:
		# On ground - stop downward velocity
		if velocity.y < 0:
			velocity.y = GROUND_CLING
		
		# Enable ground snap for better ground detection
		snap = Vector3.DOWN * GROUND_SNAP
		
		# Handle landing animation transition
		if not was_on_floor and anims.is_playing_anim(AnimationManager.ANIM_JUMP) and not anims.is_attacking():
			if is_moving_input:
				anims.walk()
			else:
				anims.idle()
		
		# Keep animations playing smoothly
		elif is_moving_input and not anims.is_attacking() and is_on_floor():
			if anims.current_anim == AnimationManager.ANIM_IDLE:
				if move_dir.dot(forward) < -0.3:
					anims.backwards()
				else:
					anims.walk()
	
	# --------
	# APPLY MOVEMENT TO PHYSICS ENGINE
	# --------
	move_and_slide()
	
	# Extra safety: Keep character grounded
	if is_on_floor() and velocity.y >= 0:
		velocity.y = GROUND_CLING

# ============================================================================
# ATTACK FINISHED CALLBACK
# ============================================================================
func _on_attack_finished() -> void:
	# When attack animation finishes, play walk or idle based on current input
	var moving: bool = (
		Input.get_action_strength("move_forward") > 0.1 or
		Input.get_action_strength("move_back") > 0.1 or
		Input.get_action_strength("move_left") > 0.1 or
		Input.get_action_strength("move_right") > 0.1
	)
	
	if moving:
		anims.walk()
	else:
		anims.idle()

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Get current movement speed as a ratio (0.0 to 1.0)
func get_speed_ratio() -> float:
	return clamp(current_speed / SPEED, 0.0, 1.0)

# Check if character is currently moving
func is_character_moving() -> bool:
	return is_moving

# Instantly stop all movement (useful for cutscenes)
func force_stop() -> void:
	velocity = Vector3.ZERO
	is_moving = false
	current_speed = 0.0
	anims.idle()
	print("Character forced to stop")

# Get current velocity magnitude
func get_current_velocity() -> float:
	return velocity.length()

# Check if character is in the air
func is_airborne() -> bool:
	return not is_on_floor()

# Adjust character position on ground
func set_ground_offset(offset: float) -> void:
	"""
	Adjust how high/low character stands relative to ground.
	Positive = higher above ground, Negative = lower/sinking
	"""
	collision_offset = offset
	if has_node("CollisionShape3D"):
		var collision: CollisionShape3D = get_node("CollisionShape3D")
		collision.position.y = collision_offset
		print("Character ground offset adjusted to: ", offset)
