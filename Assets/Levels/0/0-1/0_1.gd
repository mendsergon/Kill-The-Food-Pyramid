extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player                    # Reference to the player node
@onready var camera_2d: Camera2D = $Player/Camera2D               # Reference to the camera
@onready var enemy_group_1: Node2D = $EnemyGroup1                 # Group containing all enemies

### --- SHARED STATE --- ###
var player_detected := false                                       # Shared detection flag for all enemies

func _ready() -> void:
	# Loop through all children of the enemy group
	for enemy in enemy_group_1.get_children():
		if enemy.has_method("set_player_reference"):
			# Pass both player reference and this manager to each enemy
			enemy.set_player_reference(player, self)

### --- PUBLIC METHOD FOR ENEMY DETECTION --- ###
func set_player_detected(value: bool) -> void:
	player_detected = value
	if player_detected:
		print("Player detected! All enemies are now alert!")   # Debug message
