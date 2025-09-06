extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player

## Area 1
@onready var enemy_group_1: Node2D = $Area1/EnemyGroup1
@onready var block_1: StaticBody2D = $Area1/Block1
@onready var block_2: StaticBody2D = $Area1/Block2
@onready var area_1: Area2D = $Area1

## Area 2
@onready var enemy_group_2: Node2D = $Area2/EnemyGroup2
@onready var block_3: StaticBody2D = $Area2/Block3
@onready var block_4: StaticBody2D = $Area2/Block4
@onready var area_2: Area2D = $Area2

# Dictionary to store all area data
var areas := {}
var area_alert_states := {}  # Track alert status per area

func _ready() -> void:
	# Wait until all nodes are properly loaded
	await get_tree().process_frame
	
	# Set up all areas
	_setup_areas()
	
	# Initially disable all blocks
	_disable_all_blocks()
	
	# NOTE: We intentionally do NOT connect signals here to avoid overload confusion.
	# Instead we poll area overlap and enemy counts in _physics_process().

func _setup_areas() -> void:
	# Initialize each area with its components only if nodes exist
	if is_instance_valid(area_1) and is_instance_valid(enemy_group_1):
		areas["Area1"] = {
			"area_node": area_1,
			"enemy_group": enemy_group_1,
			"blocks": [block_1, block_2],
			"active": false,
			"cleared": false
		}
		area_alert_states["Area1"] = false
	
	if is_instance_valid(area_2) and is_instance_valid(enemy_group_2):
		areas["Area2"] = {
			"area_node": area_2,
			"enemy_group": enemy_group_2,
			"blocks": [block_3, block_4],
			"active": false,
			"cleared": false
		}
		area_alert_states["Area2"] = false
	
	# Set up enemies for each area
	for area_name in areas:
		var area_data = areas[area_name]
		if area_data and area_data.has("enemy_group") and is_instance_valid(area_data["enemy_group"]):
			for enemy in area_data["enemy_group"].get_children():
				if not enemy:
					continue
				# Set area metadata first so enemies can read it in set_player_reference
				enemy.set_meta("area_name", area_name)
				# Pass both player and area manager reference (2 arguments)
				if enemy.has_method("set_player_reference"):
					enemy.set_player_reference(player, self)

### --- BLOCK CONTROL --- ###
func _enable_blocks(area_name: String) -> void:
	var area_data = areas.get(area_name)
	if not area_data:
		return
	
	for block in area_data["blocks"]:
		if is_instance_valid(block):
			block.visible = true
			# Use deferred property set to avoid changing physics during iteration
			block.set_deferred("collision_layer", 1)
			block.set_deferred("collision_mask", 1)
	
	area_data["active"] = true

func _disable_blocks(area_name: String) -> void:
	var area_data = areas.get(area_name)
	if not area_data:
		return
	
	for block in area_data["blocks"]:
		if is_instance_valid(block):
			block.visible = false
			block.set_deferred("collision_layer", 0)
			block.set_deferred("collision_mask", 0)
	
	area_data["active"] = false

func _disable_all_blocks() -> void:
	for area_name in areas:
		_disable_blocks(area_name)

### --- POLLING (REPLACES SIGNAL CONNECTS) --- ###
# We poll area overlap and enemy counts once per physics frame to avoid connect() overload issues.
func _physics_process(delta: float) -> void:
	for area_name in areas:
		var area_data = areas[area_name]
		if not area_data:
			continue
		
		# Skip if already cleared (freed)
		if area_data.get("cleared", false):
			continue
		
		# 1) Check player entering area -> enable blocks
		var area_node: Area2D = area_data["area_node"]
		if is_instance_valid(area_node) and not area_data["active"]:
			# get_overlapping_bodies requires the Area2D to have monitoring enabled in the editor
			var bodies := area_node.get_overlapping_bodies()
			if bodies and bodies.has(player):
				_enable_blocks(area_name)
				print("Player entered ", area_name)
		
		# 2) Check if enemies are gone -> free area and disable blocks
		var eg = area_data["enemy_group"]
		if is_instance_valid(eg):
			if eg.get_child_count() == 0:
				# mark cleared so we don't run this repeatedly
				area_data["cleared"] = true
				print("All enemies defeated in ", area_name, "!")
				if is_instance_valid(area_data["area_node"]):
					area_data["area_node"].queue_free()
				_disable_blocks(area_name)

### --- AREA EVENT (unused by polling but kept for API compatibility) --- ###
# If you still want to call this from an Area2D or enemy directly, it will still work.
func _on_area_body_entered(body: Node, area_name: String) -> void:
	if body == player:
		var area_data = areas.get(area_name)
		if area_data and not area_data["active"]:
			_enable_blocks(area_name)
			print("Player entered (signal) ", area_name)

### --- ENEMY HANDLING (kept for compatibility) --- ###
# If you keep child_exiting_tree signals in the scene, they'll call this.
# We still do nothing here because the polling handles the removal flow.
func _on_enemy_removed(_node: Node, area_name: String) -> void:
	# No-op (polling handles the logic). Kept for compatibility.
	pass

# Area-wide alert function
func alert_area_enemies(area_name: String) -> void:
	var area_data = areas.get(area_name)
	if not area_data:
		return
	
	# Only alert if the area isn't already alerted
	if area_alert_states.get(area_name, false):
		return
	
	# Mark area as alerted
	area_alert_states[area_name] = true
	
	# Alert all enemies in this area
	for enemy in area_data["enemy_group"].get_children():
		if is_instance_valid(enemy) and enemy.has_method("set_alert_status"):
			enemy.set_alert_status(true)
	
	print("All enemies in ", area_name, " are now alert!")
