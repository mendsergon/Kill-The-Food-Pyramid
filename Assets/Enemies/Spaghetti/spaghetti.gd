extends CharacterBody2D

### --- CORE CONSTANTS --- ###
const MOVE_SPEED = 65.0                  # Enemy walk speed
const MOVE_DURATION = 4.0                # Active chase time
const IDLE_COOLDOWN = 1.0                # Pause duration between chases
const SPAGH_SPAWN_INTERVAL = 1.0         # Seconds between spagh spawns
const FLASH_DURATION = 0.25              # Duration of red flash on damage
const STAGGER_DURATION = 0.1             # Time frozen after taking hit
const DEATH_DURATION = 0.5               # Time before removing dead spaghetti

### --- HEALTH --- ###
@export var max_health: int = 6          # Maximum HP for spaghetti
var health: int                           # Current HP

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D  # Enemy sprite
@export var spagh_scene: PackedScene = preload("res://Assets/Enemies/Spagh/spagh.tscn")                               

### --- STATE --- ###
var player: CharacterBody2D = null       # Reference to player node
var is_moving := true                    # Currently chasing player
var behavior_timer := 0.0                # Tracks chase/idle timing
var flash_timer := 0.0                   # Timer for red flash effect
var stagger_timer := 0.0                 # Timer to freeze movement briefly after hit
var death_timer := 0.0                   # Timer after death before deletion
var is_dying := false                    # Whether spaghetti is in death state

### --- SPAGH SHOOT TIMER --- ###
var spagh_timer := 0.0                   # Tracks time between spagh spawns

### --- PUBLIC SETUP --- ###
func set_player_reference(player_ref: CharacterBody2D) -> void:
	player = player_ref

func _ready() -> void:
	# Check if the spagh scene loaded properly
	if not spagh_scene:
		push_error("Spagh scene failed to load! Check the path: res://Assets/Enemies/Spagh/spagh.tscn")
	
	animated_sprite_2d.play("Run")         # Start with walking animation immediately
	health = max_health                    # Set starting HP

func _physics_process(delta: float) -> void:
	### --- DEATH TIMER --- ###
	if is_dying:
		death_timer -= delta
		if death_timer <= 0.0:
			queue_free()                  # Remove spaghetti after death delay
		return                            # Skip logic while dead

	if player == null:
		return

	### --- TIMER MANAGEMENT --- ###
	behavior_timer += delta
	if stagger_timer > 0.0:
		stagger_timer -= delta

	if is_moving and behavior_timer >= MOVE_DURATION:
		is_moving = false
		behavior_timer = 0.0
		animated_sprite_2d.play("Idle")
	elif not is_moving and behavior_timer >= IDLE_COOLDOWN:
		is_moving = true
		behavior_timer = 0.0
		animated_sprite_2d.play("Run")

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

	### --- SHOOT SPAGHS ONLY WHEN INSIDE PLAYER CAMERA VIEW --- ###
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		if is_instance_valid(camera):
			# Calculate the visible rectangle of the camera in world space
			var screen_size = camera.get_viewport_rect().size / camera.zoom
			var cam_rect = Rect2(
				camera.global_position - screen_size / 2,
				screen_size
			)

			# Only shoot if spaghetti is inside the visible camera rectangle
			if cam_rect.has_point(global_position):
				spagh_timer += delta
				if spagh_timer >= SPAGH_SPAWN_INTERVAL:
					spagh_timer = 0.0
					spawn_spagh()

	### --- PLAYER DAMAGE ON TOUCH --- ###
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var other = collision.get_collider()            # Get the collided object
		if other == player and other.has_method("apply_damage"):
			# Knockback direction points from enemy to player 
			other.apply_damage(1, (player.global_position - global_position).normalized())  # Deal 1 damage + knockback to player

	### --- RED FLASH ON DAMAGE --- ###
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			animated_sprite_2d.modulate = Color(1, 1, 1)  # Reset color to normal

### --- SPAWN FUNCTION --- ###
func spawn_spagh() -> void:
	if not spagh_scene:
		push_error("Spagh scene is not loaded!")
		return
	
	# Create the spagh instance
	var spagh = spagh_scene.instantiate()
	
	# Set position before adding to scene to avoid transform issues
	spagh.global_position = global_position
	
	# Scale spagh to 1/2 size
	if spagh.has_method("set_scale"):
		spagh.set_scale(Vector2(0.5, 0.5))
	elif spagh is Node2D:
		spagh.scale = Vector2(0.5, 0.5)
	elif spagh.has_node("Sprite2D"):
		spagh.get_node("Sprite2D").scale = Vector2(0.5, 0.5)
	
	# Set direction if needed
	if spagh.has_method("set_direction"):
		var direction = (player.global_position - global_position).normalized()
		spagh.set_direction(direction)
	
	# PASS PLAYER REFERENCE TO SPAGH
	if spagh.has_method("set_player_reference"):
		spagh.set_player_reference(player)
	
	# Add to scene tree
	get_tree().current_scene.add_child(spagh)

### --- DAMAGE & DEATH --- ###
func apply_damage(amount: int) -> void:
	health -= amount                                 # Subtract incoming damage
	print("Spaghetti took %d damage, %d HP remaining" % [amount, health])
	animated_sprite_2d.modulate = Color(1, 0, 0)     # Tint sprite red
	flash_timer = FLASH_DURATION                    # Start flash timer
	stagger_timer = STAGGER_DURATION                # Freeze movement briefly

	if health <= 0:
		die()

func die() -> void:
	is_dying = true                                  # Mark spaghetti as dying
	death_timer = DEATH_DURATION                     # Countdown before deletion
	animated_sprite_2d.modulate = Color(1, 0, 0)     # Turn red
	rotation_degrees = 90                            # Rotate 90 degrees
	velocity = Vector2.ZERO                          # Stop movement

	### --- MOVE TO PHYSICS LAYER 5 --- ###
	collision_layer = 1 << 4                         # Set to physics layer 5 (bit flag index 4)
