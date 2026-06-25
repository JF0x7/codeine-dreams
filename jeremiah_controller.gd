# ============================================================
# CHARACTER CONTROLLER - GODOT 4
# A complete 3D character controller with:
# - Camera-relative movement
# - Smooth acceleration/deceleration
# - Animation state management
# - Ground snapping to prevent hovering
# ============================================================

# Extends CharacterBody3D - this gives us built-in physics properties
# like velocity, is_on_floor(), and move_and_slide()
extends CharacterBody3D

# ============================================================
# NODE REFERENCES (onready = loads when the scene enters the tree)
# ============================================================

# Gets the AnimationPlayer node using the path from this node
# The $ is shorthand for get_node() - it searches relative to this script's node
# Path: This node -> JeremiahUnity -> Skeleton3D -> Mesh_0 -> AnimationPlayer
@onready var anim_player: AnimationPlayer = $JeremiahUnity/Skeleton3D/Mesh_0/AnimationPlayer

# Gets the Camera3D node using get_node_or_null()
# The ".." means "go up one level" from this node
# get_node_or_null() returns null if not found instead of crashing
# This is safer than using $ which would error if the camera doesn't exist
@onready var cam: Camera3D = get_node_or_null("../Camera3D")

# ============================================================
# MOVEMENT CONSTANTS
# ============================================================

# Maximum walking speed in units per second
const SPEED := 4.0

# How quickly we accelerate to full speed (higher = faster acceleration)
# The value 10.0 means we reach full speed in about 0.1 seconds
const ACCEL := 10.0

# How quickly we decelerate to a stop (higher = faster stopping)
const DECEL := 12.0

# How quickly the character rotates to face movement direction
# Higher = faster turning (8.0 radians per second)
const ROT_SPEED := 8.0

# ============================================================
# VARIABLES
# ============================================================

# Gets the gravity value from the project settings
# This allows the gravity to be changed globally in one place
# In Godot 4, gravity is in the physics/3d/default_gravity setting
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Tracks if we're currently moving (used to prevent animation spam)
# This prevents the animation from being re-triggered every frame
var is_moving: bool = false

# Snap is used to keep the character glued to the ground
# Vector3.DOWN = (0, -1, 0) - points downward
# When snap is active, the character will stick to slopes
var snap := Vector3.DOWN

# ============================================================
# _ready() - Called once when the node enters the scene tree
# ============================================================

func _ready():
	# Check if we successfully found the AnimationPlayer
	if anim_player:
		# Print all available animations to the console for debugging
		# This helps us know what animation names to use
		print("Available animations:", anim_player.get_animation_list())
		
		# Check if an animation named "Idle" exists
		if anim_player.has_animation("Idle"):
			# Play the Idle animation immediately on startup
			anim_player.play("Idle")

# ============================================================
# _physics_process() - Called every physics frame (60 times/sec by default)
# delta = time in seconds since the last physics frame
# ============================================================

