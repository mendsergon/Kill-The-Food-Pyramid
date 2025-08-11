extends CharacterBody2D

const MOVE_SPEED = 100.0
const FLASH_DURATION = 0.1
const DEATH_DURATION = 0.2

var health: int = 1

@onready var sprite_2d: Sprite2D = $Sprite2D

var direction := Vector2.ZERO
var flash_timer := 0.0
var death_timer := 0.0
var is_dying := false
var player: CharacterBody2D = null

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()

func set_player_reference(player_ref: CharacterBody2D) -> void:
	player = player_ref

func _ready() -> void:
	sprite_2d.modulate = Color(1, 1, 1)

	# Breadcrumb belongs to layer 2 (arbitrary, just not 1)
	collision_layer = 2
	# Breadcrumb collides only with layer 1 (player + walls)
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if is_dying:
		death_timer -= delta
		if death_timer <= 0.0:
			queue_free()
		return

	velocity = direction * MOVE_SPEED
	move_and_slide()

	# Check all collisions this frame
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var other = collision.get_collider()
		if other:
			# Apply damage only if it's the player
			if other == player and other.has_method("apply_damage"):
				var knockback_dir = (player.global_position - global_position).normalized()
				other.apply_damage(1, knockback_dir)

			# If collided object is on collision layer 1 (walls or player)
			if (other.collision_layer & 1) != 0:
				queue_free()
				return

	# Flash effect
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			sprite_2d.modulate = Color(1, 1, 1)

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
	collision_layer = 0
