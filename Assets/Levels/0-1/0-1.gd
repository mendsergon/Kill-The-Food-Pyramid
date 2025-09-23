extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var spawn_area: Area2D = $SpawnArea
@onready var spawn_shape: CollisionShape2D = $SpawnArea/CollisionShape2D
@onready var fade_layer: CanvasLayer = $FadeLayer
@onready var wave_label: Label = $Player/Camera2D/WaveLabel
@onready var camera_2d_death: Camera2D = $"Camera2D Death"
@onready var death_label: Label = $"Camera2D Death/DeathLabel"
@onready var death_label_2: Label = $"Camera2D Death/DeathLabel2"

### --- ENEMY SCENES --- ###
var bread_scene: PackedScene = preload("res://Assets/Enemies/Bread/bread.tscn")
var black_bread_scene: PackedScene = preload("res://Assets/Enemies/Bread/black_bread.tscn")
var baguette_scene: PackedScene = preload("res://Assets/Enemies/Baguette/baguette.tscn")
var big_bread_scene: PackedScene = preload("res://Assets/Enemies/Bread/big_bread.tscn") 
var big__black_bread_scene: PackedScene = preload("res://Assets/Enemies/Bread/big_black_bread.tscn")

### --- WAVE SETTINGS --- ###
var waves = [
	{
		"total": 20,
		"batch_size": 2,
		"spawn_rate": 1.0,
		"enemy_type": "bread" # single type
	},
	{
		"total": 25,
		"batch_size": 2,
		"spawn_rate": 1.0,
		"enemy_type": "mixed" # 50% bread / black_bread
	},
	{
		"total": 10,
		"batch_size": 1,
		"spawn_rate": 1.0,
		"enemy_type": "baguette" 
	},
	{
		"total": 30,
		"batch_size": 2,
		"spawn_rate": 0.5,
		"enemy_type": "baguette_mixed" # new mixed wave: 10 baguettes + 20 mixed breads
	},
	{
		"total": 1,
		"batch_size": 1,
		"spawn_rate": 0.5,
		"enemy_type": "big_bread" # NEW wave 5: just 1 big bread
	}
]

var current_wave := 0
var spawned_count := 0
var alive_enemies := 0
var spawn_timer: Timer
var wave_label_timer: float = 0.0
var current_tween: Tween = null
var is_player_dead := false
var death_overlay: ColorRect = null

# Track baguette/mixed counts separately for wave 4
var baguette_spawned := 0
var mixed_spawned := 0

### --- EDGE OFFSET --- ###
var edge_offset := 16 # pixels outside camera view

### --- BIG BREAD TRACKING --- ###
var big_bread_ref: Node = null
var big_black_bread_spawned := false

func _ready() -> void:
	randomize()
	set_process(true) # ensure _process runs for boss health polling
	wave_label.modulate.a = 0.0  # Start fully transparent
	wave_label.visible = false
	
	# Initialize death camera and labels
	if is_instance_valid(camera_2d_death):
		camera_2d_death.enabled = true
	if is_instance_valid(death_label):
		death_label.visible = false
	if is_instance_valid(death_label_2):
		death_label_2.visible = false
		
	_start_wave(0)

