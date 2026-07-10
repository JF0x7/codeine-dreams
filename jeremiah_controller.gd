extends CharacterBody3D
class_name JeremiahController

# ============================================================
# EXPORT VARIABLES
# These are adjustable settings visible in the Godot Inspector.
# They control movement speed, camera behavior, animation blending, etc.
# ============================================================

@export var SPEED := 5.0
@export var STRAFE_SPEED := 5.0
@export var ROTATION_SPEED := 8.0
@export var JUMP_FORCE := 6.0
@export var BLEND_TIME := 0.15

@export var MOUSE_SENSITIVITY := 0.2
@export var INVERT_Y := false
@export var CAMERA_SMOOTH := 0.15
@export var CAMERA_DISTANCE := 4.0
@export var MIN_CAMERA_ANGLE := -80.0
@export var MAX_CAMERA_ANGLE := 80.0

@export var MOONWALK_ENABLED := true
@export var MOONWALK_ANGLE := 0
@export var MOONWALK_SPEED_MULTIPLIER := 1.0

# ============================================================
# NODE REFERENCES
# These reference parts of the character model.
# ============================================================

@onready var anim: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var cam_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = find_child("Camera3D", true, false)
@onready var spring_arm: SpringArm3D = find_child("SpringArm3D", true, false)

# ============================================================
# INTERNAL STATE VARIABLES
# These store runtime information such as camera rotation,
# animation state, and movement flags.
# ============================================================

var cam_rot := Vector2.ZERO
var cam_target := Vector2.ZERO
var mouse_captured := true
var anim_cache := {}
var current := ""
var attacking := false
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Animation name shortcuts
const Anim = {
	IDLE="Idle",
	WALK="Walk",
	BACK="Back",
	JUMP="Jump",
	ATTACK="Fist Fight A",
	LEFT="Walk",
	RIGHT="Walk"
}

# ============================================================
# READY
# Runs once when the scene loads.
# ============================================================

func _ready():
	if not anim:
		push_error("AnimationPlayer not found.")
		return
	
	if not camera:
		camera = get_viewport().get_camera_3d()
	
	await get_tree().process_frame
	
	for n in anim.get_animation_list():
		anim_cache[n] = true
	
	anim.animation_finished.connect(_on_animation_finished)
	floor_snap_length = 0.5
	
	_play_safe(Anim.IDLE)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if spring_arm:
		spring_arm.spring_length = CAMERA_DISTANCE

# ============================================================
# INPUT HANDLING
# Handles mouse movement and ESC key toggling.
# ============================================================

func _input(e):
	if e is InputEventMouseMotion and mouse_captured:
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
# Main movement, rotation, animation, and camera logic.
# ============================================================

func _physics_process(delta):
	var grounded := is_on_floor()
	
	var f := Input.get_action_strength("move_forward")
	var b := Input.get_action_strength("move_back")
	var l := Input.get_action_strength("move_left")
	var r := Input.get_action_strength("move_right")
	var moving := f > 0 or b > 0 or l > 0 or r > 0
	
	# Attack
	if Input.is_action_just_pressed("attack") and not attacking:
		attacking = true
		_play_safe(Anim.ATTACK, 0.05)
	
	# Jump
	if Input.is_action_just_pressed("jump") and grounded:
		velocity.y = JUMP_FORCE
		_play_safe(Anim.JUMP, 0.05)
	
	# Camera update
	_update_camera(delta)
	
	# Camera-relative movement directions
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
			if not (l > 0 or r > 0):
				dir += -cf * MOONWALK_SPEED_MULTIPLIER
			elif l > 0 and not r > 0:
				dir += (-cf - cr).normalized() * MOONWALK_SPEED_MULTIPLIER
			elif r > 0 and not l > 0:
				dir += (-cf + cr).normalized() * MOONWALK_SPEED_MULTIPLIER
	
	elif l > 0:
		dir += -cr
	
	elif r > 0:
		dir += cr
	
	if dir != Vector3.ZERO:
		dir = dir.normalized()
	
	# Rotation
	if b > 0 and MOONWALK_ENABLED:
		var back_angle := atan2(cf.x, cf.z)
		rotation.y = lerp_angle(rotation.y, back_angle, delta * ROTATION_SPEED)
	elif dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * ROTATION_SPEED)
	
	# Velocity
	if moving:
		var base_speed := SPEED
		if l > 0 or r > 0:
			base_speed = STRAFE_SPEED
		
		velocity.x = dir.x * base_speed
		velocity.z = dir.z * base_speed
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
		if l > 0:
			_play_safe(Anim.LEFT)
		elif r > 0:
			_play_safe(Anim.RIGHT)
		elif b > 0:
			_play_safe(Anim.BACK)
		else:
			_play_safe(Anim.WALK)
	else:
		_play_safe(Anim.IDLE)

# ============================================================
# CAMERA UPDATE
# Smoothly interpolates camera rotation.
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
# Resets attack state and resumes movement animations.
# ============================================================

func _on_animation_finished(n: String):
	if n == Anim.ATTACK or n == "Fist Fight A" or n == "Fist Fight A/mixamo_com":
		attacking = false
		
		anim.stop()
		anim.seek(0.0, true)
		
		await get_tree().create_timer(0.02).timeout
		
		var f := Input.get_action_strength("move_forward")
		var b := Input.get_action_strength("move_back")
		var l := Input.get_action_strength("move_left")
		var r := Input.get_action_strength("move_right")
		var moving := f > 0 or b > 0 or l > 0 or r > 0
		
		if moving:
			if l > 0:
				_play_safe_forced(Anim.LEFT, 0.1)
			elif r > 0:
				_play_safe_forced(Anim.RIGHT, 0.1)
			elif b > 0:
				_play_safe_forced(Anim.BACK, 0.1)
			else:
				_play_safe_forced(Anim.WALK, 0.1)
		else:
			_play_safe_forced(Anim.IDLE, 0.1)

# ============================================================
# FORCED PLAY
# Used after attack animations to reset state.
# ============================================================

func _play_safe_forced(name: String, blend: float = 0.1) -> void:
	var resolved := _resolve(name)
	if resolved == "":
		return
	
	anim.stop()
	anim.seek(0.0, true)
	current = resolved
	anim.play(resolved, blend)

# ============================================================
# SAFE PLAY
# Normal animation switching with blending.
# ============================================================

func _play_safe(name: String, blend: float = -1.0) -> void:
	if attacking and name != Anim.ATTACK:
		return
	
	var resolved := _resolve(name)
	if resolved == "" or (current == resolved and anim.is_playing()):
		return
	
	current = resolved
	anim.play(resolved, blend if blend >= 0 else BLEND_TIME)

# ============================================================
# ANIMATION NAME RESOLVER
# Finds correct animation name even if Mixamo adds suffixes.
# ============================================================

func _resolve(name: String) -> String:
	if anim_cache.has(name):
		return name
	
	for c in anim_cache.keys():
		var lc :String= c.to_lower()
		var ln := name.to_lower()
		if lc == ln or ln in lc:
			return c
	
	return ""
