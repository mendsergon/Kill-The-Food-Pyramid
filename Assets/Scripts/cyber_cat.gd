extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var player: CharacterBody2D = null

# Called from the Node2D scene script
func set_player_reference(p: CharacterBody2D) -> void:
	player = p

func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		if player.global_position.x < global_position.x:
			animated_sprite_2d.flip_h = true   # face left (player is left)
		else:
			animated_sprite_2d.flip_h = false  # face right (player is right)
