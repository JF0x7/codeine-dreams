extends Skeleton3D
class_name JeremiahSkelly

# ============================================================
# BASIC BONE MEMORY SYSTEM
# Stores recent rotations of head + spine bones.
# No smoothing, no prediction — just raw memory.
# ============================================================

var head_bone := -1
var spine_bone := -1

var memory: Array[float] = []        # Stores recent head rotations
var memory_limit := 10               # Max number of stored samples

# ============================================================
# READY — runs once when skeleton loads
# ============================================================

func _ready():
	print("JeremiahSkelly active. Bone count:", get_bone_count())

	# Automatically find bones by partial name (case-insensitive)
	head_bone = _find_bone_smart("head")
	spine_bone = _find_bone_smart("spine")

	if head_bone == -1:
		print("WARNING: Head bone not found!")
	if spine_bone == -1:
		print("WARNING: Spine bone not found!")

# ============================================================
# PROCESS — runs every frame
# ============================================================

func _process(delta):
	# Read head rotation (Y axis)
	if head_bone != -1:
		var rot := get_bone_global_pose(head_bone).basis.get_euler().y
		_store(rot)

# ============================================================
# STORE MEMORY — keeps last N rotations
# ============================================================

func _store(value: float) -> void:
	memory.append(value)
	if memory.size() > memory_limit:
		memory.pop_front()

# ============================================================
# SMART BONE FINDER — finds bones by partial name
# Works with Mixamo, Unity, Blender, Unreal rigs
# ============================================================

func _find_bone_smart(target: String) -> int:
	var t := target.to_lower()
	for i in get_bone_count():
		var name := get_bone_name(i).to_lower()
		if t in name:
			return i
	return -1
