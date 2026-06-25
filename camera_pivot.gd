extends Node3D

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
