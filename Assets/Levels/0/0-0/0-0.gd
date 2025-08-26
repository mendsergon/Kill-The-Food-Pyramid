extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var camera_2d_2: Camera2D = $Player/Camera2D2
@onready var pistol_1: Area2D = $Pistol1
@onready var block_1: StaticBody2D = $Blocks/Block1
@onready var block_2: StaticBody2D = $Blocks/Block2
@onready var block_3: StaticBody2D = $Blocks/Block3
@onready var block_4: StaticBody2D = $Blocks/Block4
@onready var room_1_area_2d: Area2D = $Rooms/Room1Area2D
@onready var exit: Area2D = $Exit
@onready var flash_layer: CanvasLayer = $FlashLayer

# Track if pistol has been interacted with
var pistol_interacted = false

func _ready() -> void:

		# Connect pistol interaction signal if not already connected
		if not pistol_1.is_connected("interacted", _on_pistol_1_interacted):
				pistol_1.connect("interacted", _on_pistol_1_interacted)
		
		# Disable block 2 by default and enable block 1
		disable_block(block_2)
		enable_block(block_1)
		

func _process(_delta: float) -> void:
		if not is_instance_valid(player):
				print("Player node is null")
				return

func disable_block(block: StaticBody2D) -> void:
		if block:
				# Set collision layer and mask to 0 to completely disable collisions
				block.collision_layer = 0
				block.collision_mask = 0
				
				# Also hide the block
				block.hide()

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
								
				# Disable pistol completely
				pistol_1.queue_free()
				
				# Enable weapon 1 for the player
				if is_instance_valid(player):
						player.unlock_weapon(0)
				
				# Disable block 1 on pistol interaction
				disable_block(block_1)

func _on_room_1_area_2d_body_entered(_body: Node2D) -> void:
	enable_block(block_2)
	
	# Hide main camera and enable secondary camera
	if camera_2d:
		camera_2d.enabled = false
	
	if camera_2d_2:
		camera_2d_2.enabled = true
	
	# Disconnect the signal to prevent retriggering
	if room_1_area_2d and room_1_area_2d.is_connected("body_entered", _on_room_1_area_2d_body_entered):
		room_1_area_2d.disconnect("body_entered", _on_room_1_area_2d_body_entered)
	
	if flash_layer:
		# Trigger the flash effect on the flash layer
		flash_layer.trigger_flash()
	else:
		print("FlashLayer node is not available")

func _on_exit_interacted() -> void:
		pass # Replace with function body.
