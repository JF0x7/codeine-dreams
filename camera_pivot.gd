extends Node3D
class_name CameraPivot

@export var sensitivity := 0.05
@export var min_pitch := deg_to_rad(-40)
@export var max_pitch := deg_to_rad(60)

@export var follow_distance := 3.0
@export var follow_height := 1.5
@export var follow_smoothing := 0.15
@export var enable_camera_following := true

@export var min_camera_height := 0.5
@export var max_camera_height := 100.0
@export var enable_boundary_checking := true

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

	if enable_camera_following and get_parent():
		# Explicitly type the player variable
		var player: Node3D = get_parent()
		
		# OR if you want to use JeremiahController specifically:
		# var player: JeremiahController = get_parent()

		# Camera direction (horizontal only)
		var cam_dir := -global_transform.basis.z
		cam_dir.y = 0
		cam_dir = cam_dir.normalized()

		# Desired camera position - now properly typed
		var desired: Vector3 = player.global_position
		desired.y += follow_height
		desired -= cam_dir * follow_distance

		if enable_boundary_checking:
			desired.y = clamp(desired.y, min_camera_height, max_camera_height)

		global_position = global_position.lerp(desired, follow_smoothing)

func get_forward_direction() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0
	return f.normalized()

func get_right_direction() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0
	return r.normalized()

func get_rotation_angles() -> Vector2:
	return Vector2(yaw, pitch)

func set_rotation_angles(new_yaw: float, new_pitch: float):
	yaw = new_yaw
	pitch = clamp(new_pitch, min_pitch, max_pitch)

func toggle_mouse_capture():
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func reset_camera():
	yaw = 0.0
	pitch = 0.0

func set_min_camera_height(h: float):
	min_camera_height = h

func set_max_camera_height(h: float):
	max_camera_height = h
