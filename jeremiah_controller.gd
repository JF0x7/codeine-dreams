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
	ATTACK = "Fist Fight A",
	DODGE = "Dodge",
	COMBO = "Combo_Attack"
}

# ---- Movement ----
const SPEED := 5.0
const JUMP_FORCE := 6.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ---- State ----
var attacking := false
var is_moving := false
var target_rotation := 0.0
var rot_speed := 8.0
var combat_mode := false
var dodge_cooldown := 0.0
var combo_count := 0

# ---- Simple Learning ----
var fluidity_score := 0.6
var movement_history: Array = []
var learning_rate := 0.02
var last_success := true

# ---- JZFai (NEW AI MODULE) ----
var jzf_predicted_input := Vector2.ZERO
var jzf_straightness := 0.0
var jzf_correction_strength := 0.15   # How much AI corrects wobble
var jzf_memory := []                  # Stores last 20 inputs


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

	# ---- JZFai Prediction ----
	_update_jzf_ai(raw_input)

	# Use AI‑stabilized input instead of raw input
	var input_vec := jzf_predicted_input

	# ---- Learning ----
	_update_learning(input_vec)

	# ---- Attack ----
	if Input.is_action_just_pressed("attack") and not attacking:
		attacking = true
		var attack_type = _choose_attack()
		anim.play_safe(attack_type, 0.05)
		return

	# ---- Jump ----
	if Input.is_action_just_pressed("jump") and is_on_ground and not attacking:
		velocity.y = JUMP_FORCE
		anim.play_safe(Anim.JUMP, 0.05)

	# ---- Dodge ----
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0 and not attacking:
		_dodge()

	# ---- Movement ----
	if not attacking:
		var forward := -cam_pivot.global_transform.basis.z
		var right := cam_pivot.global_transform.basis.x
		var move_dir: Vector3 = (right * input_vec.x) + (forward * input_vec.y)

		if is_moving:
			move_dir = move_dir.normalized()
			
			# Smooth rotation (AI‑boosted)
			target_rotation = atan2(move_dir.x, move_dir.z)
			var angle_diff := _angle_difference(rotation.y, target_rotation)
			var speed = rot_speed * (0.8 + fluidity_score * 0.3 + jzf_straightness * 0.2)
			rotation.y += sign(angle_diff) * min(abs(angle_diff), speed * delta)
			
			# Apply speed with fluidity + AI straightness
			var speed_mult = 0.7 + fluidity_score * 0.5 + jzf_straightness * 0.3
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
		var target_anim = _select_animation(is_moving, is_on_ground)
		if anim.current_animation_name != target_anim:
			anim.play_safe(target_anim, 0.15)


# ---------------------------------------------------------
# JZFai — AI Stabilizer Module
# ---------------------------------------------------------
func _update_jzf_ai(raw_input: Vector2):
	# Store last inputs
	jzf_memory.append(raw_input)
	if jzf_memory.size() > 20:
		jzf_memory.pop_front()

	# If not moving, AI resets
	if raw_input.length() < 0.1:
		jzf_predicted_input = raw_input
		jzf_straightness = lerp(jzf_straightness, 0.0, 0.1)
		return

	# Average last inputs
	var avg := Vector2.ZERO
	for v in jzf_memory:
		avg += v
	avg /= float(jzf_memory.size())

	# Straightness = how aligned raw input is with average
	jzf_straightness = clamp(1.0 - (raw_input.angle_to(avg) * 1.2), 0.0, 1.0)

	# AI correction: blend raw input toward average
	jzf_predicted_input = raw_input.lerp(avg, jzf_correction_strength)

	# Normalize for movement
	if jzf_predicted_input.length() > 1.0:
		jzf_predicted_input = jzf_predicted_input.normalized()


# ---------------------------------------------------------
# Learning System
# ---------------------------------------------------------
func _update_learning(input_vec: Vector2):
	var moving = input_vec.length() > 0.1
	
	if moving:
		movement_history.append({
			"input": input_vec,
			"timestamp": Time.get_ticks_msec()
		})
		
		if movement_history.size() > 50:
			movement_history.pop_front()
		
		if movement_history.size() > 5:
			var recent = movement_history.slice(-10)
			var avg_x = 0.0
			var avg_y = 0.0
			for entry in recent:
				avg_x += entry.input.x
				avg_y += entry.input.y
			avg_x /= float(recent.size())
			avg_y /= float(recent.size())
			
			var consistency = 1.0 - abs(avg_x - input_vec.x) * 0.5 - abs(avg_y - input_vec.y) * 0.5
			consistency = clamp(consistency, 0.0, 1.0)
			
			fluidity_score = lerp(fluidity_score, consistency, learning_rate)
			fluidity_score = clamp(fluidity_score, 0.3, 0.95)
	else:
		fluidity_score = lerp(fluidity_score, 0.6, 0.01)


func _select_animation(moving: bool, on_ground: bool) -> String:
	if not on_ground:
		return Anim.JUMP
	elif moving:
		return Anim.WALK
	else:
		return Anim.IDLE


func _choose_attack() -> String:
	if combo_count >= 3:
		combo_count = 0
		return Anim.COMBO
	
	combo_count += 1
	return Anim.ATTACK


func _dodge():
	if dodge_cooldown <= 0:
		var dash_dir = -cam_pivot.global_transform.basis.z
		
		if is_moving:
			var input_vec = jzf_predicted_input
			var forward = -cam_pivot.global_transform.basis.z
			var right = cam_pivot.global_transform.basis.x
			dash_dir = (right * input_vec.x + forward * input_vec.y).normalized()
		
		velocity = dash_dir * 10.0
		dodge_cooldown = 0.5
		
		if anim.has_animation_safe(Anim.DODGE):
			anim.play_safe(Anim.DODGE, 0.05)


func _angle_difference(from: float, to: float) -> float:
	var diff := fmod(to - from, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return diff


func _on_animation_finished(anim_name: String):
	var attack_name = anim._find_animation(Anim.ATTACK)
	var combo_name = anim._find_animation(Anim.COMBO)
	var dodge_name = anim._find_animation(Anim.DODGE)
	
	if anim_name == attack_name or anim_name == combo_name:
		attacking = false
		if anim_name == combo_name:
			combo_count = 0
		anim.play_safe(Anim.IDLE, 0.2)
	
	if anim_name == dodge_name:
		anim.play_safe(Anim.IDLE, 0.1)


# ---- Public Methods ----
func set_combat_mode(enabled: bool):
	combat_mode = enabled
	if enabled:
		print("[AI] Combat Mode Activated")

func get_stats() -> Dictionary:
	return {
		"fluidity": fluidity_score,
		"straightness": jzf_straightness,
		"memory": movement_history.size(),
		"combo": combo_count
	}
