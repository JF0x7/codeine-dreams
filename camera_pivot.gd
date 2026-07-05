extends Node3D

@onready var camera: Camera3D = $Camera3D

@export var distance := 10.0
@export var min_distance := 3.0
@export var height := 2.0
@export var mouse_sensitivity := 0.003
@export var min_pitch := deg_to_rad(0.0)
@export var max_pitch := deg_to_rad(70.0)

var yaw := 0.0
var pitch := deg_to_rad(15.0)

func _ready():
	camera.near = 0.3
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta):
	var target = global_position + Vector3(0, height, 0)

	# Clamp camera distance
	distance = max(distance, min_distance)

	var offset = Vector3(0, 0, -distance)
	offset = offset.rotated(Vector3.RIGHT, pitch)
	offset = offset.rotated(Vector3.UP, yaw)

	# Camera collision ray
	var ray = PhysicsRayQueryParameters3D.create(target, target + offset)
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)

	if hit:
		camera.global_position = hit.position
	else:
		camera.global_position = target + offset

	camera.look_at(target, Vector3.UP)
