extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var spawn_area: Area2D = $SpawnArea
@onready var spawn_shape: CollisionShape2D = $SpawnArea/CollisionShape2D

### --- ENEMY SCENES --- ###
var bread_scene: PackedScene = preload("res://Assets/Scenes/bread.tscn")

### --- SPAWN SETTINGS --- ###
var total_to_spawn := 20
var spawned_count := 0
var spawn_timer: Timer

var edge_offset := 16 # pixels outside camera view

func _ready() -> void:
	randomize()
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.0
	spawn_timer.one_shot = false
	spawn_timer.connect("timeout", Callable(self, "_spawn_wave_batch"))
	add_child(spawn_timer)
	spawn_timer.start()

func _spawn_wave_batch() -> void:
	if spawned_count >= total_to_spawn:
		spawn_timer.stop()
		return

	for i in range(2):
		if spawned_count >= total_to_spawn:
			break
		var spawn_pos = _get_spawn_position_near_camera_edge_in_area()
		var bread_enemy = bread_scene.instantiate()
		bread_enemy.global_position = spawn_pos
		if bread_enemy.has_method("set_player_reference"):
			bread_enemy.set_player_reference(player)
		get_parent().add_child(bread_enemy)
		spawned_count += 1

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

		var pos := Vector2.ZERO
		var tries := 0
		while true:
			# Pick side of camera
			var side := randi() % 4
			match side:
				0: # top
					pos.y = cam_rect.position.y - edge_offset
					pos.x = clamp(randf_range(cam_rect.position.x, cam_rect.position.x + cam_rect.size.x), area_min.x, area_max.x)
				1: # bottom
					pos.y = cam_rect.position.y + cam_rect.size.y + edge_offset
					pos.x = clamp(randf_range(cam_rect.position.x, cam_rect.position.x + cam_rect.size.x), area_min.x, area_max.x)
				2: # left
					pos.x = cam_rect.position.x - edge_offset
					pos.y = clamp(randf_range(cam_rect.position.y, cam_rect.position.y + cam_rect.size.y), area_min.y, area_max.y)
				3: # right
					pos.x = cam_rect.position.x + cam_rect.size.x + edge_offset
					pos.y = clamp(randf_range(cam_rect.position.y, cam_rect.position.y + cam_rect.size.y), area_min.y, area_max.y)

			# Ensure position is inside spawn area bounds
			if pos.x >= area_min.x and pos.x <= area_max.x and pos.y >= area_min.y and pos.y <= area_max.y:
				# Ensure not inside camera view
				if not cam_rect.has_point(pos):
					return pos

			tries += 1
			if tries > 50:
				return spawn_shape.global_position

	return spawn_shape.global_position