func _physics_process(delta):
	# ============================================================
	# INPUT VECTOR - Read keyboard input
	# ============================================================
	
	# Creates a 2D vector from input actions
	# x = right - left  (positive = right, negative = left)
	# y = forward - back (positive = forward, negative = backward)
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	
	# Clamp the input vector to prevent diagonal speed boost
	# If both W and D are pressed, the vector length would be ~1.414
	# Normalizing reduces it to 1.0 so we don't move faster diagonally
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	# ============================================================
	# CAMERA-RELATIVE MOVEMENT - Convert screen input to world movement
	# ============================================================
	
	# Create a 3D vector to store our movement direction
	var move_dir := Vector3.ZERO
	
	# Check if we have a camera reference
	if cam:
		# Get the camera's forward direction (where it's looking)
		# The -z axis is the "forward" direction in Godot
		# basis.z returns the local Z axis in global space
		var forward := -cam.global_transform.basis.z
		
		# Get the camera's right direction
		# basis.x returns the local X axis in global space
		var right := cam.global_transform.basis.x
		
		# Remove the Y component to keep movement on the ground plane
		# This prevents the character from floating when looking up/down
		forward.y = 0
		right.y = 0
		
		# Normalize the vectors so they have a length of 1.0
		# This ensures consistent movement speed in all directions
		forward = forward.normalized()
		right = right.normalized()
		
		# Combine the input with the camera directions
		# input_vec.x * right = move left/right relative to camera
		# input_vec.y * forward = move forward/back relative to camera
		move_dir = (right * input_vec.x + forward * input_vec.y).normalized()
	else:
		# Fallback if no camera is found
		# Use world-relative movement (ignores camera rotation)
		# x = left/right, z = forward/backward
		move_dir = Vector3(input_vec.x, 0, input_vec.y).normalized()

	# ============================================================
	# MOVEMENT + ANIMATION - Apply velocity and play animations
	# ============================================================
	
	# Check if we have significant movement input
	# 0.1 is a deadzone to prevent micro-movements from twitching
	if move_dir.length() > 0.1:
		# ============================================================
		# APPLY VELOCITY - Smooth acceleration
		# ============================================================
		
		# lerp() = Linear Interpolation
		# Smoothly moves current velocity toward target velocity
		# velocity.x = current, move_dir.x * SPEED = target
		# ACCEL * delta = how fast to interpolate (time-based)
		# This creates smooth acceleration instead of instant movement
		velocity.x = lerp(velocity.x, move_dir.x * SPEED, ACCEL * delta)
		velocity.z = lerp(velocity.z, move_dir.z * SPEED, ACCEL * delta)

		# ============================================================
		# ROTATION - Turn to face movement direction
		# ============================================================
		
		# Calculate the target rotation angle (in radians)
		# atan2(y, x) returns the angle from the x-axis
		# We use move_dir.x and move_dir.z to get the horizontal angle
		# This points the character in the direction they're moving
		var target_rot := atan2(move_dir.x, move_dir.z)
		
		# lerp_angle() is like lerp but works with angles
		# It automatically handles the shortest path around the circle
		# This prevents the character from spinning the long way around
		rotation.y = lerp_angle(rotation.y, target_rot, ROT_SPEED * delta)

		# ============================================================
		# WALKING ANIMATION - Play the walk animation
		# ============================================================
		
		# Check if we have an AnimationPlayer and we're not already playing
		if anim_player and not is_moving:
			# Try to find a walking animation using our helper function
			# It searches through common animation names in order
			var walk_anim = find_animation(["Walking", "Walk", "Run", "moving", "Move"])
			
			# If we found one, play it
			if walk_anim != "":
				anim_player.play(walk_anim)
				is_moving = true  # Mark that we're moving
	else:
		# ============================================================
		# DECELERATION - Smoothly slow down to stop
		# ============================================================
		
		# move_toward() moves current value toward target by the step amount
		# This is a hard stop (no interpolation) but with a fixed step
		# It stops faster than lerp and feels more responsive
		velocity.x = move_toward(velocity.x, 0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0, DECEL * delta)

		# ============================================================
		# IDLE ANIMATION - Play the idle animation
		# ============================================================
		
		# Check if we have an AnimationPlayer and we WERE moving
		if anim_player and is_moving:
			# Try to find an idle animation
			var idle_anim = find_animation(["Idle", "idle", "Stand", "stand", "Rest"])
			
			# If we found one, play it
			if idle_anim != "":
				anim_player.play(idle_anim)
				is_moving = false  # Mark that we're not moving

	# ============================================================
	# GRAVITY AND GROUND SNAP - Keeps character on the ground
	# ============================================================
	
	# Check if the character is on the floor
	if not is_on_floor():
		# Apply gravity when in the air
		# velocity.y decreases by gravity * delta each frame
		# This creates a falling effect (acceleration downward)
		velocity.y -= gravity * delta
		
		# Disable snap when airborne
		# Without snap, the character can jump and fall freely
		snap = Vector3.ZERO
	else:
		# Reset vertical velocity when on ground
		# This prevents the character from building up downward momentum
		velocity.y = 0
		
		# Enable snap to keep character glued to the ground
		# Vector3.DOWN = (0, -1, 0) - constant downward pressure
		# This prevents the character from floating off slopes
		snap = Vector3.DOWN

	# ============================================================
	# ANTI-FLOAT PROTECTION - Extra measure to prevent hovering
	# ============================================================
	
	# If we're on the floor and not moving upward
	# Apply a tiny downward force to keep the feet on the ground
	# This is a backup to ensure the character doesn't float
	# even if the snap system has issues
	if is_on_floor() and velocity.y >= 0:
		velocity.y = -0.01

	# ============================================================
	# APPLY MOVEMENT - Actually move the character
	# ============================================================
	
	# move_and_slide() is the core physics function
	# It applies velocity, handles collisions, and updates position
	# It automatically handles sliding along walls and slopes
	# It uses the snap value to keep the character on the ground
	move_and_slide()

# ============================================================
# HELPER FUNCTION - Find animation by name
# ============================================================

# This function takes an array of possible animation names
# It tries to find a matching animation in the AnimationPlayer
# Returns the first matching animation name or "" if none found
func find_animation(possible_names: Array) -> String:
	# Return empty string if we don't have an AnimationPlayer
	if not anim_player:
		return ""
	
	# Check exact matches first (fastest)
	# Loop through each possible name
	for name in possible_names:
		# If this exact name exists in the AnimationPlayer
		if anim_player.has_animation(name):
			# Return it immediately
			return name
	
	# If no exact match, try partial matching (slower but more flexible)
	# Get a list of all available animation names
	var all_anims = anim_player.get_animation_list()
	
	# Loop through each possible name again
	for possible in possible_names:
		# Loop through all available animations
		for anim in all_anims:
			# Check if the possible name appears anywhere in the animation name
			# to_lower() makes both strings lowercase for case-insensitive matching
			if possible.to_lower() in anim.to_lower():
				# Return the first match found
				return anim
	
	# No match found at all - return empty string
	return ""

# ============================================================
# KEY CONCEPTS SUMMARY
# ============================================================
# 
# 1. CharacterBody3D provides physics properties (velocity, is_on_floor)
# 2. move_and_slide() applies velocity with collision detection
# 3. lerp() creates smooth acceleration/deceleration
# 4. lerp_angle() handles smooth rotation with angle wrapping
# 5. Snap keeps the character on the ground (prevents floating)
# 6. AnimationPlayer controls character animations
# 7. Input actions map keyboard/gamepad to game actions
# 8. Camera-relative movement makes controls feel natural
# 
# ============================================================
