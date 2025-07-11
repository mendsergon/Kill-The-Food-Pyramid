extends Node2D

@onready var ray_cast_2d: RayCast2D = $RayCast2D  # Raycast to detect collisions manually

### --- CORE CONSTANTS --- ###
const SPEED: int = 300                     # Bullet travel speed (pixels per second)

### --- MOVEMENT --- ###
func _physics_process(delta: float) -> void:
	if ray_cast_2d.is_colliding():             # Check if raycast hit something this frame
		var collider = ray_cast_2d.get_collider()
		print("Hit:", collider.name)
		queue_free()                            # Destroy bullet on impact
	else:
		position += transform.x * SPEED * delta  # Move bullet forward based on local direction

### --- LIFETIME MANAGEMENT --- ###
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()                              # Remove bullet when it exits the screen
