extends CharacterBody3D
class_name JeremiahController

# ============================================================
# MOVEMENT SETTINGS
# ============================================================
@export var SPEED: float = 4.0
@export var STRAFE_SPEED: float = 5.0
@export var ROTATION_SPEED: float = 5.0
@export var JUMP_FORCE: float = 5.67
@export var BLEND_TIME: float = 0.36

# ============================================================
# CAMERA SETTINGS
# ============================================================
@export var MOUSE_SENSITIVITY: float = 0.2
@export var INVERT_Y: bool = false
@export var CAMERA_SMOOTH: float = 0.15
@export var CAMERA_DISTANCE: float = 4.0
@export var MIN_CAMERA_ANGLE: float = -80.0
@export var MAX_CAMERA_ANGLE: float = 80.0

# ============================================================
# MOONWALK SETTINGS
# ============================================================
@export var MOONWALK_ENABLED: bool = true
@export var MOONWALK_ANGLE: float = 0
@export var MOONWALK_SPEED_MULTIPLIER: float = 1.0

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var anim: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var cam_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = find_child("Camera3D", true, false)
@onready var spring_arm: SpringArm3D = find_child("SpringArm3D", true, false)

# ============================================================
# INTERNAL STATE
# ============================================================
var cam_rot := Vector2.ZERO
var cam_target := Vector2.ZERO
var mouse_captured := true

var anim_cache := {}
var current := ""
var attacking := false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ============================================================
# ANIMATION SHORTCUTS
# ============================================================
const Anim = {
	IDLE = "Idle",
	WALK = "Walk",
	BACK = "Back",
	JUMP = "Jump",
	ATTACK = "Fist Fight A",
	LEFT = "Walk",
	RIGHT = "Walk"
}

# ============================================================
# READY
# ============================================================
func _ready():
	# Ensure AnimationPlayer exists
	if not anim:
		push_error("AnimationPlayer not found.")
		return

	# Fallback camera if node path fails
	if not camera:
		camera = get_viewport().get_camera_3d()

	# Cache animation names
	await get_tree().process_frame
	for n in anim.get_animation_list():
		anim_cache[n] = true

	# Connect animation finished
	anim.animation_finished.connect(_on_animation_finished)

	# Floor snapping for stability
	floor_snap_length = 0.5

	# Start idle animation
	_play_safe(Anim.IDLE)

	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Spring arm distance
	if spring_arm:
		spring_arm.spring_length = CAMERA_DISTANCE

# ============================================================
# INPUT
# ============================================================
func _input(e):
	if e is InputEventMouseMotion and mouse_captured:
		# Smooth camera rotation input
		cam_target.x -= e.relative.x * MOUSE_SENSITIVITY * 0.01
		cam_target.y += (e.relative.y * MOUSE_SENSITIVITY * 0.01) * (1 if INVERT_Y else -1)
		cam_target.y = clamp(cam_target.y, deg_to_rad(MIN_CAMERA_ANGLE), deg_to_rad(MAX_CAMERA_ANGLE))

	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		mouse_captured = !mouse_captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE)

	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		mouse_captured = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ============================================================
# PHYSICS PROCESS
# ============================================================
func _physics_process(delta):
	var grounded := is_on_floor()

	# Movement input
	var f := Input.get_action_strength("move_forward")
	var b := Input.get_action_strength("move_back")
	var l := Input.get_action_strength("move_left")
	var r := Input.get_action_strength("move_right")
	var moving := f > 0 or b > 0 or l > 0 or r > 0

	# Attack input
	if Input.is_action_just_pressed("attack") and not attacking:
		attacking = true
		_play_safe(Anim.ATTACK, 0.05)

	# Jump input
	if Input.is_action_just_pressed("jump") and grounded:
		velocity.y = JUMP_FORCE
		_play_safe(Anim.JUMP, 0.05)

	# Update camera rotation
	_update_camera(delta)

	# Camera-relative movement
	var cf := Vector3.FORWARD
	var cr := Vector3.RIGHT

	if camera:
		cf = -camera.global_transform.basis.z
		cr = camera.global_transform.basis.x
		cf.y = 0
		cr.y = 0
		cf = cf.normalized()
		cr = cr.normalized()

	# Movement direction
	var dir := Vector3.ZERO

	if f > 0:
		dir += cf

	if b > 0:
		if MOONWALK_ENABLED:
			dir += -cf * MOONWALK_SPEED_MULTIPLIER
		else:
			dir += -cf

	if l > 0:
		dir += -cr

	if r > 0:
		dir += cr

	if dir != Vector3.ZERO:
		dir = dir.normalized()

	# Rotation
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * ROTATION_SPEED)

	# Velocity
	if moving:
		var base_speed := SPEED
		if l > 0 or r > 0:
			base_speed = STRAFE_SPEED

		var accel := 20.0777
		velocity.x = move_toward(velocity.x, dir.x * base_speed, accel * delta)
		velocity.z = move_toward(velocity.z, dir.z * base_speed, accel * delta)


	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * delta)

	# Gravity
	if grounded:
		velocity.y = max(velocity.y, 0.0)
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	# Animation state
	if attacking:
		return

	if not grounded:
		_play_safe(Anim.JUMP)
	elif moving:
		_play_safe(Anim.WALK)  # FIXED LIMB — ONE WALK ANIMATION ONLY
	else:
		_play_safe(Anim.IDLE)

# ============================================================
# CAMERA UPDATE
# ============================================================
func _update_camera(delta):
	cam_rot = cam_rot.lerp(cam_target, 1.0 - exp(-CAMERA_SMOOTH * 60.0 * delta))

	if cam_pivot:
		cam_pivot.rotation.x = cam_rot.y
		cam_pivot.rotation.y = cam_rot.x

	if spring_arm:
		spring_arm.spring_length = CAMERA_DISTANCE
		spring_arm.rotation.x = -cam_rot.y
		spring_arm.rotation.y = cam_rot.x

# ============================================================
# ANIMATION FINISHED
# ============================================================
func _on_animation_finished(n: String):
	if "fist" in n.to_lower():attacking = false


# ============================================================
# SAFE PLAY (BLENDED)
# ============================================================
func _play_safe(name: String, blend: float = -1.0) -> void:
	var resolved := _resolve(name)
	if resolved == "":
		return

	if current == resolved and anim.is_playing():
		return

	current = resolved
	anim.play(resolved, blend if blend >= 0 else BLEND_TIME)

# ============================================================
# ANIMATION NAME RESOLVER
# ============================================================
func _resolve(name: String) -> String:
	if anim_cache.has(name):
		return name

	var ln := name.to_lower()
	for c in anim_cache.keys():
		var lc :String= c.to_lower()
		if lc == ln or ln in lc:
			return c

	return ""
