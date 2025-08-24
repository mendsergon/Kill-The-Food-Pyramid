extends Control

### --- SCENE TRANSITION SYSTEM --- ###

# Called when node enters scene tree
func _ready() -> void:
	# Wait one frame to ensure all UI elements are properly initialized
	await get_tree().process_frame

### --- UI BUTTON HANDLERS --- ###

# Test area button pressed handler
func _on_test_area_pressed() -> void:
	_queue_scene_change("res://Assets/Levels/Test/game.tscn")

# New game button pressed handler  
func _on_new_game_pressed() -> void:
	_queue_scene_change("res://Assets/Menus/New Game Menu/new_game_menu.tscn")

# Load game button pressed handler (replaces Continue)
func _on_load_game_pressed() -> void:
	_queue_scene_change("res://Assets/Menus/Load Game Menu/load_game_menu.tscn")

### --- SCENE TRANSITION QUEUING --- ###

# Queues a scene change with maximum safety
func _queue_scene_change(path: String) -> void:
	# Double deferral to avoid physics step issues
	call_deferred("_safe_change_scene", path)

### --- SCENE TRANSITION EXECUTION --- ###

# Main scene change handler with full error checking
func _safe_change_scene(path: String) -> void:
	# Validate the scene path exists
	if not ResourceLoader.exists(path):
		printerr("Scene path does not exist:", path)
		return
	
	# Get validated scene tree reference
	var tree := await _get_valid_tree()
	if not tree:
		printerr("Cannot change scene - invalid scene tree")
		return
	
	# Execute the scene change
	var err := tree.change_scene_to_file(path)
	if err != OK:
		printerr("Scene change failed (", error_string(err), "):", path)
	else:
		print("Successfully changed scene to:", path)

### --- SCENE TREE VALIDATION --- ###

# Universal scene tree validator with null checks
func _get_valid_tree() -> SceneTree:
	# Wait until node is properly in scene tree
	if not is_inside_tree():
		await ready
	
	# Get tree reference with null check
	var tree := get_tree()
	if not tree:
		printerr("Scene tree reference is null")
		return null
	
	# Additional validation of current scene
	if not tree.current_scene:
		printerr("Current scene reference is null")
	
	return tree

### --- DEPRECATED METHODS (MAINTAINED FOR BACKWARDS COMPATIBILITY) --- ###

# Legacy scene change method (deprecated)
func _change_scene(path: String) -> void:
	printerr("Deprecated _change_scene called - use _safe_change_scene instead")
	_safe_change_scene(path)

# Legacy continue method (deprecated)  -- removed per request

func _on_back_pressed() -> void:
	_queue_scene_change("res://Assets/Menus/Main Menu/main_menu.tscn")
