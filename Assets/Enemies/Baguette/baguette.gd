extends CharacterBody2D

### --- CORE CONSTANTS --- ###
const MOVE_SPEED = 50.0                  # Enemy walk speed
const MOVE_DURATION = 4.0                # Active chase time (when not detected)
const IDLE_COOLDOWN = 0.5                # Pause duration between chases (when not detected)
const BREADCRUMB_SPAWN_INTERVAL = 2.0    # Seconds between breadcrumb spawns
const FLASH_DURATION = 0.25              # Duration of red flash on damage
const STAGGER_DURATION = 0.1             # Time frozen after taking hit
const DEATH_DURATION = 0.5               # Time before removing dead baguette

### --- HEALTH --- ###
@export var max_health: int = 5          # Maximum HP for baguette
var health: int                          # Current HP

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D  # Enemy sprite
@onready var area_2d: Area2D = $Area2D
@export var breadcrumb_scene: PackedScene = preload("res://Assets/Enemies/Bread Cramb/bread_cramb.tscn")                               

### --- STATE --- ###
var player: CharacterBody2D = null       # Reference to player node
var detection_manager: Node = null       # Reference to manager (main scene)
var is_moving := false                   # Currently chasing player
var behavior_timer := 0.0                # Tracks chase/idle timing (for non-detected state)
var flash_timer := 0.0                   # Timer for red flash effect
var stagger_timer := 0.0                 # Timer to freeze movement briefly after hit
var death_timer := 0.0                   # Timer after death before deletion
var is_dying := false                    # Whether baguette is in death state
var player_detected_locally := false     # Local detection state (from Area2D)

### --- BREADCRUMB SHOOT TIMER --- ###
var breadcrumb_timer := 0.0              # Tracks time between breadcrumb spawns

### --- PUBLIC SETUP --- ###
func set_player_reference(player_ref: CharacterBody2D, manager_ref: Node) -> void:
	player = player_ref
	detection_manager = manager_ref

func _ready() -> void:
	# Check if the breadcrumb scene loaded properly
	if not breadcrumb_scene:
		push_error("Breadcrumb scene failed to load! Check the path: res://Assets/Enemies/Bread Cramb/bread_cramb.tscn")
	
	animated_sprite_2d.play("Idle")        # Start with idle animation
	health = max_health                    # Set starting HP
	

func _physics_process(delta: float) -> void:
	### --- DEATH TIMER --- ###
	if is_dying:
		death_timer -= delta
		if death_timer <= 0.0:
			queue_free()                  # Remove baguette after death delay
		return                            # Skip logic while dead

	### --- SHARED DETECTION CHECK --- ###
	if player == null or (not detection_manager.player_detected and not player_detected_locally):
		velocity = Vector2.ZERO
		if not is_dying:
			animated_sprite_2d.play("Idle")
		player_detected_locally = false  # Reset local detection if player leaves
		return

	### --- TIMER MANAGEMENT (ONLY WHEN NOT LOCALLY DETECTED) --- ###
	if not player_detected_locally:
		behavior_timer += delta
		if stagger_timer > 0.0:
			stagger_timer -= delta

		# Timer-based behavior (only when not locally detected)
		if is_moving and behavior_timer >= MOVE_DURATION:
			is_moving = false
			behavior_timer = 0.0
		elif not is_moving and behavior_timer >= IDLE_COOLDOWN:
			is_moving = true
			behavior_timer = 0.0
	else:
		# Immediate attack when player is locally detected
		is_moving = true
		behavior_timer = 0.0

	### --- SET APPROPRIATE ANIMATION --- ###
	if is_moving:
		animated_sprite_2d.play("Run")
	else:
		animated_sprite_2d.play("Idle")

	### --- MOVEMENT LOGIC --- ###
	var move_direction = Vector2.ZERO
	if is_moving and stagger_timer <= 0.0:
		move_direction = (player.global_position - global_position).normalized()
		velocity = move_direction * MOVE_SPEED

		if abs(move_direction.x) > abs(move_direction.y):
			animated_sprite_2d.flip_h = move_direction.x < 0
	else:
		velocity = Vector2.ZERO

	### --- APPLY MOVEMENT --- ###
	move_and_slide()

	### --- SHOOT BREADCRUMBS ONLY WHEN INSIDE PLAYER CAMERA VIEW --- ###
	var camera = player.get_node("Camera2D") if player and player.has_node("Camera2D") else null
	if camera and is_instance_valid(camera):
		# Calculate the visible rectangle of the camera in world space
		var screen_size = camera.get_viewport_rect().size / camera.zoom
		var cam_rect = Rect2(
			camera.global_position - screen_size / 2,
			screen_size
		)

		# Only shoot if baguette is inside the visible camera rectangle
		if cam_rect.has_point(global_position):
			breadcrumb_timer += delta
			if breadcrumb_timer >= BREADCRUMB_SPAWN_INTERVAL:
				breadcrumb_timer = 0.0
				spawn_breadcrumb()

	### --- PLAYER DAMAGE ON TOUCH --- ###
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var other = collision.get_collider()            # Get the collided object
		if other == player and other.has_method("apply_damage"):
			# Knockback direction points from enemy to player 
			other.apply_damage(1, (player.global_position - global_position).normalized())         # Deal 1 damage + knockback to player

	### --- RED FLASH ON DAMAGE --- ###
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			animated_sprite_2d.modulate = Color(1, 1, 1)  # Reset color to normal

### --- AREA2D SIGNAL HANDLERS --- ###
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == player:
		# ✅ tell the manager that the player has been spotted
		detection_manager.set_player_detected(true)
		
		# ✅ Set local detection for immediate response
		player_detected_locally = true

		# ✅ force baguette to chase immediately
		is_moving = true
		behavior_timer = 0.0
		animated_sprite_2d.play("Run")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == player:
		# Reset local detection when player leaves area
		player_detected_locally = false

### --- SPAWN FUNCTION --- ###
func spawn_breadcrumb() -> void:
	if not breadcrumb_scene:
		push_error("Breadcrumb scene is not loaded!")
		return
	
	# Create the breadcrumb instance
	var crumb = breadcrumb_scene.instantiate()
	
	# Set position before adding to scene to avoid transform issues
	crumb.global_position = global_position
	
	# Scale breadcrumb to 1/4 size
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
	
	# Add to scene tree - use the scene root instead of parent to avoid issues
	get_tree().current_scene.add_child(crumb)


### --- DAMAGE & DEATH --- ###
func apply_damage(amount: int) -> void:
	health -= amount                                 # Subtract incoming damage
	print("Baguette took %d damage, %d HP remaining" % [amount, health])
	animated_sprite_2d.modulate = Color(1, 0, 0)     # Tint sprite red
	flash_timer = FLASH_DURATION                    # Start flash timer
	stagger_timer = STAGGER_DURATION                # Freeze movement briefly

	if health <= 0:
		die()

func die() -> void:
	is_dying = true                                  # Mark baguette as dying
	death_timer = DEATH_DURATION                     # Countdown before deletion
	animated_sprite_2d.modulate = Color(1, 0, 0)     # Turn red
	rotation_degrees = 90                            # Rotate 90 degrees
	velocity = Vector2.ZERO                          # Stop movement

	### --- MOVE TO PHYSICS LAYER 5 --- ###
	collision_layer = 1 << 4   # Set to physics layer 5 (bit flag index 4) 
