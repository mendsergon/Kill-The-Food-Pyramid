extends CharacterBody2D

### --- CORE CONSTANTS --- ###
const MOVE_SPEED = 75.0                  # Enemy walk speed
const MOVE_DURATION = 4.0                # Active chase time
const IDLE_COOLDOWN = 0.5                # Pause duration between chases
const FLASH_DURATION = 0.25              # Duration of red flash on damage
const STAGGER_DURATION = 0.1             # Time frozen after taking hit
const DEATH_DURATION = 0.5               # Time before removing dead bread

### --- HEALTH & STATE MACHINE --- ###
@export var max_health: int = 400        # King Bread has 400 HP
var health: int                          # Current HP
enum HealthState { HEALTH_100, HEALTH_75, HEALTH_50, HEALTH_25 }
var current_health_state: HealthState = HealthState.HEALTH_100

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@export var breadcrumb_scene: PackedScene = preload("res://Assets/Enemies/Bread Cramb/bread_cramb.tscn")

### --- STATE --- ###
var player: CharacterBody2D = null       # Reference to player node
var is_moving := true                    # Currently chasing player
var behavior_timer := 0.0                # Tracks chase/idle timing
var flash_timer := 0.0                   # Timer for red flash effect
var stagger_timer := 0.0                 # Timer to freeze movement briefly after hit
var death_timer := 0.0                   # Timer after death before deletion
var is_dying := false                    # Whether bread is in death state

### --- ANIMATION STATE TRACKING --- ###
var current_animation_state := "Run"     # Track whether we're in "Idle" or "Run" state

### --- BREADCRUMB BURST SYSTEM --- ###
var breadcrumb_timer := 0.0              # Tracks time between breadcrumb bursts
const BREADCRUMB_BURST_COOLDOWN = 2.0    # Reduced cooldown between burst attempts
const BREADCRUMB_BURST_COUNT = 3         # Number of breadcrumbs per burst
const BREADCRUMB_BURST_INTERVAL = 0.3    # Time between breadcrumbs in a burst
var current_burst_count := 0             # Current breadcrumbs fired in burst
var burst_timer := 0.0                   # Timer between breadcrumbs in burst
var is_bursting := false                 # Whether currently in burst mode

### --- DASH ATTACK SYSTEM --- ###
var dash_timer := 0.0                    # Timer for dash attack
const DASH_COOLDOWN = 2.5                # Reduced cooldown between dash attempts
const DASH_TRIGGER_DISTANCE = 200.0      # Distance to trigger dash
const DASH_PREP_DURATION = 0.5           # Increased prep time to allow for turning
const DASH_CHARGE_DURATION = 0.75        # Dash movement time
const DASH_SPEED = 300.0                 # Dash movement speed (faster)
const DASH_ROTATION_SPEED = 720.0        # Degrees per second when dashing
const DASH_TURN_SPEED = 2.0              # Speed of directional adjustment during prep
const DASH_WINDUP_ROTATION = 30.0        # How much to rotate back during windup
var is_dashing := false                  # Whether currently dashing
var dash_phase := "none"                 # "prep" or "charge"
var dash_direction := Vector2.ZERO       # Direction of dash
var target_dash_direction := Vector2.ZERO # Target direction for dash
var original_rotation := 0.0             # Store original rotation for windup

### --- MOVEMENT MODES --- ###
enum MovementMode { DIRECT, CIRCULAR }
var current_movement_mode: MovementMode = MovementMode.DIRECT
var circular_movement_timer := 0.0
const CIRCULAR_MOVEMENT_DURATION = 1.5   # Reduced circular movement duration

### --- ATTACK COOLDOWN MANAGEMENT --- ###
var attack_cooldown_timer := 0.0
const ATTACK_COOLDOWN = 0.8              # Minimum time between starting different attacks

### --- PUBLIC SETUP --- ###
func set_player_reference(player_ref: CharacterBody2D) -> void:
	player = player_ref

func _ready() -> void:
	health = max_health                    # Set starting HP
	update_health_state()                  # Initialize health state
	update_animation_based_on_health()     # Set initial animation based on health
	
	# Check if the breadcrumb scene loaded properly
	if not breadcrumb_scene:
		push_error("Breadcrumb scene failed to load! Check the path: res://Assets/Enemies/Bread Cramb/bread_cramb.tscn")

