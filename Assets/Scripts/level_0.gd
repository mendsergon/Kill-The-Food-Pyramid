extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D


func _process(_delta: float) -> void:
	# Restart the scene when the player's instance has been freed 
	if not is_instance_valid(player):
		get_tree().reload_current_scene()
		return
