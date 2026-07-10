extends Skeleton3D
class_name JeremiahSkelly

# ============================================================
# ADVANCED BONE MEMORY SYSTEM v2.1 (Godot 4.6.3 FIXED)
# Stores rotation memory with weighted importance and trends
# ============================================================

var head_bone := -1
var spine_bone := -1
var neck_bone := -1

var memory: Dictionary = {}           # Stores memory per bone
var memory_limit := 15
var min_change_threshold := 0.01      # Ignore tiny movements

# ============================================================
# READY — runs once when skeleton loads
# ============================================================

func _ready():
	print("JeremiahSkelly v2.1 active. Bone count:", get_bone_count())
	
	# Smart bone discovery with fallbacks
	head_bone = _find_bone_smart("head")
	spine_bone = _find_bone_smart("spine")
	neck_bone = _find_bone_smart("neck")
	
	# Fallback if spine not found
	if spine_bone == -1 and neck_bone != -1:
		spine_bone = neck_bone
		print("Using neck as spine fallback")
	
	# Initialize memory arrays
	for bone in [head_bone, spine_bone]:
		if bone != -1:
			memory[bone] = []
	
	_validate_bones()

# ============================================================
# PROCESS — runs every frame
# ============================================================

func _process(delta):
	for bone in memory.keys():
		var rot := get_bone_global_pose(bone).basis.get_euler().y
		
		# Only store meaningful changes
		if memory[bone].is_empty() or abs(rot - memory[bone][-1]) > min_change_threshold:
			_store(bone, rot)

# ============================================================
# STORE MEMORY — weighted storage with trend detection
# ============================================================

func _store(bone: int, value: float) -> void:
	var bone_memory: Array = memory[bone]
	bone_memory.append(value)
	
	if bone_memory.size() > memory_limit:
		bone_memory.pop_front()
	
	# Auto-clean if stable
	if bone_memory.size() > 3 and _is_stable(bone_memory):
		bone_memory.resize(3)

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

func _is_stable(arr: Array) -> bool:
	if arr.size() < 2:
		return false
	
	var first: float = arr[0]
	for val in arr:
		if abs(val - first) > 0.001:
			return false
	
	return true

func get_memory(bone_name: String) -> Array:
	var bone := _find_bone_smart(bone_name)
	if bone != -1 and memory.has(bone):
		return memory[bone].duplicate()
	return []

func get_trend(bone_name: String) -> float:
	var mem := get_memory(bone_name)
	if mem.size() < 2:
		return 0.0
	return mem[-1] - mem[0]

func clear_memory():
	for bone in memory.keys():
		memory[bone].clear()

# ============================================================
# SMART BONE FINDER — enhanced with multiple name patterns
# ============================================================

func _find_bone_smart(target: String) -> int:
	var t := target.to_lower()
	var variations := {
		"head": ["head", "skull", "cranium"],
		"spine": ["spine", "hip", "pelvis", "root"],
		"neck": ["neck", "shoulder", "clavicle"]
	}
	
	var patterns: Array = variations.get(t, [t])
	
	for i in range(get_bone_count()):
		var name := get_bone_name(i).to_lower()
		for pattern in patterns:
			if pattern in name:
				return i
	
	return -1

func _validate_bones():
	var found := 0
	for bone in [head_bone, spine_bone]:
		if bone != -1:
			found += 1
	
	print("Found ", found, "/3 target bones")
	if found < 2:
		print("WARNING: Missing important bones - functionality may be limited")
