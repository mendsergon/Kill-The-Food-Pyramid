extends CharacterBody2D

# Constants
const SPEED = 150.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 800.0
const DASH_DURATION = 0.25
const DASH_COOLDOWN = 0.5
const ATTACK_DURATION = 0.3  
const POST_ATTACK_NO_GRAVITY = 0.3

# Gravity
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# Movement variables
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var can_dash := true
var ground_touched_since_dash := true
var jump_after_dash := false
var attack_after_dash := false
var no_gravity_timer := 0.0

# Input variables
var input_direction := 0.0
var move_direction := 1.0  

# Combat variables
var is_attacking := false
var attack_timer := 0.0
var current_attack_animation := ""  # Flag for current attack animation

func _physics_process(delta: float) -> void:
	# Update timers
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			current_attack_animation = ""
	
	if no_gravity_timer > 0.0:
		no_gravity_timer -= delta

	# Get input direction 
	input_direction = Input.get_axis("move_left", "move_right")
	if not is_dashing and not is_attacking and input_direction != 0.0:
		move_direction = sign(input_direction)

	# Handle inputs during dash
	if is_dashing:
		if Input.is_action_just_pressed("jump") and is_on_floor():
			jump_after_dash = true
			attack_after_dash = false
		
		if Input.is_action_just_pressed("melee"):
			if is_on_floor():
				if not jump_after_dash:
					attack_after_dash = true
			else:
				attack_after_dash = true

	# Handle dash input
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking:
		start_dash()

	# Handle normal attack input
	if Input.is_action_just_pressed("melee") and is_on_floor() and not is_dashing and not is_attacking:
		start_attack()
		current_attack_animation = "Swing_1"

	# Dash logic 
	if is_dashing:
		velocity.x = move_direction * DASH_SPEED
		velocity.y = 0.0
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			dash_cooldown_timer = DASH_COOLDOWN
			
			if jump_after_dash and is_on_floor():
				velocity.y = JUMP_VELOCITY
				jump_after_dash = false
			elif attack_after_dash:
				start_attack()
				current_attack_animation = "Swing_2"
				no_gravity_timer = POST_ATTACK_NO_GRAVITY
				attack_after_dash = false
	else:
		if not is_on_floor() and no_gravity_timer <= 0.0:
			velocity.y += gravity * delta

		if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
			velocity.y = JUMP_VELOCITY

		if not is_attacking:
			if input_direction != 0.0:
				velocity.x = input_direction * SPEED
			else:
				velocity.x = 0.0

	# Move the character
	move_and_slide()

	# Update ground touch tracking
	if is_on_floor():
		ground_touched_since_dash = true
		no_gravity_timer = 0.0

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
	velocity.y = 0.0
	jump_after_dash = false
	attack_after_dash = false

func start_attack():
	is_attacking = true
	attack_timer = ATTACK_DURATION
	velocity.x = 0

func update_dash_cooldown(delta: float):
	if dash_cooldown_timer > 0.0 and ground_touched_since_dash:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		if dash_cooldown_timer == 0.0:
			can_dash = true

func update_animations():
	if is_attacking and current_attack_animation != "":
		animated_sprite_2d.play(current_attack_animation)
	elif is_dashing:
		animated_sprite_2d.play("Dash")
	elif not is_on_floor():
		animated_sprite_2d.play("Jump")
	elif input_direction != 0.0:
		animated_sprite_2d.play("Run")
	else:
		animated_sprite_2d.play("Idle")
