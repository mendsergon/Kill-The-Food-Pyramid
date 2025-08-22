extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var pistol_1: Area2D = $Pistol1
@onready var block_1: StaticBody2D = $Rooms/Room1/Block1
@onready var block_2: StaticBody2D = $Rooms/Room1/Block2
@onready var block_3: StaticBody2D = $Rooms/Room2/Block3
@onready var block_4: StaticBody2D = $Rooms/Room2/Block4
@onready var block_5: StaticBody2D = $Rooms/Room3/Block5
@onready var block_6: StaticBody2D = $Rooms/Room3/Block6
@onready var bread_1: CharacterBody2D = $Rooms/Room1/Bread1
@onready var bread_2: CharacterBody2D = $Rooms/Room1/Bread2
@onready var bread_3: CharacterBody2D = $Rooms/Room1/Bread3
@onready var room_2_area_2d: Area2D = $Rooms/Room2/Room2Area2D

var bread_scene: PackedScene = preload("res://Assets/Scenes/bread.tscn")
var black_bread_scene: PackedScene = preload("res://Assets/Scenes/black_bread.tscn")

# Track if pistol has been interacted with
var pistol_interacted = false
# Track if bread enemies are alive
var breads_alive = false

# Room 2 variables
var room_2_activated = false
var room_2_first_batch = []
var room_2_second_batch = []
var room_2_enemies_defeated = 0
var room_2_total_enemies = 10

func _ready() -> void:
	# Disable all blocks at the beginning by disabling their collision shapes
	disable_all_blocks()
	
	# Disable all bread enemies at the beginning
	disable_all_breads()
	
	# Connect pistol interaction signal if not already connected
	if not pistol_1.is_connected("interacted", _on_pistol_1_interacted):
		pistol_1.connect("interacted", _on_pistol_1_interacted)
	
	# Connect Room2 area signals
	if not room_2_area_2d.is_connected("body_entered", _on_room_2_area_2d_body_entered):
		room_2_area_2d.connect("body_entered", _on_room_2_area_2d_body_entered)
	if not room_2_area_2d.is_connected("body_exited", _on_room_2_area_2d_body_exited):
		room_2_area_2d.connect("body_exited", _on_room_2_area_2d_body_exited)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		get_tree().reload_current_scene()
	
	# Check if bread enemies are still alive
	if breads_alive:
		check_breads_status()
	
	# Check if Room2 enemies are defeated
	if room_2_activated:
		check_room_2_enemies()

func disable_all_blocks() -> void:
	# Disable all blocks by disabling their collision shapes
	disable_block(block_1)
	disable_block(block_2)
	disable_block(block_3)
	disable_block(block_4)
	disable_block(block_5)
	disable_block(block_6)

func disable_block(block: StaticBody2D) -> void:
	if block:
		# Disable the collision shape of the block
		for child in block.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)
		
		# Also hide the block
		block.hide()

func enable_blocks_1_and_2() -> void:
	# Enable only blocks 1 and 2
	enable_block(block_1)
	enable_block(block_2)

func enable_block(block: StaticBody2D) -> void:
	if block:
		# Enable the collision shape of the block
		for child in block.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)
		
		# Also show the block
		block.show()

func disable_all_breads() -> void:
	# Disable all bread enemies
	disable_bread(bread_1)
	disable_bread(bread_2)
	disable_bread(bread_3)

func disable_bread(bread: CharacterBody2D) -> void:
	if bread:
		# Disable physics processing
		bread.set_physics_process(false)
		bread.set_process(false)
		
		# Hide the bread
		bread.hide()
		
		# Disable collision for bread by disabling its collision shapes
		for child in bread.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)
		
		# Also disable the CharacterBody2D itself
		bread.set_deferred("disabled", true)

func enable_all_breads() -> void:
	# Enable all bread enemies
	enable_bread(bread_1)
	enable_bread(bread_2)
	enable_bread(bread_3)
	breads_alive = true

