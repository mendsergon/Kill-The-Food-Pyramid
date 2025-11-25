extends WeaponBase

### --- CONSTANTS --- ###
const BULLET = preload("res://Assets/Weapons/Bullet 1/bullet_1.tscn") # Bullet scene reference
const KICKBACK_ANGLE := 10.0   # How much the pistol rotates on recoil
const KICKBACK_SPEED := 15.0   # How fast the pistol returns to normal

### --- NODE REFERENCES --- ###
@onready var muzzle: Marker2D = $Marker2D                  # Muzzle position for bullet spawn

### --- STATE --- ###
var recoil_offset: float = 0.0   # Current recoil rotation offset

### --- AIMING SYSTEM --- ###
func _process(delta: float) -> void:
	# Skip processing if not visible/active
	if not visible:
		return
	
	# Rotate to face the global mouse position
	look_at(get_global_mouse_position())
	
	# Wrap rotation to keep within 0-360 degrees
	rotation_degrees = wrap(rotation_degrees, 0, 360)
	
	# Flip vertically when facing left (between 90° and 270°)
	if rotation_degrees > 90 and rotation_degrees < 270:
		scale.y = -1                        # Mirror sprite on Y axis
	else:
		scale.y = 1                         # Default upward scale

	# Smoothly reduce recoil offset back to zero
	recoil_offset = lerp(recoil_offset, 0.0, KICKBACK_SPEED * delta)
	rotation += deg_to_rad(recoil_offset)

	# Fire bullet on input press
	if Input.is_action_just_pressed("shoot"):
		var bullet_instance = BULLET.instantiate()                         # Create bullet
		get_tree().root.add_child(bullet_instance)                         # Add to scene
		bullet_instance.global_position = muzzle.global_position           # Set spawn position
		bullet_instance.rotation = global_rotation                         # Match aim direction

		# Connect bullet hit signal to pistol to handle melee orb recharge
		bullet_instance.connect("hit_target", Callable(self, "_on_bullet_hit"))

		# Apply recoil (kickback direction depends on aiming side)
		if scale.y == 1:
			recoil_offset = -KICKBACK_ANGLE
		else:
			recoil_offset = KICKBACK_ANGLE

# Called when a bullet hits a collider
func _on_bullet_hit(_collider) -> void:
	# Get the player and call add_melee_orb directly
	var player = get_parent()
	if player and player.has_method("add_melee_orb"):
		player.add_melee_orb()
