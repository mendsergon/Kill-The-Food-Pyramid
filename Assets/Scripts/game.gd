extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var burger: Node = $Burger  

func _ready() -> void:
	# Pass player reference to enemy for tracking
	burger.set_player_reference(player)

func _process(_delta: float) -> void:
	pass
