extends Node3D

@onready var camera: Camera3D = $Camera3D

# --- Camera Settings ---
@export var distance := 10.0          # Default camera distance behind player
@export var min_distance := 3.0       # Minimum allowed distance
@export var height := 2.0             # Height offset above player

# --- Mouse Look ---
@export var mouse_sensitivity := 0.003
@export var min_pitch := deg_to_rad(0.0)
@export var max_pitch := deg_to_rad(70.0)

var yaw := 0.0                        # Horizontal rotation
var pitch := deg_to_rad(15.0)         # Vertical rotation

# --- Scroll Zoom ---
@export var zoom_step := 1.0
@export var min_zoom := 1.7
@export var max_zoom := 17.7
var zoom_distance := 10.0             # Current zoom distance

func _ready():
	# Set near clipping plane
	camera.near = 0.3

	# Start zoom at default distance
	zoom_distance = distance

	# Capture mouse for camera control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event):
	# ----------------------------------------------------------
	# MOUSE LOOK
	# ----------------------------------------------------------
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
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
			zoom_distance = clamp(zoom_distance - zoom_step, min_zoom, max_zoom)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_distance = clamp(zoom_distance + zoom_step, min_zoom, max_zoom)


func _process(_delta):
	# Target is player's position + height offset
	var target := global_position + Vector3(0, height, 0)

	# Apply zoom
	var final_distance := zoom_distance

	# Offset behind player based on yaw/pitch
	var offset := Vector3(0, 0, -final_distance)
	offset = offset.rotated(Vector3.RIGHT, pitch)
	offset = offset.rotated(Vector3.UP, yaw)

	# Raycast to avoid clipping through walls
	var ray := PhysicsRayQueryParameters3D.create(target, target + offset)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)

	if hit:
		camera.global_position = hit.position
	else:
		camera.global_position = target + offset

	# Always look at player
	camera.look_at(target, Vector3.UP)