func _process(delta: float) -> void:
	# Handle wave label timer
	if wave_label_timer > 0:
		wave_label_timer -= delta
		if wave_label_timer <= 0.5 and wave_label.modulate.a > 0:  # Start fading out last 0.5 seconds
			if current_tween:
				current_tween.kill()
			current_tween = create_tween()
			current_tween.tween_property(wave_label, "modulate:a", 0.0, 0.5)
		elif wave_label_timer <= 0:
			wave_label.visible = false

	# Check if big bread is alive and health <= 25, then spawn big black bread once
	if big_bread_ref != null and not big_black_bread_spawned:
		# ensure the instance is still valid (not freed)
		if is_instance_valid(big_bread_ref):
			# safely try to read health property
			var h = big_bread_ref.get("health")
			if typeof(h) == TYPE_INT or typeof(h) == TYPE_FLOAT:
				if h <= 25:
					_spawn_big_black_bread()
					big_black_bread_spawned = true
		else:
			# reference invalid (freed), clear it to avoid repeated checks
			big_bread_ref = null
	
	# Check for player death
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
	baguette_spawned = 0
	mixed_spawned = 0
	big_bread_ref = null
	big_black_bread_spawned = false

	# Display wave number on wave_label with fade effect
	if is_instance_valid(wave_label):
		wave_label.text = "Wave " + str(current_wave + 1)
		if current_tween:
			current_tween.kill()
		wave_label.visible = true
		wave_label_timer = 2.0
		current_tween = create_tween()
		current_tween.tween_property(wave_label, "modulate:a", 1.0, 0.2).from(0.0)

	var wave = waves[current_wave]
	spawn_timer = Timer.new()
	spawn_timer.wait_time = wave["spawn_rate"]
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
		elif wave["enemy_type"] == "baguette": 
			enemy_scene = baguette_scene
		elif wave["enemy_type"] == "baguette_mixed":
			# Total 10 baguettes and 20 mixed breads in random order
			var total_baguettes = 10
			var total_mixed = 20

			# Calculate remaining enemies of each type
			var baguettes_left = total_baguettes - baguette_spawned
			var mixed_left = total_mixed - mixed_spawned

			# Pick randomly which to spawn, but respect remaining counts
			if baguettes_left > 0 and mixed_left > 0:
				if randf() < 0.5:
					enemy_scene = baguette_scene
					baguette_spawned += 1
				else:
					if randf() < 0.5:
						enemy_scene = bread_scene
					else:
						enemy_scene = black_bread_scene
					mixed_spawned += 1
			elif baguettes_left > 0:
				enemy_scene = baguette_scene
				baguette_spawned += 1
			else:
				# mixed only
				if randf() < 0.5:
					enemy_scene = bread_scene
				else:
					enemy_scene = black_bread_scene
				mixed_spawned += 1
		elif wave["enemy_type"] == "big_bread":
			enemy_scene = big_bread_scene 

		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_pos
		if enemy.has_method("set_player_reference"):
			enemy.set_player_reference(player)

		# If this is the big bread, keep a reference for HP check
		if wave["enemy_type"] == "big_bread":
			big_bread_ref = enemy

		# Track when enemy dies 
		if enemy.has_signal("tree_exited"):
			enemy.connect("tree_exited", Callable(self, "_on_enemy_died"))

		add_child(enemy)
		enemy.add_to_group("enemies")
		spawned_count += 1
		alive_enemies += 1

func _spawn_big_black_bread() -> void:
	var spawn_pos = _get_spawn_position_near_camera_edge_in_area()
	var big_black = big__black_bread_scene.instantiate()
	big_black.global_position = spawn_pos
	if big_black.has_method("set_player_reference"):
		big_black.set_player_reference(player)
	if big_black.has_signal("tree_exited"):
		big_black.connect("tree_exited", Callable(self, "_on_enemy_died"))
	add_child(big_black)
	big_black.add_to_group("enemies")
	alive_enemies += 1
	print("Big Black Bread spawned!")

func _on_enemy_died() -> void:
	alive_enemies -= 1
	if alive_enemies <= 0 and spawned_count >= waves[current_wave]["total"]:
		if current_wave + 1 >= waves.size():
			# All waves complete, wait 5 seconds, then fade
			await get_tree().create_timer(5.0).timeout
			if is_instance_valid(fade_layer) and fade_layer.has_method("start_fade"):
				fade_layer.start_fade("res://Assets/Levels/Rest Areas/level_1.tscn")
		else:
			# Wave is truly complete (all spawned enemies are dead), start next wave after 3 seconds
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
