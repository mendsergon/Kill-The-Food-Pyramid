extends CharacterBody2D

### --- CORE CONSTANTS --- ###
# Movement
const SPEED = 150.0                     # Normal movement speed
# Dash
const DASH_SPEED = 450.0                # Dash velocity
const DASH_DURATION = 0.25              # Time dash lasts 
const DASH_COOLDOWN = 0.5               # Delay between dashes
# Combat
const ATTACK_DURATION = 0.3             # How long attack locks movement  
# Collision
const IGNORE_LAYER_3_MASK = ~(1 << 2)   # Mask to ignore layer 3 (bit 2)
const LAYER_3_MASK = (1 << 2)           # Mask only layer 3 (bit 2)

### --- PLAYER HEALTH --- ###
@export var max_health: int = 3         # Maximum HP for player
var health: int                          # Current HP

### --- INVULNERABILITY --- ###
const INVULN_DURATION := 1.0            # Seconds invulnerable after hit
var invuln_timer := 0.0                 # Invulnerability countdown
var is_invulnerable := false            # True while invulnerable

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D # Character sprite
@onready var pistol_1: Node2D = $"Pistol 1" # Pistol node
@onready var melee_area: Area2D = $MeleeArea2D # Melee hit area

### --- MOVEMENT STATE --- ###
var is_dashing := false                 # True during dash
var dash_timer := 0.0                   # Counts down dash duration
var dash_cooldown_timer := 0.0          # Time until next dash
var can_dash := true                    # Dash available
# Queued actions
var attack_after_dash := false          # Attack after dash ends

### --- INPUT TRACKING --- ###
var move_direction := Vector2.ZERO      # Combined movement input
var aim_direction := Vector2.RIGHT      # Current mouse aim direction

### --- LOCKED DIRECTION --- ###
var is_direction_locked := false        # True while dash/attack in progress
var locked_aim_direction := Vector2.RIGHT  # Stored direction at action start

### --- COMBAT STATE --- ###
var is_attacking := false               # During attack animation
var attack_timer := 0.0                 # Attack duration countdown
var current_attack_animation := ""      # Attack animation name

### --- COLLISION MASK STATE --- ###
var original_collision_mask := 0        # Stores default collision mask
var original_collision_layer := 0       # Stores default collision layer  

func _ready() -> void:
	# Initialize health and disable melee area until needed
	health = max_health                     # Set starting HP
	melee_area.monitoring = false
	melee_area.visible = false
	melee_area.connect("body_entered", Callable(self, "_on_melee_area_body_entered"))
	# Store initial collision mask and layer
	original_collision_mask = collision_mask
	original_collision_layer = collision_layer

