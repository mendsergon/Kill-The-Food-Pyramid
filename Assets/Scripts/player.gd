extends CharacterBody2D

# Defining constants for speeds, durations, and cooldowns
const SPEED = 150.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 800.0
const DASH_DURATION = 0.25
const DASH_COOLDOWN = 0.5

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var can_dash: bool = true
var ground_touched_since_dash: bool = true  # Flag for tracking if ground was touched after last dash

var input_direction: float = 0.0
var move_direction: float = 1.0  # Default facing right

var jump_after_dash: bool = false  # Flag for jumping right after dash ends

func _physics_process(delta: float) -> void:
	# Read horizontal input and update facing direction only if not dashing
	input_direction = Input.get_axis("move_left", "move_right")
	if not is_dashing and input_direction != 0.0:
		move_direction = sign(input_direction)

	# If player presses jump during dash on ground, set flag
	if is_dashing and Input.is_action_just_pressed("jump") and is_on_floor():
		jump_after_dash = true

	# Dash input: start dash only if can_dash is true
	if Input.is_action_just_pressed("dash") and can_dash:
		is_dashing = true
		dash_timer = DASH_DURATION
		can_dash = false
		ground_touched_since_dash = false  # Reset ground touch tracking on dash start
		velocity.y = 0.0  # Cancel vertical velocity on dash start
		jump_after_dash = false  # Reset jump flag when new dash starts

	# Dash logic: override movement and handle dash timer
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
			velocity += get_gravity() * delta

		# Jumping logic
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# Normal horizontal movement: no sliding on release
		if input_direction != 0.0:
			velocity.x = input_direction * SPEED
		else:
			velocity.x = 0.0  # Stop immediately when no input

	# Move the character according to velocity
	move_and_slide()

	# Track if the player has touched ground since the last dash ended
	if is_on_floor():
		ground_touched_since_dash = true

	# Only decrease cooldown timer if player touched ground after last dash
	if dash_cooldown_timer > 0.0 and ground_touched_since_dash:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		if dash_cooldown_timer == 0.0:
			can_dash = true

	# Handle animations based on state
	if is_dashing:
		animated_sprite_2d.play("Dash")
	else:
		if is_on_floor():
			if input_direction == 0.0:
				animated_sprite_2d.play("Idle")
			else:
				animated_sprite_2d.play("Run")
		else:
			animated_sprite_2d.play("Jump")

	# Flip sprite according to facing direction
	animated_sprite_2d.flip_h = move_direction < 0
