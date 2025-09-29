extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var spawn_area: Area2D = $SpawnArea
@onready var spawn_shape: CollisionShape2D = $SpawnArea/CollisionShape2D
@onready var fade_layer: CanvasLayer = $FadeLayer
@onready var wave_label: Label = $"Player/Camera2D/WaveLabel"
@onready var camera_2d_death: Camera2D = $"Camera2D Death"
@onready var death_label: Label = $"Camera2D Death/DeathLabel"
@onready var death_label_2: Label = $"Camera2D Death/DeathLabel2"

### --- ENEMY SCENES --- ###
var bread_scene: PackedScene = preload("res://Assets/Enemies/Bread/bread.tscn")
var black_bread_scene: PackedScene = preload("res://Assets/Enemies/Bread/black_bread.tscn")
var baguette_scene: PackedScene = preload("res://Assets/Enemies/Baguette/baguette.tscn")
var potato_scene: PackedScene = preload("res://Assets/Enemies/Potato/potato.tscn")
var sweet_potato_scene: PackedScene = preload("res://Assets/Enemies/Sweet Potato/sweet_potato.tscn")

### --- WAVE SETTINGS --- ###
var waves := [
	{
		"enemy_type": "potato",
		"total": 20,
		"batch_size": 2,    
		"spawn_rate": 2.0   
	},
	{
		"enemy_type": "mixed_second_wave",
		"total": 50,
		"batch_size": 5,
		"spawn_rate": 5.0,
		"composition": {
			"potato": 15,
			"bread": 12,      
			"black_bread": 13,
			"baguette": 10
		}
	},
	{
		"enemy_type": "mixed_third_wave",
		"total": 45,  
		"batch_size": 5,
		"spawn_rate": 5.0,
		"composition": {
			"potato": 25,
			"sweet_potato": 20
		}
	},
	{
		"enemy_type": "mixed_fourth_wave",
		"total": 75,
		"batch_size": 5,
		"spawn_rate": 5.0,
		"composition": {
			"baguette": 15,
			"potato": 20,
			"sweet_potato": 10,
			"bread": 15,
			"black_bread": 15
		}
	},
	{
		"enemy_type": "mixed_fifth_wave",
		"total": 100,
		"batch_size": 5,
		"spawn_rate": 5.0,
		"composition": {
			"bread": 25,
			"black_bread": 25,
			"baguette": 20,
			"potato": 15,
			"sweet_potato": 15
		}
	}
]

var current_wave := 0
var spawned_count := 0
var alive_enemies := 0
var spawn_timer: Timer
var wave_label_timer: float = 0.0
var current_tween: Tween = null
var second_wave_spawn_list: Array = []

### --- EDGE OFFSET --- ###
var edge_offset := 16 # pixels outside camera view

### --- DEATH STATE --- ###
var is_player_dead := false
var death_overlay: ColorRect = null

func _ready() -> void:
	randomize()
	set_process(true)
	wave_label.modulate.a = 0.0
	wave_label.visible = false

	if is_instance_valid(camera_2d_death):
		camera_2d_death.enabled = true
	if is_instance_valid(death_label):
		death_label.visible = false
	if is_instance_valid(death_label_2):
		death_label_2.visible = false
	
	_start_wave(0)

func _process(delta: float) -> void:
	if wave_label_timer > 0:
		wave_label_timer -= delta
		if wave_label_timer <= 0.5 and wave_label.modulate.a > 0:
			if current_tween:
				current_tween.kill()
			current_tween = create_tween()
			current_tween.tween_property(wave_label, "modulate:a", 0.0, 0.5)
		elif wave_label_timer <= 0:
			wave_label.visible = false

	if not is_player_dead and not is_instance_valid(player):
		_on_player_died()

func _input(event: InputEvent) -> void:
	if not is_player_dead:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_F:
			# Load last active slot via SaveManager
			if SaveManager.has_method("get_active_slot") and SaveManager.get_active_slot() != -1:
				var ok = SaveManager.continue_game()  # uses current_slot automatically
				if not ok:
					printerr("Failed to continue game from active save slot")
			else:
				print("No active save slot set — cannot load")

func _on_player_died() -> void:
	is_player_dead = true

	# Remove all enemies when player dies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	if spawn_timer:
		spawn_timer.stop()
		spawn_timer.queue_free()

	if is_instance_valid(camera_2d_death):
		camera_2d_death.make_current()

	if is_instance_valid(death_label):
		death_label.visible = true
	if is_instance_valid(death_label_2):
		death_label_2.visible = true

	if death_overlay == null:
		death_overlay = ColorRect.new()
		death_overlay.name = "DeathOverlay"
		death_overlay.color = Color(0, 0, 0, 0.75)
		death_overlay.anchor_left = 0.0
		death_overlay.anchor_top = 0.0
		death_overlay.anchor_right = 1.0
		death_overlay.anchor_bottom = 1.0
		death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		death_overlay.z_index = -1
		if is_instance_valid(camera_2d_death):
			camera_2d_death.add_child(death_overlay)

	print("Player died. Press E to restart, or F to go to rest area.")

