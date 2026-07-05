extends Node3D

@export var size := Vector2(50, 50)      # total grid area
@export var divisions := 20              # number of grid lines
@export var grid_color := Color(0.3, 0.4, 0.3, 0.3)
@export var y_offset := 0.01             # tiny offset to avoid z-fighting

func _ready():
	_make_grid()

func _make_grid():
	var grid := MeshInstance3D.new()
	grid.mesh = _build_grid_mesh()

	# Place grid exactly on your world boundary floor
	grid.position.y = y_offset

	var mat := StandardMaterial3D.new()

	# Prevent grid from drawing over Jeremiah
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY

	grid.material_override = mat
	add_child(grid)

func _build_grid_mesh() -> Mesh:
	var mesh := ImmediateMesh.new()

	var half_x := size.x / 2
	var half_z := size.y / 2

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for i in range(divisions + 1):
		var t := float(i) / divisions

		var x := -half_x + t * size.x
		var z := -half_z + t * size.y

		# Vertical lines
		mesh.surface_set_color(grid_color)
		mesh.surface_add_vertex(Vector3(x, 0, -half_z))
		mesh.surface_set_color(grid_color)
		mesh.surface_add_vertex(Vector3(x, 0, half_z))

		# Horizontal lines
		mesh.surface_set_color(grid_color)
		mesh.surface_add_vertex(Vector3(-half_x, 0, z))
		mesh.surface_set_color(grid_color)
		mesh.surface_add_vertex(Vector3(half_x, 0, z))

	mesh.surface_end()
	return mesh
