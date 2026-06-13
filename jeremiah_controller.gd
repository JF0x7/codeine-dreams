extends CharacterBody3D

@export var speed := 4.0
@export var acceleration := 10.0
@export var rotation_speed := 10.0 # Controls how fast the character turns

@onready var anim_tree: AnimationTree = $Jeremiah/AnimationTree

# We declare the variable here, but assign it in _ready() to prevent null pointer crashes
var anim_state: AnimationNodeStateMachinePlayback

func _ready() -> void:
	# Safely initialize the animation playback state machine
	if anim_tree:
		anim_state = anim_tree.get("parameters/playback")
		anim_tree.active = true # Forces the tree to be active when the game starts

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Handle Movement and Transitions
	if direction.length() > 0.1:
		velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)

		# Smoothly rotate the character toward the movement direction
		var target_transform := global_transform.looking_at(global_transform.origin + direction, Vector3.UP)
		global_transform = global_transform.interpolate_with(target_transform, rotation_speed * delta)

		# Switch to Walk animation (Ensure this matches your lowercase/uppercase graph names!)
		if anim_state:
			anim_state.travel("walk")
	else:
		velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, acceleration * delta)

		# Switch to Idle animation (Ensure this matches your lowercase/uppercase graph names!)
		if anim_state:
			anim_state.travel("idle")

	move_and_slide()
