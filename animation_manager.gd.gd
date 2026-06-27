extends AnimationPlayer
class_name AnimationManager

signal anim_changed(old_anim: String, new_anim: String)  # Renamed to avoid conflict
signal attack_finished()

var current_anim: String = ""
var _is_attacking := false

# Animation constants
const ANIM_IDLE := "Idle/mixamo_com"
const ANIM_WALK := "Walking/mixamo_com"
const ANIM_BACKWARDS := "Backwards/mixamo_com"
const ANIM_JUMP := "Jump/mixamo_com"
const ANIM_ATTACK := "Fist Fight A/mixamo_com"

func _ready():
	animation_finished.connect(_on_any_animation_finished)
	
	# Set all animations to proper loop mode
	for anim_name in get_animation_list():
		var anim = get_animation(anim_name)
		if anim:
			if anim_name == ANIM_ATTACK:
				anim.loop_mode = Animation.LOOP_NONE
			else:
				anim.loop_mode = Animation.LOOP_LINEAR

func play_anim(name: String) -> bool:
	if not has_animation(name):
		print("Animation not found:", name)
		return false
	
	if name == current_anim:
		return true
	
	# If playing attack, don't interrupt (except for another attack)
	if _is_attacking and name != ANIM_ATTACK:
		return false
	
	var old_anim := current_anim
	current_anim = name
	
	play(name)
	anim_changed.emit(old_anim, current_anim)  # Using renamed signal
	
	return true

func is_playing_anim(name: String) -> bool:
	return current_anim == name

func is_attacking() -> bool:
	return _is_attacking

# Convenience functions
func idle() -> bool:
	return play_anim(ANIM_IDLE)

func walk() -> bool:
	return play_anim(ANIM_WALK)

func backwards() -> bool:
	return play_anim(ANIM_BACKWARDS)

func jump() -> bool:
	return play_anim(ANIM_JUMP)

func attack() -> bool:
	if _is_attacking:
		return false
	_is_attacking = true
	var result = play_anim(ANIM_ATTACK)
	if not result:
		_is_attacking = false
	return result

func _on_any_animation_finished(anim_name: String):
	if anim_name == ANIM_ATTACK:
		_is_attacking = false
		attack_finished.emit()

# Get current animation speed (for blending)
func get_animation_speed() -> float:
	if current_anim and has_animation(current_anim):
		return get_animation(current_anim).length
	return 0.0

# Check if currently playing (redundant but clear)
func is_animation_playing() -> bool:
	return is_playing()
