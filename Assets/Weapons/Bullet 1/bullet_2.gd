extends Area2D

@warning_ignore("unused_signal")
signal hit_target(collider)  # Signal to notify when bullet hits something

@onready var ray_cast_2d: RayCast2D = $RayCast2D  # Raycast to detect collisions manually
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

### --- CORE CONSTANTS --- ###
const SPEED: int = 300                     # Bullet travel speed (pixels per second)

### --- BULLET PROPERTIES --- ###
var damage: int = 1                        # Damage dealt by bullet

### --- INITIALIZATION --- ###
func _ready() -> void:
	# Make the bullet green
	modulate = Color.GREEN
	
	# Play audio once when the bullet is spawned, starting from 0.2 seconds
	audio_stream_player.play(0.2)
	
	# Start fading out immediately over the remaining duration of the audio
	var audio_length = audio_stream_player.stream.get_length() - 0.4
	var tween = create_tween()
	tween.tween_property(audio_stream_player, "volume_db", -80.0, audio_length)

### --- MOVEMENT --- ###
func _physics_process(delta: float) -> void:
	if ray_cast_2d.is_colliding():             # Check if raycast hit something this frame
		var collider = ray_cast_2d.get_collider()
		
		# If the thing we hit can take damage, apply damage from bullets
		if collider.has_method("apply_damage"):
			collider.apply_damage(damage)
		
		print("Hit:", collider.name, " Damage:", damage)
		emit_signal("hit_target", collider)  # Emit signal to notify listeners of hit
		queue_free()                            # Destroy bullet on impact
	else:
		position += transform.x * SPEED * delta  # Move bullet forward based on local direction

### --- SET DAMAGE METHOD --- ###
func set_damage(new_damage: int) -> void:
	damage = new_damage

### --- LIFETIME MANAGEMENT --- ###
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()                              # Remove bullet when it exits the screen
