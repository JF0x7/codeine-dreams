extends CharacterBody3D

# --- Animation ---
@onready var anim_player: AnimationPlayer = $AnimationTree/AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# --- Camera ---
@onready var cam: Camera3D = $SpringArm3D/Camera3D

# --- Movement settings ---
const MOVE_SPEED := 4.0
const ACCEL := 10.0
const DECEL := 12.0
const ROT_SPEED := 8.0

var speed: float = 4.5
var jump_force: float = 4.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Mouse look ---
var mouse_sensitivity: float = 0.003
var rotation_x: float = 0.0
var rotation_y: float = 0.0

func _ready():
	# Camera + mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	cam.current = true

	# Animation
	anim_tree.active = true
	anim_player.play("Idle")

func _input(event):
	if event is InputEventMouseMotion:
		rotation_y -= event.relative.x * mouse_sensitivity
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, deg_to_rad(-60), deg_to_rad(30))
		cam.rotation = Vector3(rotation_x, rotation_y, 0)

func _physics_process(delta):
	# -------------------------
	# MOVEMENT INPUT
	# -------------------------
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# -------------------------
	# JUMP + GRAVITY
	# -------------------------
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_force

	# -------------------------
	# GTA‑STYLE MOVEMENT
	# -------------------------
	if move_dir.length() > 0.1:
		# Accelerate
		velocity.x = lerp(velocity.x, move_dir.x * MOVE_SPEED, ACCEL * delta)
		velocity.z = lerp(velocity.z, move_dir.z * MOVE_SPEED, ACCEL * delta)

		# Rotate character toward movement direction
		var target_rot = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, ROT_SPEED * delta)

		# Animations
		anim_player.play("Walk")
		anim_state.travel("Walk")
	else:
		# Decelerate
		velocity.x = move_toward(velocity.x, 0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0, DECEL * delta)

		# Animations
		anim_player.play("Idle")
		anim_state.travel("Idle")

	move_and_slide()