func _physics_process(delta: float) -> void:
	### --- INVULNERABILITY TIMER --- ###
	if is_invulnerable:
		invuln_timer -= delta
		if invuln_timer <= 0.0:
			is_invulnerable = false

	### --- INPUT PROCESSING --- ###
	# Get combined movement input (4-directional)
	move_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Get mouse position for aiming
	_update_aim_direction()
	
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
			# Unlock look direction at end of attack
			is_direction_locked = false

	### --- ACTION INITIATION --- ###
	# Start dash if available
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking:
		start_dash()
		# Lock look direction at dash start
		locked_aim_direction = aim_direction
		is_direction_locked = true

	# Queue melee **during** dash → Swing_2
	if is_dashing and Input.is_action_just_pressed("melee"):  
		attack_after_dash = true                              

	# Normal attack
	if Input.is_action_just_pressed("melee") and not is_dashing and not is_attacking:
		start_attack()
		current_attack_animation = "Swing_1"
		_enable_melee()
		# Lock look direction at attack start
		locked_aim_direction = aim_direction
		is_direction_locked = true

	### --- DASH PHYSICS --- ###
	if is_dashing:
		# End dash when timer expires
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			dash_cooldown_timer = DASH_COOLDOWN
			collision_mask = original_collision_mask  # Restore collisions
			collision_layer = original_collision_layer
			
			# Execute queued attack
			if attack_after_dash:
				start_attack()
				current_attack_animation = "Swing_2"
				_enable_melee()
				attack_after_dash = false
				# Lock look direction for the queued attack
				locked_aim_direction = aim_direction
				is_direction_locked = true

	### --- REGULAR MOVEMENT --- ###
	else:
		# Apply movement if not attacking
		if not is_attacking:
			velocity = move_direction * SPEED

	### --- PHYSICS UPDATE --- ###
	move_and_slide()

	### --- DASH RECHARGE --- ###
	update_dash_cooldown(delta)

	### --- ANIMATION SYSTEM --- ###
	update_animations()

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

	### --- SPRITE ORIENTATION --- ###
	# Rotate to face locked mouse direction during dash or melee, otherwise reset and flip on movement
	if is_dashing or is_attacking:
		# Use the stored direction, not live aim
		var dir = locked_aim_direction
		animated_sprite_2d.rotation = dir.angle()                  # Rotate sprite to face mouse
		# Wrap rotation to keep within 0–360 degrees
		animated_sprite_2d.rotation_degrees = wrap(animated_sprite_2d.rotation_degrees, 0, 360)  
		# Flip vertically when facing left (between 90° and 270°)
		if animated_sprite_2d.rotation_degrees > 90 and animated_sprite_2d.rotation_degrees < 270:
			animated_sprite_2d.scale.y = -1                       # Mirror sprite on Y axis
		else:
			animated_sprite_2d.scale.y = 1                        # Default upward scale
		animated_sprite_2d.flip_h = false                         # Disable horizontal flip while rotated
	else:
		# Reset rotation and scale when not in those actions
		animated_sprite_2d.rotation = 0
		animated_sprite_2d.scale.y = 1
		# Horizontal flip based on movement direction
		if move_direction.x != 0:
			animated_sprite_2d.flip_h = move_direction.x < 0

func _update_aim_direction() -> void:
	# Calculate direction to mouse position
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()

func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	can_dash = false
	velocity = aim_direction * DASH_SPEED
	collision_mask &= IGNORE_LAYER_3_MASK  # Ignore layer 3 during dash
	collision_layer = LAYER_3_MASK         # Change to ghost layer
	
	# Queue attack if pressed during dash
	if Input.is_action_just_pressed("melee"):
		attack_after_dash = true
	else:
		attack_after_dash = false

func start_attack():
	is_attacking = true
	attack_timer = ATTACK_DURATION
	velocity = Vector2.ZERO  # Freeze movement during attack

func _enable_melee():
	# Position melee area in aim direction
	melee_area.position = aim_direction * 20
	melee_area.monitoring = true
	melee_area.visible = true

func _on_melee_area_body_entered(body: Node) -> void:
	# Deal 3 HP melee damage if possible
	if body.has_method("apply_damage"):
		body.apply_damage(3)
	print("Melee hit:", body.name)

func update_dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		if dash_cooldown_timer == 0.0:
			can_dash = true

func update_animations() -> void:
	if is_attacking and current_attack_animation != "":
		animated_sprite_2d.play(current_attack_animation)
	elif is_dashing:
		animated_sprite_2d.play("Dash")
	elif move_direction.length() > 0.1:  # Moving
		animated_sprite_2d.play("Run")
	else:
		animated_sprite_2d.play("Idle")

### --- DAMAGE & DEATH --- ###
func apply_damage(amount: int) -> void:
	# Subtract incoming damage if not invulnerable
	if is_invulnerable:
		return
	health -= amount
	is_invulnerable = true
	invuln_timer = INVULN_DURATION        # Start invulnerability
	print("Player took %d damage, %d HP remaining" % [amount, health])
	
	# Check for death
	if health <= 0:
		die()

func die() -> void:
	# Handle player death 
	queue_free()
