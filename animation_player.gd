extends AnimationPlayer

var anim_cache: Dictionary = {}
var current_animation_name: String = ""
@export var blend_time: float = 0.15

func _ready() -> void:
	await get_tree().process_frame
	
	var names: PackedStringArray = get_animation_list()
	
	if names.is_empty():
		print("No animations found! Check your AnimationPlayer node.")
		return
	
	for name in names:
		anim_cache[name] = true
	
	print("=== AnimationPlayer Ready ===")
	print("Animations found (%d):" % names.size())
	for name in anim_cache.keys():
		print(" • ", name)

func play_safe(anim_name: String, custom_blend: float = -1.0) -> void:
	var actual := _find_animation(anim_name)
	
	if actual == "":
		print("⚠ Animation not found: ", anim_name)
		return
	
	if current_animation_name == actual and is_playing():
		return
	
	var blend: float = custom_blend if custom_blend >= 0.0 else blend_time
	
	play(actual, blend)
	current_animation_name = actual

func play_instant(anim_name: String) -> void:
	var actual := _find_animation(anim_name)
	if actual == "":
		print("⚠ Animation not found: ", anim_name)
		return
	play(actual)
	current_animation_name = actual

func crossfade_to(anim_name: String, duration: float = 0.2) -> void:
	var actual := _find_animation(anim_name)
	if actual == "":
		print("⚠ Animation not found: ", anim_name)
		return
	play(actual, duration)
	current_animation_name = actual

func _find_animation(anim_name: String) -> String:
	if anim_cache.has(anim_name):
		return anim_name
	
	var mixamo := anim_name + "/mixamo_com"
	if anim_cache.has(mixamo):
		return mixamo
	
	var folder := "Animations/Jeremiah/" + anim_name
	if anim_cache.has(folder):
		return folder
	
	var full := "Animations/Jeremiah/" + anim_name + "/mixamo_com"
	if anim_cache.has(full):
		return full
	
	return ""

func has_animation_safe(anim_name: String) -> bool:
	return _find_animation(anim_name) != ""

func get_animation_names() -> Array:
	return anim_cache.keys()

func get_current_animation_name() -> String:
	return current_animation_name

func is_animation_playing(anim_name: String) -> bool:
	return current_animation_name == _find_animation(anim_name) and is_playing()
