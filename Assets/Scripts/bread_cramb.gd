extends CharacterBody2D

### --- CORE CONSTANTS --- ###
const MOVE_SPEED = 100.0                 # Speed of breadcrumb
const FLASH_DURATION = 0.1               # Duration of red flash after taking damage
const DEATH_DURATION = 0.2               # Delay before removing breadcrumb after death
const MAX_DISTANCE_FROM_PLAYER = 800.0   # Auto-despawn distance from player
const OVERLAP_RADIUS = 10.0               # Radius used for overlap-based hit detection

### --- HEALTH --- ###
var health: int = 1                      # Breadcrumb HP (only 1 hit to destroy)

### --- NODE REFERENCES --- ###
@onready var sprite_2d: Sprite2D = $Sprite2D  # Reference to crumb's sprite

### --- STATE --- ###
var direction := Vector2.ZERO            # Locked movement direction at spawn
var flash_timer := 0.0                    # Timer for red flash effect
var death_timer := 0.0                    # Timer before removing dead crumb
var is_dying := false                     # Whether crumb is in death state
var player: CharacterBody2D = null        # Reference to player node

### --- PUBLIC SETUP --- ###
func set_direction(dir: Vector2) -> void:
	# Store normalized movement direction
	direction = dir.normalized()
	print("Breadcrumb direction set to: ", direction)

func set_player_reference(player_ref: CharacterBody2D) -> void:
	# Assign player reference for targeting & collision checks
	player = player_ref
	print("Breadcrumb received player reference.")

func _ready() -> void:
	# Reset sprite color to normal at spawn
	sprite_2d.modulate = Color(1, 1, 1)
	print("Breadcrumb spawned at ", global_position)

func _physics_process(delta: float) -> void:
	### --- DEATH TIMER LOGIC --- ###
	if is_dying:
		death_timer -= delta
		if death_timer <= 0.0:
			print("Breadcrumb died and is being freed.")
			queue_free()
		return

	### --- FACE PLAYER --- ###
	if player:
		var to_player = player.global_position - global_position
		rotation = to_player.angle()

	### --- MOVE IN LOCKED DIRECTION --- ###
	var collision = move_and_collide(direction * MOVE_SPEED * delta)
	if collision:
		print("Breadcrumb collided with: ", collision.get_collider())

	### --- RELIABLE OVERLAP CHECK FOR PLAYER DAMAGE --- ###
	if player:
		var space = get_world_2d().direct_space_state

		# Create a small circle for hit detection
		var circle = CircleShape2D.new()
		circle.radius = OVERLAP_RADIUS

		# Setup physics query
		var params = PhysicsShapeQueryParameters2D.new()
		params.shape = circle
		params.transform = Transform2D(0.0, global_position)
		params.collision_mask = player.collision_layer
		params.exclude = [self]

		var results = space.intersect_shape(params, 4)
		if results.size() > 0:
			print("Breadcrumb overlap check found ", results.size(), " collisions")

		for res in results:
			var collider = res.get("collider", null)
			if collider == null:
				continue

			# Damage player on contact
			if collider == player and player.has_method("apply_damage"):
				print("Breadcrumb hit player! Applying damage.")
				var knockback_dir = (player.global_position - global_position).normalized()
				player.apply_damage(1, knockback_dir)
				die()
				return

	### --- AUTO-DESPAWN WHEN TOO FAR FROM PLAYER --- ###
	if player and global_position.distance_to(player.global_position) > MAX_DISTANCE_FROM_PLAYER:
		print("Breadcrumb too far from player, despawning.")
		queue_free()
		return

	### --- FLASH EFFECT TIMER --- ###
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			# Reset sprite color when flash ends
			sprite_2d.modulate = Color(1, 1, 1)

### --- DAMAGE HANDLING --- ###
func apply_damage(amount: int) -> void:
	# Subtract incoming damage
	health -= amount
	print("Breadcrumb took %d damage, %d HP remaining" % [amount, health])

	# Start red flash effect
	sprite_2d.modulate = Color(1, 0, 0)
	flash_timer = FLASH_DURATION

	# Destroy crumb if HP depleted
	if health <= 0:
		die()

### --- DEATH HANDLING --- ###
func die() -> void:
	is_dying = true
	death_timer = DEATH_DURATION
	velocity = Vector2.ZERO
	collision_layer = 0  # Disable collisions while dying
	print("Breadcrumb is dying.")
