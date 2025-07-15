extends CharacterBody2D

### --- CORE CONSTANTS --- ###
const MOVE_SPEED = 50.0                  # Enemy walk speed
const MOVE_DURATION = 3.0                 # Active chase time
const IDLE_COOLDOWN = 2.0                 # Pause duration between chases

### --- PHYSICS --- ###
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity") # Gravity value
const FALL_GRAVITY_MULTIPLIER = 1.5      # Faster falling multiplier

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D  # Enemy sprite

### --- STATE --- ###
var player: CharacterBody2D = null        # Reference to player node
var is_moving := true                     # Currently chasing player
var behavior_timer := 0.0                 # Tracks chase/idle timing

### --- PUBLIC SETUP --- ###
func set_player_reference(player_ref: CharacterBody2D) -> void:
	player = player_ref

func _ready() -> void:
	animated_sprite_2d.play("Idle")

func _physics_process(delta: float) -> void:
	if player == null:
		return  # Don't run until the player is assigned

	### --- TIMER MANAGEMENT --- ###
	behavior_timer += delta

	if is_moving and behavior_timer >= MOVE_DURATION:
		is_moving = false
		behavior_timer = 0.0
		animated_sprite_2d.play("Idle")

	elif not is_moving and behavior_timer >= IDLE_COOLDOWN:
		is_moving = true
		behavior_timer = 0.0
		animated_sprite_2d.play("Run")

	### --- GRAVITY LOGIC --- ###
	if not is_on_floor():
		# Apply stronger gravity when falling
		if velocity.y < 0:
			# Going up - normal gravity (enemy won't jump but for consistency)
			velocity.y += gravity * delta
		else:
			# Falling - multiply gravity for faster fall
			velocity.y += gravity * FALL_GRAVITY_MULTIPLIER * delta
	else:
		# Reset vertical velocity if on floor
		velocity.y = 0

	### --- HORIZONTAL MOVEMENT --- ###
	velocity.x = 0.0
	if is_moving:
		var direction = sign(player.global_position.x - global_position.x)
		velocity.x = direction * MOVE_SPEED
		animated_sprite_2d.flip_h = direction < 0

	### --- APPLY MOVEMENT --- ###
	move_and_slide()