func _physics_process(delta: float) -> void:
	### --- DEATH TIMER --- ###
	if is_dying:
		death_timer -= delta
		if death_timer <= 0.0:
			queue_free()                  # Remove bread after death delay
		return                            # Skip logic while dead

	if player == null:
		return

	### --- UPDATE HEALTH STATE --- ###
	update_health_state()

	### --- RED FLASH ON DAMAGE (MUST BE PROCESSED IN ALL STATES) --- ###
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			animated_sprite_2d.modulate = Color(1, 1, 1)  # Reset color to normal

	### --- TIMER MANAGEMENT --- ###
	behavior_timer += delta
	if stagger_timer > 0.0:
		stagger_timer -= delta
	
	### --- ATTACK COOLDOWN --- ###
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	### --- INDEPENDENT ATTACK SYSTEMS --- ###
	# Breadcrumb burst system
	if not is_bursting and attack_cooldown_timer <= 0.0:
		breadcrumb_timer += delta
		if breadcrumb_timer >= BREADCRUMB_BURST_COOLDOWN and is_in_camera_view() and not is_dashing:
			start_breadcrumb_burst()

	# Dash attack system
	if not is_dashing and attack_cooldown_timer <= 0.0:
		dash_timer += delta
		var distance_to_player = global_position.distance_to(player.global_position)
		if dash_timer >= DASH_COOLDOWN and distance_to_player <= DASH_TRIGGER_DISTANCE and not is_bursting:
			start_dash_attack()

	### --- HANDLE ACTIVE ATTACKS --- ###
	if is_bursting:
		handle_breadcrumb_burst(delta)
	
	if is_dashing:
		handle_dash_attack(delta)
		return  # Skip normal movement during dash

	### --- NORMAL BEHAVIOR --- ###
	if is_moving and behavior_timer >= MOVE_DURATION:
		is_moving = false
		behavior_timer = 0.0
		current_animation_state = "Idle"
		update_animation_based_on_health()
	elif not is_moving and behavior_timer >= IDLE_COOLDOWN:
		is_moving = true
		behavior_timer = 0.0
		current_animation_state = "Run"
		update_animation_based_on_health()

	### --- MOVEMENT LOGIC --- ###
	var move_direction = Vector2.ZERO
	if is_moving and stagger_timer <= 0.0:
		if current_movement_mode == MovementMode.DIRECT or is_bursting:
			# Direct movement toward player
			move_direction = (player.global_position - global_position).normalized()
		else:
			# Circular movement around player
			move_direction = calculate_circular_movement()
		
		velocity = move_direction * MOVE_SPEED

		if abs(move_direction.x) > abs(move_direction.y):
			animated_sprite_2d.flip_h = move_direction.x < 0
	else:
		velocity = Vector2.ZERO

	### --- APPLY MOVEMENT --- ###
	move_and_slide()

	### --- PLAYER DAMAGE ON TOUCH --- ###
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var other = collision.get_collider()            # Get the collided object
		if other == player and other.has_method("apply_damage"):
			# Knockback direction points from enemy to player 
			other.apply_damage(1, (player.global_position - global_position).normalized())

### --- HEALTH STATE MANAGEMENT --- ###
func update_health_state() -> void:
	var health_percent = float(health) / float(max_health) * 100
	
	var new_state: HealthState
	if health_percent > 75:
		new_state = HealthState.HEALTH_100
	elif health_percent > 50:
		new_state = HealthState.HEALTH_75
	elif health_percent > 25:
		new_state = HealthState.HEALTH_50
	else:
		new_state = HealthState.HEALTH_25
	
	if new_state != current_health_state:
		current_health_state = new_state
		# Future: Add state-specific behavior changes here
		print("King Bread health state changed to: ", current_health_state)

### --- HEALTH-BASED ANIMATION --- ###
func update_animation_based_on_health() -> void:
	var animation_suffix = "100"  # Default
	
	match current_health_state:
		HealthState.HEALTH_100:
			animation_suffix = "100"
		HealthState.HEALTH_75:
			animation_suffix = "75"
		HealthState.HEALTH_50:
			animation_suffix = "50"
		HealthState.HEALTH_25:
			animation_suffix = "25"
	
	var new_animation = current_animation_state + " " + animation_suffix
	
	# Only change animation if it's different from current
	if animated_sprite_2d.animation != new_animation:
		animated_sprite_2d.play(new_animation)

### --- BREADCRUMB BURST SYSTEM --- ###
func start_breadcrumb_burst() -> void:
	is_bursting = true
	current_burst_count = 0
	burst_timer = 0.0
	breadcrumb_timer = 0.0
	current_movement_mode = MovementMode.CIRCULAR
	circular_movement_timer = CIRCULAR_MOVEMENT_DURATION
	attack_cooldown_timer = ATTACK_COOLDOWN  # Set cooldown after starting attack

func handle_breadcrumb_burst(delta: float) -> void:
	burst_timer -= delta
	circular_movement_timer -= delta
	
	if burst_timer <= 0.0:
		spawn_breadcrumb()
		current_burst_count += 1
		burst_timer = BREADCRUMB_BURST_INTERVAL
	
	if current_burst_count >= BREADCRUMB_BURST_COUNT:
		is_bursting = false
		current_movement_mode = MovementMode.DIRECT

