extends CharacterBody2D

### --- CORE CONSTANTS --- ###
const MOVE_SPEED = 50.0                  # Enemy walk speed
const MOVE_DURATION = 3.0               # Active chase time
const IDLE_COOLDOWN = 2.0               # Pause duration between chases

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

	### --- MOVEMENT LOGIC --- ###
	var move_direction = Vector2.ZERO
	if is_moving:
		move_direction = (player.global_position - global_position).normalized()
		velocity = move_direction * MOVE_SPEED

		# Flip sprite based on horizontal direction only
		if abs(move_direction.x) > abs(move_direction.y):
			animated_sprite_2d.flip_h = move_direction.x < 0
	else:
		velocity = Vector2.ZERO

	### --- APPLY MOVEMENT --- ###
	move_and_slide()
