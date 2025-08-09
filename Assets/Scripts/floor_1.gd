extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var spawn_area: Area2D = $SpawnArea
@onready var spawn_shape: CollisionShape2D = $SpawnArea/CollisionShape2D

### --- ENEMY SCENES --- ###
var bread_scene: PackedScene = preload("res://Assets/Scenes/bread.tscn")
var black_bread_scene: PackedScene = preload("res://Assets/Scenes/black_bread.tscn")

### --- WAVE SETTINGS --- ###
var waves = [
	{
		"total": 20,
		"batch_size": 2,
		"spawn_rate": 1.0,
		"enemy_type": "bread" # single type
	},
	{
		"total": 40,
		"batch_size": 2,
		"spawn_rate": 1.0,
		"enemy_type": "mixed" # 50% bread / black_bread
	}
]

var current_wave := 0
var spawned_count := 0
var alive_enemies := 0
var spawn_timer: Timer

### --- EDGE OFFSET --- ###
var edge_offset := 16 # pixels outside camera view

func _ready() -> void:
	randomize()
	_start_wave(0)

func _start_wave(wave_index: int) -> void:
	if wave_index >= waves.size():
		print("All waves complete!")
		return

	current_wave = wave_index
	spawned_count = 0
	alive_enemies = 0

	var wave = waves[current_wave]
	spawn_timer = Timer.new()
	spawn_timer.wait_time = wave["spawn_rate"]
	spawn_timer.one_shot = false
	spawn_timer.connect("timeout", Callable(self, "_spawn_wave_batch"))
	add_child(spawn_timer)
	spawn_timer.start()

func _spawn_wave_batch() -> void:
	var wave = waves[current_wave]
	var total_to_spawn = wave["total"]
	var batch_size = wave["batch_size"]

	if spawned_count >= total_to_spawn:
		spawn_timer.stop()
		spawn_timer.queue_free()
		return # Wait for alive_enemies to reach 0 before starting next wave

	for i in range(batch_size):
		if spawned_count >= total_to_spawn:
			break
		var spawn_pos = _get_spawn_position_near_camera_edge_in_area()

		# Choose enemy scene based on wave type
		var enemy_scene: PackedScene
		if wave["enemy_type"] == "bread":
			enemy_scene = bread_scene
		elif wave["enemy_type"] == "mixed":
			if randf() < 0.5:
				enemy_scene = bread_scene
			else:
				enemy_scene = black_bread_scene

		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_pos
		if enemy.has_method("set_player_reference"):
			enemy.set_player_reference(player)

		# Track when enemy dies
		if enemy.has_signal("tree_exited"):
			enemy.connect("tree_exited", Callable(self, "_on_enemy_died"))

		get_parent().add_child(enemy)
		spawned_count += 1
		alive_enemies += 1

func _on_enemy_died() -> void:
	alive_enemies -= 1
	if alive_enemies <= 0 and spawned_count >= waves[current_wave]["total"]:
		# Wave is truly complete (all spawned enemies are dead)
		await get_tree().create_timer(5.0).timeout
		_start_wave(current_wave + 1)

func _get_spawn_position_near_camera_edge_in_area() -> Vector2:
	var shape := spawn_shape.shape
	if shape is RectangleShape2D:
		var extents: Vector2 = shape.extents
		var area_min = spawn_shape.global_position - extents
		var area_max = spawn_shape.global_position + extents

		var cam_rect := Rect2(
			camera_2d.global_position - camera_2d.get_viewport_rect().size * 0.5,
			camera_2d.get_viewport_rect().size
		)

		var tries := 0
		while tries < 100:
			var pos := Vector2.ZERO
			var side := randi() % 4
			match side:
				0: # top edge (just above camera)
					pos.y = cam_rect.position.y - edge_offset
					pos.x = randf_range(cam_rect.position.x, cam_rect.position.x + cam_rect.size.x)
				1: # bottom edge (just below camera)
					pos.y = cam_rect.position.y + cam_rect.size.y + edge_offset
					pos.x = randf_range(cam_rect.position.x, cam_rect.position.x + cam_rect.size.x)
				2: # left edge (just left of camera)
					pos.x = cam_rect.position.x - edge_offset
					pos.y = randf_range(cam_rect.position.y, cam_rect.position.y + cam_rect.size.y)
				3: # right edge (just right of camera)
					pos.x = cam_rect.position.x + cam_rect.size.x + edge_offset
					pos.y = randf_range(cam_rect.position.y, cam_rect.position.y + cam_rect.size.y)

			# Clamp position inside spawn area rectangle
			pos.x = clamp(pos.x, area_min.x, area_max.x)
			pos.y = clamp(pos.y, area_min.y, area_max.y)

			# Conditions:
			# 1) pos must be inside spawn area rectangle (already clamped)
			# 2) pos must be outside camera viewport
			if not cam_rect.has_point(pos):
				return pos

			tries += 1

		# fallback to center of spawn area
		return spawn_shape.global_position

	return spawn_shape.global_position
