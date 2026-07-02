extends Node3D
class_name GroundMaterial

# ============================================================================
# GROUND PHYSICS SETTINGS - TWEAK THESE!
# ============================================================================
@export var friction := 0.8
@export var restitution := 0.2
@export var hardness := 0.9

# ============================================================================
# FOOTSTEP SETTINGS - TWEAK THESE!
# ============================================================================
@export var enable_footsteps := true
@export var footstep_volume := 0.5
@export var footstep_speed := 1.0
@export var footstep_sound := "res://path/to/your/footstep_sound.wav"

# ============================================================================
# PARTICLE SETTINGS - TWEAK THESE!
# ============================================================================
@export var enable_particles := true
@export var particles_per_step := 5
@export var particle_velocity := 2.0
@export var particle_lifetime := 0.5
@export var particle_color := Color(0.9, 0.85, 0.7, 1.0)

# ============================================================================
# INTERNAL STATE
# ============================================================================
var last_footstep_time := 0.0
var footstep_interval := 0.4
var player_controller: JeremiahController
var audio_player: AudioStreamPlayer3D

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready():
	# Find the player controller in the scene
	player_controller = get_tree().root.find_child("JeremiahController", true, false) as JeremiahController
	
	if not player_controller:
		print("WARNING: GroundMaterial could not find JeremiahController!")
		return
	
	# Create audio player for footsteps
	if enable_footsteps:
		audio_player = AudioStreamPlayer3D.new()
		add_child(audio_player)
		audio_player.bus = &"Master"
		audio_player.volume_db = linear_to_db(footstep_volume)
	
	print("GroundMaterial initialized - Ground feels like hard sand!")

# ============================================================================
# MAIN UPDATE LOOP
# ============================================================================
func _process(delta):
	if not player_controller:
		return
	
	# Check if player is moving on ground
	if player_controller.is_character_moving() and player_controller.is_on_floor():
		_update_footsteps(delta)

# ============================================================================
# FOOTSTEP HANDLING
# ============================================================================
func _update_footsteps(delta: float):
	"""Handle footstep sounds and particles based on player movement"""
	last_footstep_time += delta
	
	# Calculate interval based on player speed
	var speed_ratio = player_controller.get_speed_ratio()
	var current_interval = footstep_interval / max(speed_ratio, 0.5)
	
	# Play footstep when interval is reached
	if last_footstep_time >= current_interval:
		_play_footstep()
		last_footstep_time = 0.0

# ============================================================================
# FOOTSTEP EFFECTS
# ============================================================================
func _play_footstep():
	"""Play footstep sound and particles at player position"""
	if not player_controller:
		return
	
	var player_pos = player_controller.global_position
	
	# Update audio player position and play sound
	if enable_footsteps and audio_player:
		audio_player.global_position = player_pos
		_play_footstep_sound()
	
	# Spawn particles
	if enable_particles:
		_spawn_ground_particles(player_pos)

# ============================================================================
# SOUND EFFECTS
# ============================================================================
func _play_footstep_sound():
	"""Play the footstep sound effect"""
	if not audio_player:
		return
	
	# If using the placeholder path, generate a simple beep instead
	if footstep_sound == "res://path/to/your/footstep_sound.wav":
		print("NOTE: Using placeholder. Set 'footstep_sound' to point to your footstep audio file!")
		return
	
	# Load and play the footstep sound
	var sound = load(footstep_sound)
	if sound:
		audio_player.stream = sound
		audio_player.pitch_scale = randf_range(0.8, 1.2)
		audio_player.play()
	else:
		print("ERROR: Could not load footstep sound: ", footstep_sound)

# ============================================================================
# PARTICLE EFFECTS
# ============================================================================
func _spawn_ground_particles(position: Vector3):
	"""Spawn sand-like particles at the footstep position"""
	if not enable_particles:
		return
	
	for i in range(particles_per_step):
		# Random spread direction
		var spread = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.2, 0.8),
			randf_range(-1.0, 1.0)
		).normalized()
		
		_create_ground_particle(position, spread)

func _create_ground_particle(position: Vector3, direction: Vector3):
	"""Create a single ground particle (small mesh that fades out)"""
	# Create a small sphere for the particle
	var particle = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.05
	sphere_mesh.height = 0.1
	particle.mesh = sphere_mesh
	
	# Create material for the particle
	var material = StandardMaterial3D.new()
	material.albedo_color = particle_color
	particle.material_override = material
	
	# Set position
	particle.global_position = position + Vector3.UP * 0.1
	
	# Add to scene
	add_child(particle)
	
	# Animate particle (fade and fall)
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move particle down and spread out
	tween.tween_property(particle, "global_position", 
		position + direction * particle_velocity + Vector3.DOWN * 0.5, 
		particle_lifetime)
	
	# Fade out
	var material_copy = material.duplicate()
	particle.material_override = material_copy
	tween.tween_property(material_copy, "albedo_color:a", 0.0, particle_lifetime)
	
	# Remove after animation
	await tween.finished
	particle.queue_free()

# ============================================================================
# PHYSICS MATERIAL CONFIGURATION
# ============================================================================
func configure_physics_body(body: PhysicsBody3D):
	"""Configure a physics body's material to feel like hard sand"""
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = friction
	physics_material.bounce = restitution
	
	# Apply to all colliders
	for child in body.get_children():
		if child is CollisionShape3D:
			child.physics_material_override = physics_material

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func set_friction(new_friction: float):
	"""Adjust ground friction at runtime"""
	friction = clamp(new_friction, 0.0, 1.0)

func set_hardness(new_hardness: float):
	"""Adjust ground hardness at runtime"""
	hardness = clamp(new_hardness, 0.0, 1.0)

func set_particle_color(color: Color):
	"""Change particle color"""
	particle_color = color

func enable_all_effects():
	"""Enable all ground effects"""
	enable_footsteps = true
	enable_particles = true

func disable_all_effects():
	"""Disable all ground effects"""
	enable_footsteps = false
	enable_particles = false

func get_material_name() -> String:
	"""Get ground material name"""
	return "Hard Sand Ground"
