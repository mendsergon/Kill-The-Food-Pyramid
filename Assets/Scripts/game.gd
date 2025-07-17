extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var burger: CharacterBody2D = $Burger
@onready var bread: CharacterBody2D = $Bread

func _ready() -> void:
	# Pass player reference to enemy for tracking
	burger.set_player_reference(player)
	bread.set_player_reference(player)

func _process(_delta: float) -> void:
	# Restart the scene when the player's instance has been freed 
	if not is_instance_valid(player):
		get_tree().reload_current_scene()
