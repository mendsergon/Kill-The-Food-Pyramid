extends Node2D

### --- CORE CONSTANTS --- ###
const SPEED: int = 450                      # Bullet travel speed (pixels per second)

### --- MOVEMENT --- ###
func _process(delta: float) -> void:
	position += transform.x * SPEED * delta  # Move bullet forward based on local direction

### --- LIFETIME MANAGEMENT --- ###
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()                              # Remove bullet when it exits the screen
