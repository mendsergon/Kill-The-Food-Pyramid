extends Node2D

@onready var bread: CharacterBody2D = $Bread
@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D

func _ready() -> void:
	bread.set_player_reference(player)
