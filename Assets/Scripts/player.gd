extends CharacterBody2D

### --- CORE CONSTANTS --- ###
# Movement
const SPEED = 150.0                     # Normal movement speed
const JUMP_VELOCITY = -300.0            # Upward force when jumping
# Dash
const DASH_SPEED = 800.0                # Horizontal dash velocity
const DASH_DURATION = 0.25              # Time dash lasts 
const DASH_COOLDOWN = 0.5               # Delay between dashes
# Combat
const ATTACK_DURATION = 0.3             # How long attack locks movement  
const POST_ATTACK_NO_GRAVITY = 0.3      # Zero-gravity after aerial attacks

### --- PHYSICS --- ###
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity") # Gravity value

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D # Character sprite

### --- MOVEMENT STATE --- ###
var is_dashing := false                 # True during dash
var dash_timer := 0.0                   # Counts down dash duration
var dash_cooldown_timer := 0.0          # Time until next dash
var can_dash := true                    # Dash available
var ground_touched_since_dash := true   # Reset when landing
# Queued actions
var jump_after_dash := false            # Jump after dash ends
var attack_after_dash := false          # Attack after dash ends
var no_gravity_timer := 0.0             # Zero-gravity countdown

### --- INPUT TRACKING --- ###
var input_direction := 0.0              # Raw input 
var move_direction := 1.0               # Facing direction

### --- COMBAT STATE --- ###
var is_attacking := false               # During attack animation
var attack_timer := 0.0                 # Attack duration countdown
var current_attack_animation := ""      # "Swing_1" or "Swing_2"

func _physics_process(delta: float) -> void:
	### --- TIMER MANAGEMENT --- ###
	# Handle attack duration
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			current_attack_animation = ""
	
	# Handle zero-gravity period
	if no_gravity_timer > 0.0:
		no_gravity_timer -= delta

	### --- INPUT PROCESSING --- ###
	# Get horizontal input
	input_direction = Input.get_axis("move_left", "move_right")
	
	# Update facing direction when able
	if not is_dashing and not is_attacking and input_direction != 0.0:
		move_direction = sign(input_direction)

	### --- DASH ACTION QUEUEING --- ###
	if is_dashing:
		# Queue jump if pressed first (ground only)
		if Input.is_action_just_pressed("jump") and is_on_floor() and not attack_after_dash:
			jump_after_dash = true
		
		# Queue attack if pressed first (any state)
		if Input.is_action_just_pressed("melee") and not jump_after_dash:
			attack_after_dash = true

	### --- ACTION INITIATION --- ###
	# Start dash if available
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking:
		start_dash()

	# Normal ground attack
	if Input.is_action_just_pressed("melee") and is_on_floor() and not is_dashing and not is_attacking:
		start_attack()
		current_attack_animation = "Swing_1"

	### --- DASH PHYSICS --- ###
	if is_dashing:
		velocity.x = move_direction * DASH_SPEED
		velocity.y = 0.0 # Cancel gravity
		
		# End dash when timer expires
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			dash_cooldown_timer = DASH_COOLDOWN
			
			# Execute whichever action was queued first
			if jump_after_dash and is_on_floor():
				velocity.y = JUMP_VELOCITY
				jump_after_dash = false
			elif attack_after_dash:
				start_attack()
				current_attack_animation = "Swing_2"
				no_gravity_timer = POST_ATTACK_NO_GRAVITY
				attack_after_dash = false

	### --- REGULAR MOVEMENT --- ###
	else:
		# Apply gravity when applicable
		if not is_on_floor() and no_gravity_timer <= 0.0:
			velocity.y += gravity * delta

		# Standard jump
		if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
			velocity.y = JUMP_VELOCITY

		# Horizontal movement
		if not is_attacking:
			velocity.x = input_direction * SPEED if input_direction != 0.0 else 0.0

	### --- PHYSICS UPDATE --- ###
	move_and_slide()

	### --- GROUND STATE --- ###
	if is_on_floor():
		ground_touched_since_dash = true
		no_gravity_timer = 0.0 # Cancel zero-gravity

	### --- DASH RECHARGE --- ###
	update_dash_cooldown(delta)

	### --- ANIMATION SYSTEM --- ###
	update_animations()

	### --- SPRITE ORIENTATION --- ###
	animated_sprite_2d.flip_h = move_direction < 0

### --- DASH INITIALIZATION --- ###
func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	can_dash = false
	ground_touched_since_dash = false
	velocity.y = 0.0
	# Reset action queue
	jump_after_dash = false
	attack_after_dash = false

### --- ATTACK INITIALIZATION --- ###
func start_attack():
	is_attacking = true
	attack_timer = ATTACK_DURATION
	velocity.x = 0 # Freeze horizontal movement

### --- DASH COOLDOWN --- ###
func update_dash_cooldown(delta: float):
	if dash_cooldown_timer > 0.0 and ground_touched_since_dash:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		if dash_cooldown_timer == 0.0:
			can_dash = true

### --- ANIMATION CONTROLLER --- ###
func update_animations():
	# Priority system:
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
