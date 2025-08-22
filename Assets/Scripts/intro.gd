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
@onready var room_2_area_2d: Area2D = $Rooms/Room2/Room2Area2D

# Track if pistol has been interacted with
var pistol_interacted = false

func _ready() -> void:
	# Disable all blocks at the beginning by setting collision to 0 and hiding them
	disable_all_blocks()
	
	# Enable only block_2 at the beginning
	enable_block(block_2)
	
	# Connect pistol interaction signal if not already connected
	if not pistol_1.is_connected("interacted", _on_pistol_1_interacted):
		pistol_1.connect("interacted", _on_pistol_1_interacted)
	
	# Connect Room2 area signals
	if not room_2_area_2d.is_connected("body_entered", _on_room_2_area_2d_body_entered):
		room_2_area_2d.connect("body_entered", _on_room_2_area_2d_body_entered)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		get_tree().reload_current_scene()

func disable_all_blocks() -> void:
	# Disable all blocks by setting collision to 0 and hiding them
	disable_block(block_1)
	disable_block(block_2)
	disable_block(block_3)
	disable_block(block_4)
	disable_block(block_5)
	disable_block(block_6)

func disable_block(block: StaticBody2D) -> void:
	if block:
		# Set collision layer and mask to 0 to completely disable collisions
		block.collision_layer = 0
		block.collision_mask = 0
		
		# Also hide the block
		block.hide()

func enable_blocks_1_and_2() -> void:
	# Enable only blocks 1 and 2
	enable_block(block_1)
	enable_block(block_2)

func enable_block(block: StaticBody2D) -> void:
	if block:
		# Set collision layer and mask to 1 to enable collisions
		block.collision_layer = 1
		block.collision_mask = 1
		
		# Also show the block
		block.show()

func _on_pistol_1_interacted() -> void:
	if not pistol_interacted:
		pistol_interacted = true
		
		
		disable_block(block_2)
		
		# Disable pistol completely
		pistol_1.queue_free()
		
		# Enable weapon 1 for the player
		if is_instance_valid(player):
			player.unlock_weapon(0)

func _on_room_2_area_2d_body_entered(body: Node2D) -> void:
	if body == player:
		# Enable blocks 3 and 4 when player enters Room 2
		enable_block(block_3)
		enable_block(block_4)
