extends CharacterBody2D

### --- CORE CONSTANTS --- ###
const MOVE_SPEED = 150.0
const FLASH_DURATION = 0.1
const DEATH_DURATION = 0.2
const MAX_DISTANCE_FROM_PLAYER = 800.0
const OVERLAP_RADIUS = 10.0
const SPRITE_ORIENTATION_OFFSET = 0.0   # if your sprite faces right by default, use -PI/2, etc.

### --- HEALTH --- ###
var health: int = 1

### --- NODE REFERENCES --- ###
@onready var sprite_2d: Sprite2D = $Sprite2D

### --- STATE --- ###
var direction := Vector2.ZERO
var flash_timer := 0.0
var death_timer := 0.0
var is_dying := false
var player: CharacterBody2D = null

### --- PUBLIC SETUP --- ###
func set_player_reference(player_ref: CharacterBody2D) -> void:
	player = player_ref
	print("Spagh received player reference.")
	face_player_and_lock_direction()

### --- HELPERS --- ###
func face_player_and_lock_direction() -> void:
	if player == null:
		return

	var to_player = player.global_position - global_position
	if to_player == Vector2.ZERO:
		to_player = Vector2(0, -1)  # default up if overlapping

	direction = to_player.normalized()

	# rotate the parent so it looks at the player
	rotation = to_player.angle() + SPRITE_ORIENTATION_OFFSET + PI/2

	print("Spagh locked direction to player:", direction)

func _ready() -> void:
	sprite_2d.modulate = Color(1, 1, 1)
	print("Spagh spawned at ", global_position)
	# don’t rotate here unless player already set

func _physics_process(delta: float) -> void:
	if is_dying:
		death_timer -= delta
		if death_timer <= 0.0:
			print("Spagh died and is being freed.")
			queue_free()
		return

	# Move in locked direction
	if direction != Vector2.ZERO:
		var collision = move_and_collide(direction * MOVE_SPEED * delta)
		if collision:
			print("Spagh collided with: ", collision.get_collider())

	# Damage check
	if player:
		var space = get_world_2d().direct_space_state
		var circle = CircleShape2D.new()
		circle.radius = OVERLAP_RADIUS

		var params = PhysicsShapeQueryParameters2D.new()
		params.shape = circle
		params.transform = Transform2D(0.0, global_position)
		params.collision_mask = player.collision_layer
		params.exclude = [self]

		var results = space.intersect_shape(params, 4)
		for res in results:
			var collider = res.get("collider", null)
			if collider == player and player.has_method("apply_damage"):
				print("Spagh hit player! Applying damage.")
				var knockback_dir = (player.global_position - global_position).normalized()
				player.apply_damage(1, knockback_dir)
				die()
				return

	# Auto-despawn
	if player and global_position.distance_to(player.global_position) > MAX_DISTANCE_FROM_PLAYER:
		print("Spagh too far from player, despawning.")
		queue_free()
		return

	# Flash timer
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			sprite_2d.modulate = Color(1, 1, 1)

### --- DAMAGE HANDLING --- ###
func apply_damage(amount: int) -> void:
	health -= amount
	print("Spagh took %d damage, %d HP remaining" % [amount, health])
	sprite_2d.modulate = Color(1, 0, 0)
	flash_timer = FLASH_DURATION
	if health <= 0:
		die()

### --- DEATH HANDLING --- ###
func die() -> void:
	is_dying = true
	death_timer = DEATH_DURATION
	velocity = Vector2.ZERO
	collision_layer = 0
	print("Spagh is dying.")
