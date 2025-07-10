extends Node2D

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