func enable_bread(bread: CharacterBody2D) -> void:
	if bread and is_instance_valid(bread):
		# Enable physics processing
		bread.set_physics_process(true)
		bread.set_process(true)
		
		# Show the bread
		bread.show()
		
		# Enable collision for bread by enabling its collision shapes
		for child in bread.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)
		
		# Also enable the CharacterBody2D itself
		bread.set_deferred("disabled", false)
		
		# Set player reference if the bread has that method
		if bread.has_method("set_player_reference") and is_instance_valid(player):
			bread.set_player_reference(player)

func check_breads_status() -> void:
	# Check if all bread enemies are dead or not valid
	var bread1_dead = not is_instance_valid(bread_1) or bread_1.is_queued_for_deletion()
	var bread2_dead = not is_instance_valid(bread_2) or bread_2.is_queued_for_deletion()
	var bread3_dead = not is_instance_valid(bread_3) or bread_3.is_queued_for_deletion()
	
	if bread1_dead and bread2_dead and bread3_dead:
		# Disable blocks 1 and 2 when all breads are dead
		disable_block(block_1)
		disable_block(block_2)
		breads_alive = false

func _on_pistol_1_interacted() -> void:
	if not pistol_interacted:
		pistol_interacted = true
		
		# Enable blocks 1 and 2
		enable_blocks_1_and_2()
		
		# Enable bread enemies
		enable_all_breads()
		
		# Disable pistol completely
		pistol_1.queue_free()
		
		# Enable weapon 1 for the player
		if is_instance_valid(player):
			player.unlock_weapon(0)

func _on_room_2_area_2d_body_entered(body: Node2D) -> void:
	if body == player and not room_2_activated:
		room_2_activated = true
		
		# Enable blocks 3 and 4
		enable_block(block_3)
		enable_block(block_4)
		
		# Spawn first batch of 5 enemies
		spawn_room_2_enemies(5)

func _on_room_2_area_2d_body_exited(body: Node2D) -> void:
	# Optional: Handle player exiting the area
	pass

func spawn_room_2_enemies(count: int) -> void:
	var room_node = $Rooms/Room2  # Parent node for the enemies
	
	for i in range(count):
		# Randomly choose between bread and black bread
		var enemy_scene = bread_scene if randf() < 0.5 else black_bread_scene
		var enemy = enemy_scene.instantiate()
		
		# Set random position within Room2 area
		var area_rect = get_area_rect(room_2_area_2d)
		enemy.position = Vector2(
			randf_range(area_rect.position.x, area_rect.end.x),
			randf_range(area_rect.position.y, area_rect.end.y)
		)
		
		# Add to the appropriate batch
		if room_2_first_batch.size() < 5:
			room_2_first_batch.append(enemy)
		else:
			room_2_second_batch.append(enemy)
			# Hide the second batch initially
			disable_bread(enemy)
		
		# Add to scene and set up
		room_node.add_child(enemy)
		
		# Set player reference if the enemy has that method
		if enemy.has_method("set_player_reference") and is_instance_valid(player):
			enemy.set_player_reference(player)
		
		# Connect to death signal if available
		if enemy.has_signal("died"):
			enemy.connect("died", Callable(self, "_on_room_2_enemy_died"))

func get_area_rect(area: Area2D) -> Rect2:
	# Get the bounding rectangle of the area
	var collision_shape = area.get_node("CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var shape = collision_shape.shape as RectangleShape2D
		var pos = collision_shape.global_position
		var size = shape.size
		return Rect2(pos - size/2, size)
	
	# Fallback to a default size if not a rectangle
	return Rect2(area.global_position, Vector2(300, 300))

func check_room_2_enemies() -> void:
	# Check if first batch is defeated
	var first_batch_defeated = true
	for enemy in room_2_first_batch:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			first_batch_defeated = false
			break
	
	# Spawn second batch if first is defeated
	if first_batch_defeated and room_2_second_batch.size() > 0:
		for enemy in room_2_second_batch:
			enable_bread(enemy)

func _on_room_2_enemy_died() -> void:
	room_2_enemies_defeated += 1
	
	# Check if all enemies are defeated
	if room_2_enemies_defeated >= room_2_total_enemies:
		# Optional: Do something when all enemies are defeated
		print("All Room 2 enemies defeated!")
