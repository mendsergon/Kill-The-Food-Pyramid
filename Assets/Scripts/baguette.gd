extends CharacterBody2D

### --- CORE CONSTANTS --- ###
const MOVE_SPEED = 50.0                  # Enemy walk speed
const STOP_DISTANCE = 50.0               # Distance to stop from player
const REACTIVATION_DISTANCE = 80.0       # Distance player must move away before chasing again
const IDLE_COOLDOWN = 2.0                # Pause duration between chases
const FLASH_DURATION = 0.25              # Duration of red flash on damage
const STAGGER_DURATION = 0.1             # Time frozen after taking hit
const DEATH_DURATION = 0.5               # Time before removing dead baguette

### --- HEALTH --- ###
@export var max_health: int = 5          # Maximum HP for baguette
var health: int                          # Current HP

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D  # Enemy sprite

### --- STATE --- ###
var player: CharacterBody2D = null       # Reference to player node
var is_moving := true                    # Currently chasing player
var idle_timer := 0.0                    # Timer for idle phase
var flash_timer := 0.0                   # Timer for red flash effect
var stagger_timer := 0.0                 # Timer to freeze movement briefly after hit
var death_timer := 0.0                   # Timer after death before deletion
var is_dying := false                    # Whether baguette is in death state
var last_stop_position: Vector2          # Position of player when enemy last stopped

### --- PUBLIC SETUP --- ###
func set_player_reference(player_ref: CharacterBody2D) -> void:
	player = player_ref

func _ready() -> void:
	animated_sprite_2d.play("Idle")
	health = max_health                    # Set starting HP

func _physics_process(delta: float) -> void:
	### --- DEATH TIMER --- ###
	if is_dying:
		death_timer -= delta
		if death_timer <= 0.0:
			queue_free()                  # Remove baguette after death delay
		return                            # Skip logic while dead

	if player == null:
		return

	### --- TIMER MANAGEMENT --- ###
	if stagger_timer > 0.0:
		stagger_timer -= delta

	### --- MOVEMENT LOGIC WITH STOP DISTANCE --- ###
	var dist_to_player = global_position.distance_to(player.global_position)

	if is_moving and stagger_timer <= 0.0:
		if dist_to_player > STOP_DISTANCE:
			# Chase the player
			var move_direction = (player.global_position - global_position).normalized()
			velocity = move_direction * MOVE_SPEED

			if abs(move_direction.x) > abs(move_direction.y):
				animated_sprite_2d.flip_h = move_direction.x < 0

			animated_sprite_2d.play("Run")
		else:
			# Stop when close enough
			is_moving = false
			idle_timer = IDLE_COOLDOWN
			last_stop_position = player.global_position
			velocity = Vector2.ZERO
			animated_sprite_2d.play("Idle")
	else:
		# Idle phase
		velocity = Vector2.ZERO
		idle_timer -= delta
		if idle_timer <= 0.0:
			# Reactivate only if player moved far enough
			if player.global_position.distance_to(last_stop_position) > REACTIVATION_DISTANCE:
				is_moving = true
			else:
				idle_timer = IDLE_COOLDOWN  # Wait another cycle

	### --- APPLY MOVEMENT --- ###
	move_and_slide()

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
	collision_layer = 1 << 4                         # Set to physics layer 5 (bit flag index 4)
