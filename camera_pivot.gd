extends Node3D

@onready var camera: Camera3D = $Camera3D

# --- Camera Settings ---
@export var distance: float = 11.0
@export var min_distance: float = 7.7
@export var height: float = 1.7

# --- Sensitivity ---
@export var mouse_sensitivity: float = 0.005
@export var stick_sensitivity: float = 2.5

@export var min_pitch: float = deg_to_rad(-89.7)
@export var max_pitch: float = deg_to_rad(89.7)

var yaw: float = 0.0
var pitch: float = deg_to_rad(15.0)

# --- Zoom ---
@export var zoom_step: float = 1.0
@export var min_zoom: float = 1.0
@export var max_zoom: float = 15.0
var zoom_distance: float = 10.7


func _ready() -> void:
	camera.near = 0.7
	zoom_distance = distance
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	# --- Mouse Look ---
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

	# --- Mouse Capture Toggle ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# --- Scroll Zoom ---
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_distance = clamp(zoom_distance - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_distance = clamp(zoom_distance + zoom_step, min_zoom, max_zoom)


func _process(delta: float) -> void:
	# --- Controller Look ---
	var look_x := Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_y := Input.get_action_strength("look_down") - Input.get_action_strength("look_up")

	yaw -= look_x * stick_sensitivity * delta
	pitch -= look_y * stick_sensitivity * delta
	pitch = clamp(pitch, min_pitch, max_pitch)

	# --- Orbit Pivot ---
	var target := global_position + Vector3(0, height, 0)

	# --- Orbit Offset ---
	var offset := Vector3(
		sin(yaw) * cos(pitch) * zoom_distance,
		sin(pitch) * zoom_distance,
		cos(yaw) * cos(pitch) * zoom_distance
	)

	# --- Collision Raycast ---
	var ray := PhysicsRayQueryParameters3D.create(target, target + offset)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)

	if hit and hit.collider != self:
		camera.global_position = hit.position
	else:
		camera.global_position = target + offset

	camera.look_at(target, Vector3.UP)