### --- DASH ATTACK SYSTEM --- ###
func start_dash_attack() -> void:
	is_dashing = true
	dash_phase = "prep"
	dash_timer = DASH_PREP_DURATION
	velocity = Vector2.ZERO
	current_animation_state = "Idle"
	update_animation_based_on_health()
	
	# Set initial dash direction and target direction
	dash_direction = (player.global_position - global_position).normalized()
	target_dash_direction = dash_direction
	
	# Store original rotation for windup effect
	original_rotation = rotation_degrees
	
	# Change color to indicate windup (orange/yellow tint)
	animated_sprite_2d.modulate = Color(1, 0.8, 0.3)
	
	attack_cooldown_timer = ATTACK_COOLDOWN  # Set cooldown after starting attack

func handle_dash_attack(delta: float) -> void:
	dash_timer -= delta

	if dash_phase == "prep":
		# Gradually turn toward player during preparation
		if player:
			target_dash_direction = (player.global_position - global_position).normalized()
			# Smoothly interpolate toward target direction
			dash_direction = dash_direction.slerp(target_dash_direction, DASH_TURN_SPEED * delta)
		
		# Windup effect: rotate back and forth to indicate charging
		var windup_progress = 1.0 - (dash_timer / DASH_PREP_DURATION)
		var windup_rotation = sin(windup_progress * PI * 4) * DASH_WINDUP_ROTATION
		rotation_degrees = original_rotation + windup_rotation
		
		if dash_timer <= 0.0:
			dash_phase = "charge"
			dash_timer = DASH_CHARGE_DURATION
			current_animation_state = "Run"
			update_animation_based_on_health()
			
			# Reset color for the actual dash
			animated_sprite_2d.modulate = Color(1, 1, 1)

	elif dash_phase == "charge":
		# Spin backwards while moving in the locked dash direction
		rotation_degrees -= DASH_ROTATION_SPEED * delta
		velocity = dash_direction * DASH_SPEED
		move_and_slide()

		# Damage player if collided during dash
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var other = collision.get_collider()
			if other == player and other.has_method("apply_damage"):
				other.apply_damage(1, dash_direction)

		if dash_timer <= 0.0:
			is_dashing = false
			rotation_degrees = 0
			velocity = Vector2.ZERO
			dash_timer = 0.0  # Reset for cooldown

### --- CIRCULAR MOVEMENT --- ###
func calculate_circular_movement() -> Vector2:
	var direction_to_player = (player.global_position - global_position).normalized()
	# Create perpendicular direction for circling
	var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
	# Combine forward and perpendicular movement for circling
	return (direction_to_player * 0.7 + perpendicular * 0.3).normalized()

### --- CAMERA CHECK --- ###
func is_in_camera_view() -> bool:
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		if is_instance_valid(camera):
			# Calculate the visible rectangle of the camera in world space
			var screen_size = camera.get_viewport_rect().size / camera.zoom
			var cam_rect = Rect2(
				camera.global_position - screen_size / 2,
				screen_size
			)
			# Only return true if king bread is inside the visible camera rectangle
			return cam_rect.has_point(global_position)
	return false

### --- BREADCRUMB SPAWNING --- ###
func spawn_breadcrumb() -> void:
	if not breadcrumb_scene:
		push_error("Breadcrumb scene is not loaded!")
		return
	
	# Create the breadcrumb instance
	var crumb = breadcrumb_scene.instantiate()
	
	# Set position before adding to scene to avoid transform issues
	crumb.global_position = global_position
	
	# Scale breadcrumb to 1/2 size
	if crumb.has_method("set_scale"):
		crumb.set_scale(Vector2(0.5, 0.5))
	elif crumb is Node2D:
		crumb.scale = Vector2(0.5, 0.5)
	elif crumb.has_node("Sprite2D"):
		crumb.get_node("Sprite2D").scale = Vector2(0.5, 0.5)
	
	# Set direction if needed
	if crumb.has_method("set_direction"):
		var direction = (player.global_position - global_position).normalized()
		crumb.set_direction(direction)
	
	# PASS PLAYER REFERENCE TO BREADCRUMB
	if crumb.has_method("set_player_reference"):
		crumb.set_player_reference(player)
	
	# Add to scene tree
	get_tree().current_scene.add_child(crumb)

### --- DAMAGE & DEATH --- ###
func apply_damage(amount: int) -> void:
	health -= amount                                 # Subtract incoming damage
	print("King Bread took %d damage, %d HP remaining" % [amount, health])
	animated_sprite_2d.modulate = Color(1, 0, 0)     # Tint sprite red
	flash_timer = FLASH_DURATION                    # Start flash timer
	stagger_timer = STAGGER_DURATION                # Freeze movement briefly
	
	# Update animation based on new health value
	update_health_state()
	update_animation_based_on_health()

	if health <= 0:
		die()

func die() -> void:
	is_dying = true                                  # Mark bread as dying
	death_timer = DEATH_DURATION                     # Countdown before deletion
	animated_sprite_2d.modulate = Color(1, 0, 0)     # Turn red
	rotation_degrees = 90                            # Rotate 90 degrees
	velocity = Vector2.ZERO                          # Stop movement

	### --- MOVE TO PHYSICS LAYER 5 --- ###
	collision_layer = 1 << 4                         # Set to physics layer 5 (bit flag index 4)
