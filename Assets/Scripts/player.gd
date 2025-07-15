extends CharacterBody2D

### --- CORE CONSTANTS --- ###
# Movement
const SPEED = 150.0                     # Normal movement speed
const JUMP_VELOCITY = -260.0           # Upward force when jumping
# Dash
const DASH_SPEED = 800.0               # Horizontal dash velocity
const DASH_DURATION = 0.25             # Time dash lasts 
const DASH_COOLDOWN = 0.5              # Delay between dashes
# Combat
const ATTACK_DURATION = 0.3            # How long attack locks movement  
const POST_ATTACK_NO_GRAVITY = 0.3     # Zero-gravity after aerial attacks
# Jump tuning
const JUMP_HOLD_GRAVITY = 400.0        # Reduced gravity when jump held
const FALL_GRAVITY_MULTIPLIER = 1.5    # Faster falling when descending

### --- PHYSICS --- ###
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity") # Gravity value

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D # Character sprite
@onready var pistol_1: Node2D = $"Pistol 1" # Pistol node
@onready var melee_area: Area2D = $MeleeArea2D # Melee hit area

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
var is_jump_button_held := false        # Jump button held state

### --- COMBAT STATE --- ###
var is_attacking := false               # During attack animation
var attack_timer := 0.0                 # Attack duration countdown
var current_attack_animation := ""     # "Swing_1" or "Swing_2"

func _ready() -> void:
	# Disable melee area until needed
	melee_area.monitoring = false
	melee_area.visible = false
	melee_area.connect("body_entered", Callable(self, "_on_melee_area_body_entered"))

func _physics_process(delta: float) -> void:
	### --- TIMER MANAGEMENT --- ###
	# Handle attack duration
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			current_attack_animation = ""
			# Disable melee hit detection
			melee_area.monitoring = false
			melee_area.visible = false

	# Handle zero-gravity period
	if no_gravity_timer > 0.0:
		no_gravity_timer -= delta

	### --- INPUT PROCESSING --- ###
	# Get horizontal input
	input_direction = Input.get_axis("move_left", "move_right")
	# Track jump hold
	is_jump_button_held = Input.is_action_pressed("jump")

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

	# Normal attack (ground or air)
	if Input.is_action_just_pressed("melee") and not is_dashing and not is_attacking:
		start_attack()
		current_attack_animation = "Swing_1"
		# Enable melee area
		_enable_melee()
		# Lock vertical movement during air attacks
		if not is_on_floor():
			velocity.y = 0
			no_gravity_timer = ATTACK_DURATION

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
				_enable_melee()
				no_gravity_timer = POST_ATTACK_NO_GRAVITY
				attack_after_dash = false

	### --- REGULAR MOVEMENT --- ###
	else:
		# Dynamic gravity for jump/fall
		if not is_on_floor() and no_gravity_timer <= 0.0:
			if velocity.y < 0: # Going up
				if is_jump_button_held:
					velocity.y += JUMP_HOLD_GRAVITY * delta # Light gravity while holding
				else:
					velocity.y += gravity * delta # Full gravity if released early
			else:
				velocity.y += gravity * FALL_GRAVITY_MULTIPLIER * delta # Faster fall

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

	### --- SPRITE & MELEE ORIENTATION --- ###
	# Determine horizontal aim direction (left/right only)
	var aim_dir = sign(get_global_mouse_position().x - global_position.x)
	if aim_dir == 0:
		aim_dir = move_direction
	# Flip sprite
	if is_dashing:
		animated_sprite_2d.flip_h = move_direction < 0
	else:
		animated_sprite_2d.flip_h = aim_dir < 0
	# Flip melee area
	melee_area.scale.x = aim_dir

	### --- WEAPON STATE --- ###
	# Hide and disable pistol during dash or melee
	if is_dashing or is_attacking:
		pistol_1.visible = false
		pistol_1.set_process(false)
		pistol_1.set_process_input(false)
	else:
		pistol_1.visible = true
		pistol_1.set_process(true)
		pistol_1.set_process_input(true)

### --- DASH INITIALIZATION --- ###
func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	can_dash = false
	ground_touched_since_dash = false
	velocity.y = 0.0
	# If no input, dash toward cursor direction
	if input_direction == 0:
		var dir = sign(get_global_mouse_position().x - global_position.x)
		if dir != 0:
			move_direction = dir
	# Reset action queue
	jump_after_dash = false
	attack_after_dash = false

### --- ATTACK INITIALIZATION --- ###
func start_attack():
	is_attacking = true
	attack_timer = ATTACK_DURATION
	velocity.x = 0 # Freeze horizontal movement

### --- ENABLE MELEE AREA & DEBUG --- ###
func _enable_melee():
	melee_area.monitoring = true
	melee_area.visible = true

func _on_melee_area_body_entered(body: Node) -> void:
	print("Melee hit:", body.name)

### --- DASH COOLDOWN --- ###
func update_dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer > 0.0 and ground_touched_since_dash:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		if dash_cooldown_timer == 0.0:
			can_dash = true

### --- ANIMATION CONTROLLER --- ###
func update_animations() -> void:
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
#test
