extends CharacterBody2D

### --- CONSTANTS ---
const MOVE_SPEED = 100.0                 # Speed of breadcrumb
const FLASH_DURATION = 0.1               # Red flash duration on damage
const DEATH_DURATION = 0.2               # Time before disappearing after death
const MAX_DISTANCE_FROM_PLAYER = 800.0   # Max distance before crumb despawns

### --- HEALTH ---
var health: int = 1                      # Breadcrumb only has 1 HP

### --- NODE REFERENCES ---
@onready var sprite_2d: Sprite2D = $Sprite2D

### --- STATE ---
var direction := Vector2.ZERO            # Direction locked at spawn
var flash_timer := 0.0
var death_timer := 0.0
var is_dying := false
var player: CharacterBody2D = null       # Reference to player

### --- PUBLIC SETUP ---
func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()

func set_player_reference(player_ref: CharacterBody2D) -> void:
	player = player_ref

func _ready() -> void:
	sprite_2d.modulate = Color(1, 1, 1)   # Ensure normal color on spawn

func _physics_process(delta: float) -> void:
	if is_dying:
		death_timer -= delta
		if death_timer <= 0.0:
			queue_free()
		return

	# Move in locked direction
	var collision = move_and_collide(direction * MOVE_SPEED * delta)
	if collision:
		var other = collision.get_collider()
		if other == player and other.has_method("apply_damage"):
			# Knockback based on actual positions at collision time
			var knockback_dir = (player.global_position - global_position).normalized()
			other.apply_damage(1, knockback_dir)
			die()

	# Despawn if too far from player
	if player and global_position.distance_to(player.global_position) > MAX_DISTANCE_FROM_PLAYER:
		queue_free()
		return

	# Flash effect on damage
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			sprite_2d.modulate = Color(1, 1, 1)

### --- DAMAGE & DEATH ---
func apply_damage(amount: int) -> void:
	health -= amount
	sprite_2d.modulate = Color(1, 0, 0)
	flash_timer = FLASH_DURATION
	if health <= 0:
		die()

func die() -> void:
	is_dying = true
	death_timer = DEATH_DURATION
	velocity = Vector2.ZERO
	collision_layer = 0  # Disable collisions
