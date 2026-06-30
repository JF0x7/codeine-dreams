extends Node3D
class_name CameraPivot

# ============================================================================
# MOUSE & LOOK SETTINGS - TWEAK THESE!
# ============================================================================
# How sensitive the camera is to mouse movement (higher = faster)
@export var sensitivity := 0.05

# Minimum pitch (how far down you can look in degrees)
@export var min_pitch := deg_to_rad(-40)

# Maximum pitch (how far up you can look in degrees)
@export var max_pitch := deg_to_rad(60)

# ============================================================================
# CAMERA FOLLOWING SETTINGS - TWEAK THESE!
# ============================================================================
# How far behind the player the camera should be
@export var follow_distance := 3.0

# How high above the player's feet the camera should be
@export var follow_height := 1.5

# Smoothing factor for camera movement (0.01 = very smooth, 0.5 = snappy)
@export var follow_smoothing := 0.15

# Enable/disable camera following (useful for testing)
@export var enable_camera_following := true

# ============================================================================
# MAP BOUNDARY SETTINGS - TWEAK THESE!
# ============================================================================
# Minimum Y position (prevent camera from going under the map)
# Set this to your map's lowest point + some buffer
@export var min_camera_height := 0.5

# Maximum Y position (prevent camera from going too high above map)
@export var max_camera_height := 100.0

# Enable map boundary checking
@export var enable_boundary_checking := true

# ============================================================================
# INTERNAL STATE
# ============================================================================
var yaw := 0.0      # Horizontal rotation
var pitch := 0.0    # Vertical rotation
var target_position := Vector3.ZERO

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready():
	# Capture mouse cursor for first-person style control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("CameraPivot initialized - Mouse captured for camera control")

# ============================================================================
# INPUT HANDLING - Mouse Look
# ============================================================================
func _input(event):
	if event is InputEventMouseMotion:
		# Adjust yaw (horizontal) and pitch (vertical)
		yaw -= event.relative.x * sensitivity
		pitch -= event.relative.y * sensitivity
		
		# Clamp pitch to prevent flipping
		pitch = clamp(pitch, min_pitch, max_pitch)

# ============================================================================
# PROCESS UPDATE - Apply rotations and camera following
# ============================================================================
func _process(delta):
	# Apply rotation based on mouse input
	rotation.x = pitch
	rotation.y = yaw
	
	# Smooth camera following behind the player
	if enable_camera_following and get_parent():
		var player = get_parent()
		
		# Calculate camera position behind player
		# Get camera direction (backwards from where player is looking)
		var camera_direction = -global_transform.basis.z
		camera_direction.y = 0  # Keep horizontal
		camera_direction = camera_direction.normalized()
		
		# Position camera behind player at follow_distance
		var desired_position = player.global_position + Vector3(0, follow_height, 0)
		desired_position -= camera_direction * follow_distance
		
		# Apply boundary checking to prevent going under/above map
		if enable_boundary_checking:
			desired_position.y = clamp(desired_position.y, min_camera_height, max_camera_height)
		
		# Smoothly interpolate camera position toward target
		global_position = global_position.lerp(desired_position, follow_smoothing)

# ============================================================================
# DIRECTION HELPERS - Used by player movement
# ============================================================================

# Get the forward direction the camera is facing (ignoring vertical tilt)
func get_forward_direction() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0  # Ignore vertical component for movement
	return f.normalized()

# Get the right direction relative to camera
func get_right_direction() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0  # Ignore vertical component for movement
	return r.normalized()

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Get current camera rotation as Vector2 (yaw, pitch)
func get_rotation_angles() -> Vector2:
	return Vector2(yaw, pitch)

# Set camera rotation directly (useful for cutscenes)
func set_rotation_angles(new_yaw: float, new_pitch: float):
	yaw = new_yaw
	pitch = clamp(new_pitch, min_pitch, max_pitch)

# Toggle mouse capture on/off
func toggle_mouse_capture():
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("Mouse released")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		print("Mouse captured")

# Reset camera to default position and rotation
func reset_camera():
	yaw = 0.0
	pitch = 0.0
	print("Camera reset to default orientation")

# Set map boundary height (call this if you change map size)
func set_min_camera_height(height: float):
	"""Set the minimum camera height to prevent going under the map"""
	min_camera_height = height
	print("Min camera height set to: ", height)

func set_max_camera_height(height: float):
	"""Set the maximum camera height"""
	max_camera_height = height
	print("Max camera height set to: ", height)
