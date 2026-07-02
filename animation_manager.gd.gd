extends AnimationPlayer
class_name AnimationManager

# ============================================================================
# SIGNALS
# ============================================================================
signal anim_changed(old_anim: String, new_anim: String)
signal attack_finished()

# ============================================================================
# ANIMATION STATE
# ============================================================================
var current_anim: String = ""
var _is_attacking := false

# ============================================================================
# ANIMATION NAMES - Update these if your animations have different names!
# ============================================================================
const ANIM_IDLE := "Idle/mixamo_com"
const ANIM_WALK := "Walking/mixamo_com"
const ANIM_BACKWARDS := "Backwards/mixamo_com"
const ANIM_JUMP := "Jump/mixamo_com"
const ANIM_ATTACK := "Fist Fight A/mixamo_com"

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready():
	# Connect to animation finished signal
	animation_finished.connect(_on_any_animation_finished)
	
	# Configure loop modes for all animations
	for anim_name in get_animation_list():
		var anim = get_animation(anim_name)
		if anim:
			if anim_name == ANIM_ATTACK:
				# Attack should NOT loop - play once and stop
				anim.loop_mode = Animation.LOOP_NONE
			else:
				# All other animations loop
				anim.loop_mode = Animation.LOOP_LINEAR
	
	print("AnimationManager initialized with animations: ", get_animation_list())

# ============================================================================
# MAIN ANIMATION PLAYING FUNCTION
# ============================================================================
func play_anim(name: String) -> bool:
	"""
	Play an animation. Returns true if successful, false if blocked.
	"""
	if not has_animation(name):
		print("ERROR: Animation not found: ", name)
		return false
	
	# Don't interrupt the same animation
	if name == current_anim:
		return true
	
	# Don't interrupt attacks (except another attack)
	if _is_attacking and name != ANIM_ATTACK:
		return false
	
	# Switch animation
	var old_anim := current_anim
	current_anim = name
	
	play(name)
	anim_changed.emit(old_anim, current_anim)
	
	return true

# ============================================================================
# ANIMATION STATE CHECKERS
# ============================================================================

# Check if a specific animation is currently playing
func is_playing_anim(name: String) -> bool:
	return current_anim == name

# Check if currently attacking
func is_attacking() -> bool:
	return _is_attacking

# Check if any animation is playing
func is_animation_playing() -> bool:
	return is_playing()

# ============================================================================
# CONVENIENCE FUNCTIONS - Call these from player controller
# ============================================================================

func idle() -> bool:
	"""Play idle animation"""
	return play_anim(ANIM_IDLE)

func walk() -> bool:
	"""Play walking animation"""
	return play_anim(ANIM_WALK)

func backwards() -> bool:
	"""Play backwards walking animation"""
	return play_anim(ANIM_BACKWARDS)

func jump() -> bool:
	"""Play jumping animation"""
	return play_anim(ANIM_JUMP)

func attack() -> bool:
	"""Play attack animation (blocks other animations while playing)"""
	if _is_attacking:
		return false
	_is_attacking = true
	var result = play_anim(ANIM_ATTACK)
	if not result:
		_is_attacking = false
	return result

# ============================================================================
# CALLBACKS
# ============================================================================

# Called when ANY animation finishes
func _on_any_animation_finished(anim_name: String):
	if anim_name == ANIM_ATTACK:
		_is_attacking = false
		attack_finished.emit()
		print("Attack animation finished")

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Get the length/duration of the current animation
func get_animation_duration() -> float:
	if current_anim and has_animation(current_anim):
		return get_animation(current_anim).length
	return 0.0

# Get how far through the current animation we are (0.0 to 1.0)
func get_animation_progress() -> float:
	if not is_playing():
		return 0.0
	return get_current_animation_position() / get_animation_duration()

# Stop all animations
func stop_all():
	stop()
	current_anim = ""
	_is_attacking = false
	print("All animations stopped")
