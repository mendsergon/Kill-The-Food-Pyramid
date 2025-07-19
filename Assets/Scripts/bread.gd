extends CharacterBody2D

### --- CORE CONSTANTS --- ###
const MOVE_SPEED = 75.0                  # Enemy walk speed
const MOVE_DURATION = 4.0                # Active chase time
const IDLE_COOLDOWN = 2.0                # Pause duration between chases

### --- HEALTH --- ###
@export var max_health: int = 3          # Maximum HP for bread
var health: int                          # Current HP

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D  # Enemy sprite

### --- STATE --- ###
var player: CharacterBody2D = null       # Reference to player node
var is_moving := true                    # Currently chasing player
var behavior_timer := 0.0                # Tracks chase/idle timing

### --- PUBLIC SETUP --- ###
func set_player_reference(player_ref: CharacterBody2D) -> void:
	player = player_ref

func _ready() -> void:
	animated_sprite_2d.play("Idle")
	health = max_health                    # Set starting HP

func _physics_process(delta: float) -> void:
	if player == null:
		return

	### --- TIMER MANAGEMENT --- ###
	behavior_timer += delta

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
	if is_moving:
		move_direction = (player.global_position - global_position).normalized()
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
			other.apply_damage(1, (player.global_position - global_position).normalized())         # Deal 1 damage + knockback to player

### --- DAMAGE & DEATH --- ###
func apply_damage(amount: int) -> void:
	health -= amount                                 # Subtract incoming damage
	print("Bread took %d damage, %d HP remaining" % [amount, health])
	if health <= 0:
		die()

func die() -> void:
	queue_free()                                     # Remove bread on death