func _start_wave(wave_index: int) -> void:
	if wave_index >= waves.size():
		print("All waves complete!")
		return

	current_wave = wave_index
	spawned_count = 0
	alive_enemies = 0

	if waves[current_wave].get("enemy_type").begins_with("mixed_"):
		second_wave_spawn_list.clear()
		for enemy_type in waves[current_wave]["composition"]:
			var count = waves[current_wave]["composition"][enemy_type]
			for i in range(count):
				second_wave_spawn_list.append(enemy_type)
		second_wave_spawn_list.shuffle()

	wave_label.text = "Wave " + str(current_wave + 1)
	if current_tween:
		current_tween.kill()
	wave_label.visible = true
	wave_label_timer = 2.0
	current_tween = create_tween()
	current_tween.tween_property(wave_label, "modulate:a", 1.0, 0.2).from(0.0)

	var wave = waves[current_wave]
	spawn_timer = Timer.new()
	spawn_timer.wait_time = wave.get("spawn_rate", 1.0)
	spawn_timer.one_shot = false
	spawn_timer.connect("timeout", Callable(self, "_spawn_wave_batch"))
	add_child(spawn_timer)
	spawn_timer.start()

func _spawn_wave_batch() -> void:
	if is_player_dead or not is_instance_valid(player):
		if spawn_timer:
			spawn_timer.stop()
			spawn_timer.queue_free()
		return

	var wave = waves[current_wave]
	var total_to_spawn = wave.get("total", 0)
	var batch_size = wave.get("batch_size", 1)

	if spawned_count >= total_to_spawn:
		spawn_timer.stop()
		spawn_timer.queue_free()
		return

	for i in range(batch_size):
		if spawned_count >= total_to_spawn:
			break

		var spawn_pos = _get_spawn_position_near_camera_edge_in_area()
		var enemy_scene: PackedScene
		var enemy_type: String

		if wave.get("enemy_type").begins_with("mixed_"):
			enemy_type = second_wave_spawn_list.pop_back()
		else:
			enemy_type = wave.get("enemy_type", "bread")

		match enemy_type:
			"bread": enemy_scene = bread_scene
			"black_bread": enemy_scene = black_bread_scene
			"baguette": enemy_scene = baguette_scene
			"potato": enemy_scene = potato_scene
			"sweet_potato": enemy_scene = sweet_potato_scene
			_: enemy_scene = bread_scene

		var enemy = enemy_scene.instantiate()
		if is_instance_valid(enemy):
			enemy.global_position = spawn_pos
			if enemy.has_method("set_player_reference") and is_instance_valid(player):
				enemy.set_player_reference(player)
			if enemy.has_signal("tree_exited"):
				enemy.connect("tree_exited", Callable(self, "_on_enemy_died"))
			add_child(enemy)
			enemy.add_to_group("enemies")

			spawned_count += 1
			alive_enemies += 1

func _on_enemy_died() -> void:
	alive_enemies -= 1
	if alive_enemies <= 0 and spawned_count >= waves[current_wave].get("total", 0):
		if current_wave + 1 >= waves.size():
			await get_tree().create_timer(5.0).timeout
			if is_instance_valid(fade_layer) and fade_layer.has_method("start_fade"):
				fade_layer.start_fade("res://Assets/Levels/Rest Areas/level_2.tscn")
		else:
			await get_tree().create_timer(3.0).timeout
			_start_wave(current_wave + 1)

func _get_spawn_position_near_camera_edge_in_area() -> Vector2:
	if not is_instance_valid(spawn_shape) or not is_instance_valid(camera_2d):
		return Vector2.ZERO

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
				0:
					pos.y = cam_rect.position.y - edge_offset
					pos.x = randf_range(cam_rect.position.x, cam_rect.position.x + cam_rect.size.x)
				1:
					pos.y = cam_rect.position.y + cam_rect.size.y + edge_offset
					pos.x = randf_range(cam_rect.position.x, cam_rect.position.x + cam_rect.size.x)
				2:
					pos.x = cam_rect.position.x - edge_offset
					pos.y = randf_range(cam_rect.position.y, cam_rect.position.y + cam_rect.size.y)
				3:
					pos.x = cam_rect.position.x + cam_rect.size.x + edge_offset
					pos.y = randf_range(cam_rect.position.y, cam_rect.position.y + cam_rect.size.y)

			pos.x = clamp(pos.x, area_min.x, area_max.x)
			pos.y = clamp(pos.y, area_min.y, area_max.y)

			if not cam_rect.has_point(pos):
				return pos
			tries += 1

	return spawn_shape.global_position
