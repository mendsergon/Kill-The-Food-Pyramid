extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var enemy_group_1: Node2D = $Area1/EnemyGroup1
@onready var block_1: StaticBody2D = $Area1/Block1
@onready var block_2: StaticBody2D = $Area1/Block2
@onready var area_1: Area2D = $Area1

### --- SHARED STATE --- ###
var player_detected := false

func _ready() -> void:
	# Initially disable blocks
	_disable_blocks()
	
	# Connect area entrance signal
	if not area_1.body_entered.is_connected(_on_area_1_body_entered):
		area_1.body_entered.connect(_on_area_1_body_entered)
	
	# Set up enemies
	for enemy in enemy_group_1.get_children():
		if enemy.has_method("set_player_reference"):
			enemy.set_player_reference(player, self)
	
	# Connect enemy removal signal
	if not enemy_group_1.child_exiting_tree.is_connected(_on_enemy_removed):
		enemy_group_1.child_exiting_tree.connect(_on_enemy_removed)

### --- BLOCK CONTROL --- ###
func _enable_blocks() -> void:
	block_1.visible = true
	block_1.set_deferred("collision_layer", 1)
	block_1.set_deferred("collision_mask", 1)
	
	block_2.visible = true
	block_2.set_deferred("collision_layer", 1)
	block_2.set_deferred("collision_mask", 1)

func _disable_blocks() -> void:
	block_1.visible = false
	block_1.set_deferred("collision_layer", 0)
	block_1.set_deferred("collision_mask", 0)
	
	block_2.visible = false
	block_2.set_deferred("collision_layer", 0)
	block_2.set_deferred("collision_mask", 0)

### --- AREA EVENT --- ###
func _on_area_1_body_entered(body: Node) -> void:
	if body == player:
		_enable_blocks()

### --- ENEMY HANDLING --- ###
func _on_enemy_removed(_node: Node) -> void:
	# Check if this was the last enemy (1 left that's about to be removed)
	if enemy_group_1.get_child_count() == 1:
		print("All enemies defeated in Area1!")
		
		# Free the area
		area_1.queue_free()
		
		# Disable blocks
		_disable_blocks()

func set_player_detected(value: bool) -> void:
	player_detected = value
	if player_detected:
		print("Player detected! All enemies are now alert!")
