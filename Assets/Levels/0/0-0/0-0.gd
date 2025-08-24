extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var pistol_1: Area2D = $Pistol1

# Track if pistol has been interacted with
var pistol_interacted = false

func _ready() -> void:

	# Connect pistol interaction signal if not already connected
	if not pistol_1.is_connected("interacted", _on_pistol_1_interacted):
		pistol_1.connect("interacted", _on_pistol_1_interacted)
	
func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		get_tree().reload_current_scene()

func disable_block(block: StaticBody2D) -> void:
	if block:
		# Set collision layer and mask to 0 to completely disable collisions
		block.collision_layer = 0
		block.collision_mask = 0
		
		# Also hide the block
		block.hide()

func _on_pistol_1_interacted() -> void:
	if not pistol_interacted:
		pistol_interacted = true
		
		# Disable pistol completely
		pistol_1.queue_free()
		
		# Enable weapon 1 for the player
		if is_instance_valid(player):
			player.unlock_weapon(0)
