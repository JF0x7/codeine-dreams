extends CharacterBody3D

class_name JeremiahController

# ---- Nodes ----
@onready var anim: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var cam_pivot: Node3D = $CameraPivot

# ---- Animation Names ----
const Anim = {
	IDLE = "Idle",
	WALK = "Walking",
	JUMP = "Jump",
	ATTACK = "Fist Fight A"
}

# ---- Movement ----
const SPEED := 5.0
const JUMP_FORCE := 6.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ---- State ----
var attacking := false
var is_moving := false

# ---- Rotation ----
var target_rotation := 0.0
var rot_speed := 8.0

# ---- Self‑Learning AI ----
var fluidity_score := 0.6              # How smooth movement should feel
var input_memory: Array = []           # Stores recent inputs
var learning_rate := 0.03              # How fast AI adapts
var ai_input := Vector2.ZERO           # AI‑stabilized input


func _ready():
	if not anim:
		push_error("AnimationPlayer NOT FOUND")
		return
	
	anim.animation_finished.connect(_on_animation_finished)
	floor_snap_length = 0.5
	target_rotation = rotation.y
	anim.play_safe(Anim.IDLE)


func _physics_process(delta):
	if not anim:
		return
	
	# ---- Raw Input ----
	var raw_input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	if raw_input.length() > 1.0:
		raw_input = raw_input.normalized()
	
	is_moving = raw_input.length() > 0.1
	var is_on_ground := is_on_floor()
	
	# ---- Self‑Learning AI: stabilize + learn from input ----
	_update_ai(raw_input)
	var input_vec := ai_input
	
	# ---- Attack ----
	if Input.is_action_just_pressed("attack") and not attacking:
		attacking = true
		anim.play_safe(Anim.ATTACK, 0.05)
		return
	
	# ---- Jump ----
	if Input.is_action_just_pressed("jump") and is_on_ground and not attacking:
		velocity.y = JUMP_FORCE
		anim.play_safe(Anim.JUMP, 0.05)
	
	# ---- Movement ----
	if not attacking:
		var forward := -cam_pivot.global_transform.basis.z
		var right := cam_pivot.global_transform.basis.x
		var move_dir: Vector3 = (right * input_vec.x) + (forward * input_vec.y)
		
		if is_moving:
			move_dir = move_dir.normalized()
			
			# Smooth rotation based on fluidity_score
			target_rotation = atan2(move_dir.x, move_dir.z)
			var angle_diff := _angle_difference(rotation.y, target_rotation)
			var rot_mult := 0.5 + fluidity_score * 0.5
			rotation.y += sign(angle_diff) * min(abs(angle_diff), rot_speed * rot_mult * delta)
			
			# Movement speed also influenced by fluidity_score
			var speed_mult := 0.6 + fluidity_score * 0.4
			velocity.x = move_dir.x * SPEED * speed_mult
			velocity.z = move_dir.z * SPEED * speed_mult
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED * delta)
			velocity.z = move_toward(velocity.z, 0.0, SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 2.0)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * delta * 2.0)
	
	# ---- Gravity ----
	if not is_on_ground:
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	
	move_and_slide()
	
	# ---- Animations ----
	if not attacking:
		var target_anim := _select_animation(is_moving, is_on_ground)
		if anim.current_animation_name != target_anim:
			anim.play_safe(target_anim, 0.15)


# ---------------------------------------------------------
# Self‑Learning AI Module
# ---------------------------------------------------------
func _update_ai(raw_input: Vector2):
	# If not moving, slowly reset toward neutral
	if raw_input.length() < 0.1:
		ai_input = raw_input
		fluidity_score = lerp(fluidity_score, 0.6, 0.01)
		return
	
	# Store recent inputs
	input_memory.append(raw_input)
	if input_memory.size() > 30:
		input_memory.pop_front()
	
	# Compute average input direction
	var avg := Vector2.ZERO
	for v in input_memory:
		avg += v
	avg /= float(input_memory.size())
	
	# AI‑stabilized input: blend raw toward average
	ai_input = raw_input.lerp(avg, 0.2)
	if ai_input.length() > 1.0:
		ai_input = ai_input.normalized()
	
	# Measure consistency: how close raw input is to average
	var consistency := 1.0 - (raw_input.angle_to(avg) * 0.8)
	consistency = clamp(consistency, 0.0, 1.0)
	
	# Update fluidity_score based on consistency
	fluidity_score = lerp(fluidity_score, consistency, learning_rate)
	fluidity_score = clamp(fluidity_score, 0.3, 0.95)


# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------
func _select_animation(moving: bool, on_ground: bool) -> String:
	if not on_ground:
		return Anim.JUMP
	elif moving:
		return Anim.WALK
	else:
		return Anim.IDLE


func _angle_difference(from: float, to: float) -> float:
	var diff := fmod(to - from, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return diff


func _on_animation_finished(anim_name: String):
	var attack_name = anim._find_animation(Anim.ATTACK)
	if anim_name == attack_name:
		attacking = false
		anim.play_safe(Anim.IDLE, 0.2)


# ---- Debug / Stats ----
func get_stats() -> Dictionary:
	return {
		"fluidity": fluidity_score,
		"memory_size": input_memory.size(),
		"ai_input": ai_input
	}
