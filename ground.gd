extends StaticBody3D
# This node provides BOTH:
# 1) The invisible physics floor (WorldBoundaryShape3D)
# 2) The blueprint-style visual grid floor (MeshInstance3D)
# They never interfere with each other.


# ---------------------------------------------------------
# SECTION 1 — EASY TRANSFORM CONTROLS FOR THE BOUNDARY
# ---------------------------------------------------------

@export var boundary_position := Vector3(0, 0, 0)
# Move the infinite physics plane up/down/sideways

@export var boundary_rotation := Vector3(0, 0, 0)
# Rotate the plane (useful if you want angled floors)

# NOTE: WorldBoundaryShape3D is infinite, so scaling does nothing.
# But you CAN scale the visual grid:
@export var grid_scale := Vector3(1, 1, 1)


# ---------------------------------------------------------
# SECTION 2 — GRID VISUAL SETTINGS (Blueprint Look)
# ---------------------------------------------------------

@export var grid_size := Vector2(50, 50)
# Total blueprint grid area

@export var grid_divisions := 20
# Number of grid lines

@export var grid_color := Color(0.0, 0.0, 0.0, 0.4)
# Blueprint blue with transparency

@export var grid_y_offset := 0.02
# Lift grid slightly above boundary to avoid z-fighting


func _ready():
	_make_boundary()  # Build the physics floor
	_make_grid()      # Build the blueprint visual floor


# ---------------------------------------------------------
# SECTION 3 — PHYSICS FLOOR (Infinite, Invisible)
# ---------------------------------------------------------

func _make_boundary():
	var collision := CollisionShape3D.new()
	var shape := WorldBoundaryShape3D.new()

	collision.shape = shape
	add_child(collision)

	# Apply user transform settings
	position = boundary_position
	rotation_degrees = boundary_rotation


# ---------------------------------------------------------
# SECTION 4 — BLUEPRINT VISUAL GRID (No Collision)
# ---------------------------------------------------------

func _make_grid():
	var grid := MeshInstance3D.new()
	grid.mesh = _build_grid_mesh()

	# Position grid slightly above the boundary
	grid.position.y = grid_y_offset

	# Apply user scaling
	grid.scale = grid_scale

	# Create blueprint-style material
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_cast_shadows = true
	mat.disable_receive_shadows = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = grid_color
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	grid.material_override = mat
	add_child(grid)


# ---------------------------------------------------------
# SECTION 5 — GRID MESH BUILDER
# ---------------------------------------------------------

func _build_grid_mesh() -> Mesh:
	var mesh := ImmediateMesh.new()

	var half_x := grid_size.x / 2
	var half_z := grid_size.y / 2

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for i in range(grid_divisions + 1):
		var t := float(i) / grid_divisions

		var x := -half_x + t * grid_size.x
		var z := -half_z + t * grid_size.y

		# Vertical line
		mesh.surface_set_color(grid_color)
		mesh.surface_add_vertex(Vector3(x, 0, -half_z))
		mesh.surface_set_color(grid_color)
		mesh.surface_add_vertex(Vector3(x, 0, half_z))

		# Horizontal line
		mesh.surface_set_color(grid_color)
		mesh.surface_add_vertex(Vector3(-half_x, 0, z))
		mesh.surface_set_color(grid_color)
		mesh.surface_add_vertex(Vector3(half_x, 0, z))

	mesh.surface_end()
	return mesh
