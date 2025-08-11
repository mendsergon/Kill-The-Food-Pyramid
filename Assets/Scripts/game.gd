extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var burger: CharacterBody2D = $Burger
@onready var bread: CharacterBody2D = $Bread
@onready var baguette: CharacterBody2D = $Baguette
@onready var camera_2d: Camera2D = $Player/Camera2D

### --- ENEMY SCENES --- ###w
var burger_scene: PackedScene = preload("res://Assets/Scenes/bread.tscn")
var bread_scene: PackedScene = preload("res://Assets/Scenes/burger.tscn")

### --- SPAWNING VARIABLES --- ###
var spawn_timer := 0.0
const SPAWN_INTERVAL := 2.0 # Time in seconds between spawns
const SPAWN_MARGIN := 100   # Distance outside the camera view to spawn

func _ready() -> void:
	# Pass player reference to enemy for tracking
	burger.set_player_reference(player)
	bread.set_player_reference(player)
	baguette.set_player_reference(player)

func _process(_delta: float) -> void:
	# Restart the scene when the player's instance has been freed 
	if not is_instance_valid(player):
		get_tree().reload_current_scene()
		return

	# --- Spawn logic: add 1 burger and 1 bread every 2 seconds just outside camera view --- #
	spawn_timer += _delta
	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		spawn_enemy(burger_scene)
		spawn_enemy(bread_scene)

# --- Spawn a new enemy instance slightly outside the camera view in a random direction --- #
func spawn_enemy(enemy_scene: PackedScene) -> void:
	var enemy = enemy_scene.instantiate() as CharacterBody2D
	enemy.set_player_reference(player)

	enemy.scale = Vector2(0.75, 0.75) # Scale enemy to 75% size

	var cam_pos = camera_2d.global_position
	var cam_size = get_viewport_rect().size / camera_2d.zoom

	var direction = randi() % 4 # 0=left, 1=right, 2=top, 3=bottom
	var spawn_pos := Vector2.ZERO

	match direction:
		0: # Left
			spawn_pos = Vector2(cam_pos.x - cam_size.x / 2 - SPAWN_MARGIN, randf_range(cam_pos.y - cam_size.y / 2, cam_pos.y + cam_size.y / 2))
		1: # Right
			spawn_pos = Vector2(cam_pos.x + cam_size.x / 2 + SPAWN_MARGIN, randf_range(cam_pos.y - cam_size.y / 2, cam_pos.y + cam_size.y / 2))
		2: # Top
			spawn_pos = Vector2(randf_range(cam_pos.x - cam_size.x / 2, cam_pos.x + cam_size.x / 2), cam_pos.y - cam_size.y / 2 - SPAWN_MARGIN)
		3: # Bottom
			spawn_pos = Vector2(randf_range(cam_pos.x - cam_size.x / 2, cam_pos.x + cam_size.x / 2), cam_pos.y + cam_size.y / 2 + SPAWN_MARGIN)

	enemy.global_position = spawn_pos
	add_child(enemy)
