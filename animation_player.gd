extends AnimationPlayer
class_name JeremiahAnimator

# ============================================================
# EXPORTS
# ============================================================

@export var blend_time: float = 0.15
@export var animation_speed: float = 1.0
@export var self_blend_time: float = 0.1

@export var blend_times: Dictionary = {
	"Idle_to_Walk": 0.15, "Walk_to_Idle": 0.15,
	"Idle_to_Back": 0.15, "Back_to_Idle": 0.15,
	"Idle_to_Jump": 0.1,  "Jump_to_Idle": 0.1,
	"Walk_to_Back": 0.2,  "Back_to_Walk": 0.2,
	"Walk_to_Jump": 0.1,  "Jump_to_Walk": 0.1,
	"Back_to_Jump": 0.1,  "Jump_to_Back": 0.1,
	"Idle_to_Fist Fight A": 0.05, "Walk_to_Fist Fight A": 0.05,
	"Back_to_Fist Fight A": 0.05, "Jump_to_Fist Fight A": 0.05,
	"Fist Fight A_to_Idle": 0.2, "Fist Fight A_to_Walk": 0.15,
	"Fist Fight A_to_Back": 0.15, "Fist Fight A_to_Jump": 0.1
}

# ============================================================
# STATE
# ============================================================

var anim_cache: Dictionary = {}
var current: String = ""
var previous: String = ""
var attack_finished_callback: Callable
var _self_blend_active := false

const PREFIXES := ["", "Animations/Jeremiah/"]
const SUFFIXES := ["", "/mixamo_com"]

const Anim := {
	IDLE = "Idle",
	WALK = "Walk",
	BACK = "Back",
	JUMP = "Jump",
	ATTACK = "Fist Fight A"
}

# ============================================================
# READY
# ============================================================

func _ready():
	await get_tree().process_frame

	for name in get_animation_list():
		anim_cache[name] = true

	print("JeremiahAnimator loaded:", anim_cache.keys())

# ============================================================
# PLAY SAFE
# ============================================================

func play_safe(name: String, blend: float = -1.0, allow_self_blend: bool = false) -> void:
	var resolved := _resolve(name)
	if resolved == "":
		return

	# Self-blend logic
	if current == resolved and is_playing() and allow_self_blend:
		_self_blend(resolved, blend)
		return

	previous = current
	current = resolved

	var actual_blend := blend if blend >= 0.0 else _get_blend(previous, resolved)

	speed_scale = animation_speed
	play(resolved, actual_blend)
	_self_blend_active = false

# ============================================================
# SELF-BLEND
# ============================================================

func _self_blend(anim: String, blend: float = -1.0) -> void:
	var actual_blend := blend if blend >= 0.0 else self_blend_time

	var current_time := get_current_animation_position()
	var current_speed := speed_scale

	stop()
	play(anim, actual_blend)
	seek(current_time, true)

	speed_scale = current_speed
	_self_blend_active = true

# ============================================================
# RESTART AFTER ATTACK
# ============================================================

func restart_after_attack() -> void:
	if current == _resolve(Anim.ATTACK):
		_self_blend(current, 0.05)

# ============================================================
# BLEND TIME RESOLVER
# ============================================================

func _get_blend(from: String, to: String) -> float:
	var key := "%s_to_%s" % [from, to]
	return blend_times.get(key, blend_times.get("%s_to_%s" % [to, from], blend_time))

# ============================================================
# RESOLVE ANIMATION NAME
# ============================================================

func _resolve(name: String) -> String:
	if anim_cache.has(name):
		return name

	for p in PREFIXES:
		for s in SUFFIXES:
			var full :String= p + name + s
			if anim_cache.has(full):
				return full

	var ln := name.to_lower()
	for c in anim_cache.keys():
		var lc :String= c.to_lower()
		if lc == ln or ln in lc:
			return c

	return ""

# ============================================================
# UTILITY
# ============================================================

func get_current() -> String:
	return current

func get_previous() -> String:
	return previous

func has_anim(name: String) -> bool:
	return _resolve(name) != ""

func set_speed(speed: float) -> void:
	animation_speed = speed
	speed_scale = speed

func blend_to_idle(blend: float = -1.0) -> void:
	play_safe(Anim.IDLE, blend)

# ============================================================
# QUEUE ANIMATION
# ============================================================

func queue_animation(name: String, blend: float = -1.0, allow_self_blend: bool = false) -> void:
	animation_finished.connect(
		func(): play_safe(name, blend, allow_self_blend),
		CONNECT_ONE_SHOT
	)

# ============================================================
# DEBUG
# ============================================================

func debug() -> void:
	print("=== JeremiahAnimator Debug ===")
	print("Current:", current)
	print("Previous:", previous)
	print("Blend time:", blend_time)
	print("Self-blend time:", self_blend_time)
	print("Self-blend active:", _self_blend_active)
	print("Speed:", speed_scale)
	print("==============================")
