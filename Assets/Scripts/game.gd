extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var potato: CharacterBody2D = $Potato

### --- ENEMY SCENES --- ###w
var burger_scene: PackedScene = preload("res://Assets/Scenes/bread.tscn")
var bread_scene: PackedScene = preload("res://Assets/Scenes/burger.tscn")

### --- SPAWNING VARIABLES --- ###
var spawn_timer := 0.0
const SPAWN_INTERVAL := 2.0 # Time in seconds between spawns
const SPAWN_MARGIN := 100   # Distance outside the camera view to spawn

func _ready() -> void:
	# Pass player reference to enemy for tracking
	potato.set_player_reference(player)

func _process(_delta: float) -> void:
	# Restart the scene when the player's instance has been freed 
	if not is_instance_valid(player):
		get_tree().reload_current_scene()
		return
