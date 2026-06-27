extends Node3D
class_name CameraPivot

@export var sensitivity := 0.05
@export var min_pitch := deg_to_rad(-40)
@export var max_pitch := deg_to_rad(60)

var yaw := 0.0
var pitch := 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * sensitivity
		pitch -= event.relative.y * sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

func _process(delta):
	rotation.x = pitch
	rotation.y = yaw

func get_forward_direction() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0
	return f.normalized()

func get_right_direction() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0
	return r.normalized()
