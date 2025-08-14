extends Node

### --- SAVE SYSTEM CONSTANTS --- ###
const PLAYER_SAVE_PATH := "user://player_slot_1.tres"  # Path to save file
var _pending_save: PlayerSaveData = null                # Data waiting to be applied after scene load

### --- PLAYER REFERENCE METHODS --- ###
# Finds and returns the Player node in current scene
func get_player() -> Node:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		printerr("No current scene!")
		return null
	return find_player_in_scene(current_scene)

# Recursively searches scene for Player node with fallbacks
func find_player_in_scene(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	
	# Primary search for "Player" node
	var player = scene_root.find_child("Player", true, false)
	if player: 
		return player
	
	# Fallback search for CharacterBody2D in "player" group
	player = scene_root.find_child("CharacterBody2D", true, false)
	if player and player.is_in_group("player"): 
		return player
	
	printerr("Player node not found in scene!")
	return null

### --- SAVE DATA CREATION --- ###
# Creates and returns new PlayerSaveData resource with current state
func make_save_data() -> PlayerSaveData:
	var player = get_player()
	if player == null:
		return null

	# Create new save data instance
	var d = PlayerSaveData.new()
	
	# Scene information
	d.scene_path = get_tree().current_scene.scene_file_path
	
	# Player position and aiming
	d.position = player.global_position
	d.aim_direction = player.aim_direction
	
	# Health system
	d.health = player.health
	d.max_health = player.max_health
	
	# Melee orb system
	d.current_orb_charges = player.current_orb_charges
	d.max_melee_orbs = player.MAX_MELEE_ORBS
	
	# Dash slab system  
	d.current_dash_slabs = player.current_dash_slabs
	d.max_dash_slabs = player.MAX_DASH_SLABS
	
	return d

### --- SAVE OPERATIONS --- ###
# Saves current player state to file
func save_player():
	var data = make_save_data()
	if data == null:
		return
	
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute("user://")
	
	# Write save file
	var err = ResourceSaver.save(data, PLAYER_SAVE_PATH)
	if err != OK:
		printerr("Save failed: ", err)
	else:
		print("Player saved to: ", PLAYER_SAVE_PATH)

# Loads and returns saved data from file
func load_save_resource() -> PlayerSaveData:
	if not FileAccess.file_exists(PLAYER_SAVE_PATH):
		print("No save file found")
		return null
	
	# Load and validate save data
	var data = load(PLAYER_SAVE_PATH)
	if not data is PlayerSaveData:
		printerr("Invalid save file format")
		return null
	
	return data

### --- CONTINUE GAME FUNCTIONALITY --- ###
# Loads saved game and transitions to saved scene
func continue_game() -> void:
	# Load saved data
	var save_data = load_save_resource()
	if save_data == null:
		print("No save available")
		return

	# Validate scene path
	if save_data.scene_path == "":
		printerr("Save data has no scene path!")
		return

	# Store data for application after scene loads
	_pending_save = save_data
	
	# Change scene (deferred to ensure safe transition)
	var err = get_tree().change_scene_to_file(save_data.scene_path)
	if err != OK:
		printerr("Failed to change scene: ", err)
		_pending_save = null
		return
	
	# Schedule save data application
	call_deferred("_apply_pending_save")

# Applies saved data after new scene has loaded  
func _apply_pending_save():
	# Wait for scene to stabilize (2 frames)
	await get_tree().process_frame
	await get_tree().process_frame
	
	if _pending_save == null:
		return
	
	# Find player in new scene
	var player = get_player()
	if player == null:
		printerr("Player not found after scene load!")
		_pending_save = null
		return
	
	# Reference to save data
	var d = _pending_save
	
	### --- APPLY SAVED VALUES --- ###
	# Position and aiming
	player.global_position = d.position
	player.aim_direction = d.aim_direction
	
	# Health system
	player.health = clamp(d.health, 0, d.max_health)
	player.max_health = d.max_health
	
	# Melee orb system
	player.current_orb_charges = clamp(d.current_orb_charges, 0, d.max_melee_orbs)
	player.MAX_MELEE_ORBS = d.max_melee_orbs
	
	# Dash slab system
	player.current_dash_slabs = clamp(d.current_dash_slabs, 0, d.max_dash_slabs)
	player.MAX_DASH_SLABS = d.max_dash_slabs

	# Reset player state flags
	player.is_dashing = false
	player.is_attacking = false  
	player.is_hit = false
	player.is_dead = false

	print("Save data applied successfully")
	_pending_save = null
