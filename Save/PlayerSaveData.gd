# res://Save/PlayerSaveData.gd
extends Resource
class_name PlayerSaveData

@export var scene_path: String
@export var position: Vector2
@export var aim_direction: Vector2
@export var health: int
@export var max_health: int
@export var current_orb_charges: int
@export var max_melee_orbs: int
@export var current_dash_slabs: int
@export var max_dash_slabs: int

# Add this so slots can show a friendly name
@export var save_name: String = ""
