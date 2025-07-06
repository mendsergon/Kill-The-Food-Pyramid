extends CharacterBody2D

# Defining constants
const SPEED = 150.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 800.0
const DASH_DURATION = 0.25
const DASH_COOLDOWN = 0.5
const ATTACK_DURATION = 0.2  # 4 frames at 20 FPS

# Get gravity from project settings
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# Movement variables
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var can_dash := true
var ground_touched_since_dash := true
var jump_after_dash := false

# Input variables
var input_direction := 0.0
var move_direction := 1.0  # Default facing right

# Combat variables
var is_attacking := false
var attack_timer := 0.0

func _physics_process(delta: float) -> void:
	# Update attack timer
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			animated_sprite_2d.play("Idle")

	# Get input direction (only if not attacking or dashing)
	input_direction = Input.get_axis("move_left", "move_right")
	if not is_dashing and not is_attacking and input_direction != 0.0:
		move_direction = sign(input_direction)

	# If player presses jump during dash on ground, set flag
	if is_dashing and Input.is_action_just_pressed("jump") and is_on_floor():
		jump_after_dash = true

	# Handle dash input
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking:
		start_dash()

	# Handle attack input
	if Input.is_action_just_pressed("melee") and is_on_floor() and not is_dashing and not is_attacking:
		start_attack()

	# Dash logic (EXACTLY as you had it)
	if is_dashing:
		velocity.x = move_direction * DASH_SPEED
		velocity.y = 0.0  # Lock vertical movement during dash
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			dash_cooldown_timer = DASH_COOLDOWN  # Start cooldown after dash ends
			
			# If jump was pressed during dash on ground, jump immediately now
			if jump_after_dash and is_on_floor():
				velocity.y = JUMP_VELOCITY
				jump_after_dash = false  # reset flag
	else:
		# Apply gravity if not on floor
		if not is_on_floor():
			velocity.y += gravity * delta

		# Jumping logic (only if not attacking)
		if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
			velocity.y = JUMP_VELOCITY

		# Normal horizontal movement (no sliding on release)
		if not is_attacking:
			if input_direction != 0.0:
				velocity.x = input_direction * SPEED
			else:
				velocity.x = 0.0  # Stop immediately when no input

	# Move the character
	move_and_slide()

	# Update ground touch tracking
	if is_on_floor():
		ground_touched_since_dash = true

	# Handle dash cooldown
	update_dash_cooldown(delta)

	# Update animations
	update_animations()

	# Flip sprite according to facing direction
	animated_sprite_2d.flip_h = move_direction < 0

func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	can_dash = false
	ground_touched_since_dash = false
	velocity.y = 0.0  # Cancel vertical velocity on dash start
	jump_after_dash = false  # Reset jump flag when new dash starts

func start_attack():
	is_attacking = true
	attack_timer = ATTACK_DURATION
	animated_sprite_2d.play("Swing_1")
	velocity.x = 0  # Stop horizontal movement during attack

func update_dash_cooldown(delta: float):
	if dash_cooldown_timer > 0.0 and ground_touched_since_dash:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		if dash_cooldown_timer == 0.0:
			can_dash = true

func update_animations():
	if is_attacking:
		return  # Let the attack animation play through
	elif is_dashing:
		animated_sprite_2d.play("Dash")
	elif not is_on_floor():
		animated_sprite_2d.play("Jump")
	elif input_direction != 0.0:
		animated_sprite_2d.play("Run")
	else:
		animated_sprite_2d.play("Idle")
