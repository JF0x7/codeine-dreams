extends AnimationPlayer
class_name JeremiahAnimator

# ============================================================
# EXPORTS
# ============================================================

@export var blend_time: float = 0.15
@export var animation_speed: float = 1.0
@export var blend_times: Dictionary = {
	"Idle_to_Walk": 0.15, "Idle_to_Back": 0.15, "Idle_to_Jump": 0.1, "Idle_to_Fist Fight A": 0.05,
	"Walk_to_Idle": 0.15, "Walk_to_Back": 0.2, "Walk_to_Jump": 0.1, "Walk_to_Fist Fight A": 0.05,
	"Back_to_Idle": 0.15, "Back_to_Walk": 0.2, "Back_to_Jump": 0.1, "Back_to_Fist Fight A": 0.05,
	"Jump_to_Idle": 0.1, "Jump_to_Walk": 0.1, "Jump_to_Back": 0.1, "Jump_to_Fist Fight A": 0.05,
	"Fist Fight A_to_Idle": 0.2, "Fist Fight A_to_Walk": 0.15, "Fist Fight A_to_Back": 0.15, "Fist Fight A_to_Jump": 0.1,
}

# ============================================================
# STATE
# ============================================================

var anim_cache := {}
var current := ""
var previous := ""
var attack_finished_callback: Callable

const PREFIXES := ["", "Animations/Jeremiah/"]
const SUFFIXES := ["", "/mixamo_com"]
const Anim = {IDLE="Idle", WALK="Walk", BACK="Back", JUMP="Jump", ATTACK="Fist Fight A"}

# ============================================================
# READY
# ============================================================

func _ready():
	await get_tree().process_frame
	for name in get_animation_list(): anim_cache[name] = true
	print("✅ Loaded:", anim_cache.keys())

# ============================================================
# PLAY - Smart Blending
# ============================================================

func play_safe(name: String, blend: float = -1.0) -> void:
	var resolved := _resolve(name)
	if resolved == "" or (current == resolved and is_playing()): return
	
	previous = current
	current = resolved
	
	var actual_blend := blend if blend >= 0.0 else _get_blend(previous, resolved)
	speed_scale = animation_speed
	play(resolved, actual_blend)

# ============================================================
# RESTART AFTER ATTACK - Call this from controller
# ============================================================

func restart_after_attack() -> void:
	# Force restart current animation to reset blend
	if current == _resolve(Anim.ATTACK):
		stop()
		play(current, 0.05)

# ============================================================
# GET BLEND TIME
# ============================================================

func _get_blend(from: String, to: String) -> float:
	var key := "%s_to_%s" % [from, to]
	return blend_times.get(key, blend_times.get("%s_to_%s" % [to, from], blend_time))

# ============================================================
# RESOLVE ANIMATION
# ============================================================

func _resolve(name: String) -> String:
	if anim_cache.has(name): return name
	for p in PREFIXES:
		for s in SUFFIXES:
			var full :String= p + name + s
			if anim_cache.has(full): return full
	for c in anim_cache.keys():
		var lc :String= c.to_lower()
		var ln := name.to_lower()
		if lc == ln or ln in lc: return c
	return ""

# ============================================================
# UTILITY
# ============================================================

func get_current() -> String: return current
func get_previous() -> String: return previous
func has_anim(name: String) -> bool: return _resolve(name) != ""
func set_speed(speed: float) -> void: animation_speed = speed; speed_scale = speed
func blend_to_idle(blend: float = -1.0) -> void: play_safe(Anim.IDLE, blend)

# ============================================================
# QUEUE ANIMATION
# ============================================================

func queue_animation(name: String, blend: float = -1.0) -> void:
	animation_finished.connect(func(): play_safe(name, blend), CONNECT_ONE_SHOT)

# ============================================================
# DEBUG
# ============================================================

func debug() -> void:
	print("=== BLEND DEBUG ===")
	print("Current:", current, "| Previous:", previous)
	print("Blend time:", blend_time)
	print("Speed:", speed_scale)
	print("===================")
