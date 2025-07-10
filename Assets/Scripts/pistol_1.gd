extends Node2D

### --- CONSTANTS --- ###
const BULLET = preload("res://Assets/Scenes/bullet_1.tscn") # Bullet scene reference

### --- NODE REFERENCES --- ###
@onready var muzzle: Marker2D = $Marker2D                  # Muzzle position for bullet spawn

### --- AIMING SYSTEM --- ###
func _process(delta: float) -> void:
	# Rotate to face the global mouse position
	look_at(get_global_mouse_position())
	
	# Wrap rotation to keep within 0–360 degrees
	rotation_degrees = wrap(rotation_degrees, 0, 360)
	
	# Flip vertically when facing left (between 90° and 270°)
	if rotation_degrees > 90 and rotation_degrees < 270:
		scale.y = -1                        # Mirror sprite on Y axis
	else:
		scale.y = 1                         # Default upward scale

	# Fire bullet on input press
	if Input.is_action_just_pressed("shoot"):
		var bullet_instance = BULLET.instantiate()                         # Create bullet
		get_tree().root.add_child(bullet_instance)                         # Add to scene
		bullet_instance.global_position = muzzle.global_position           # Set spawn position
		bullet_instance.rotation = global_rotation                         # Match aim direction
