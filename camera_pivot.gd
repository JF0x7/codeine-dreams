extends Node3D

@onready var camera: Camera3D = $Camera3D

# --- Camera Settings ---
@export var distance := 11          # Default camera distance behind player
@export var min_distance :=7.7       # Minimum allowed zoom distance
@export var height := 1.7           # Orbit pivot height (raised for perfect sky view)

# --- Mouse Look ---
@export var mouse_sensitivity := 0.005
@export var min_pitch := deg_to_rad(-89.7)   # Allow full downward look
@export var max_pitch := deg_to_rad(89.7)    # Allow full upward look

var yaw := 0.0                        # Horizontal rotation angle
var pitch := deg_to_rad(15.0)         # Vertical rotation angle

# --- Scroll Zoom ---
@export var zoom_step := 1.0
@export var min_zoom := 1.0
@export var max_zoom := 15.0
var zoom_distance := 10.7             # Current zoom distance

func _ready():
	# Set near clipping plane so camera doesn't clip through close objects
	camera.near = 0.7

	# Initialize zoom distance
	zoom_distance = distance

	# Capture mouse for camera control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event):
	# ----------------------------------------------------------
	# MOUSE LOOK
	# ----------------------------------------------------------
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation (left/right)
		yaw -= event.relative.x * mouse_sensitivity

		# Vertical rotation (up/down)
		pitch -= event.relative.y * mouse_sensitivity

		# Clamp pitch so camera can look fully up and down
		pitch = clamp(pitch, min_pitch, max_pitch)

	# ESC unlocks mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Left click recaptures mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# ----------------------------------------------------------
	# SCROLL ZOOM
	# ----------------------------------------------------------
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# Zoom in
			zoom_distance = clamp(zoom_distance - zoom_step, min_zoom, max_zoom)

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# Zoom out
			zoom_distance = clamp(zoom_distance + zoom_step, min_zoom, max_zoom)


func _process(_delta):
	# ----------------------------------------------------------
	# ORBIT PIVOT POINT
	# ----------------------------------------------------------
	# Raise pivot above player so camera never dips underground
	var target := global_position + Vector3(0, height, 0)

	# ----------------------------------------------------------
	# SPHERICAL ORBIT OFFSET (perfect sky view)
	# ----------------------------------------------------------
	# This creates a true orbit around the player using yaw/pitch
	var offset := Vector3(
		sin(yaw) * cos(pitch) * zoom_distance,  # X movement
		sin(pitch) * zoom_distance,             # Y movement (up/down)
		cos(yaw) * cos(pitch) * zoom_distance   # Z movement
	)

	# ----------------------------------------------------------
	# RAYCAST TO AVOID WALL CLIPPING
	# ----------------------------------------------------------
	var ray := PhysicsRayQueryParameters3D.create(target, target + offset)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)

	# If ray hits something AND it's not the player, move camera to hit point
	if hit and hit.collider != self:
		camera.global_position = hit.position
	else:
		# Otherwise place camera at orbit offset
		camera.global_position = target + offset

	# ----------------------------------------------------------
	# CAMERA LOOKS AT PLAYER
	# ----------------------------------------------------------
	camera.look_at(target, Vector3.UP)
