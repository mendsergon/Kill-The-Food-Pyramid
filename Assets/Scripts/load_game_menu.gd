extends Control

### --- SCENE TRANSITION SYSTEM --- ###

func _ready() -> void:
	# Wait a frame to ensure UI elements are initialized
	await get_tree().process_frame
	_update_slot_labels()

### --- UI BUTTON HANDLERS --- ###

func _on_back_pressed() -> void:
	_queue_scene_change("res://Assets/Scenes/main_menu.tscn")

# Pressing a slot: ONLY continue (load) the save if it exists. Do NOT wipe or create a new save.
func _on_slot_1_pressed() -> void:
	_on_slot_pressed(1)

func _on_slot_2_pressed() -> void:
	_on_slot_pressed(2)

func _on_slot_3_pressed() -> void:
	_on_slot_pressed(3)

func _on_slot_pressed(slot: int) -> void:
	if not has_node("/root/SaveManager"):
		printerr("SaveManager autoload not found")
		return

	# Check if a save exists in this slot
	var data := SaveManager.load_save_resource(slot)
	if data != null and data.scene_path != "":
		# Set active slot and continue (load) the saved game
		if not _set_active_slot_on_manager(slot):
			printerr("_on_slot_pressed: Failed to set active slot %d on SaveManager" % slot)
			return
		print("Slot %d has a save — loading." % slot)
		# SaveManager.continue_game should handle changing scene and applying save
		if SaveManager.has_method("continue_game"):
			var ok := SaveManager.continue_game(slot)
			if not ok:
				printerr("_on_slot_pressed: SaveManager.continue_game failed for slot %d" % slot)
		else:
			# Fallback: directly instruct SaveManager to load slot via its API
			printerr("_on_slot_pressed: SaveManager missing continue_game method")
	else:
		# Slot empty: do nothing (menu remains open). Print to console so devs know.
		print("No save in slot %d — nothing to load." % slot)

### --- SLOT HANDLING --- ###

func _update_slot_labels() -> void:
	for slot in [1, 2, 3]:
		var label: Label = get_node_or_null("SLOT %d" % slot)
		if not label:
			continue
		
		if not has_node("/root/SaveManager"):
			label.text = "SLOT %d: EMPTY" % slot
			continue
		
		# Show slot state using SaveManager's loader (explicit slot)
		var data = SaveManager.load_save_resource(slot)
		if not data or data.scene_path == "":
			label.text = "SLOT %d: EMPTY" % slot
		else:
			label.text = "SLOT %d: %s" % [slot, data.scene_path.get_file()]

# Helper that tries to set active slot using SaveManager API, returns true on success
func _set_active_slot_on_manager(slot: int) -> bool:
	# Prefer API method if present
	if SaveManager.has_method("set_active_slot"):
		return SaveManager.set_active_slot(slot)
	# Otherwise try writing public variable current_slot
	if "current_slot" in SaveManager:
		SaveManager.current_slot = slot
		print("SaveManager: current_slot set to %d (direct write)" % slot)
		return true
	# If neither available, try fallback method names
	if SaveManager.has_variable("current_slot"):
		SaveManager.current_slot = slot
		print("SaveManager: current_slot set to %d (fallback)" % slot)
		return true

	printerr("_set_active_slot_on_manager: SaveManager doesn't expose set_active_slot or current_slot")
	return false

### --- SCENE TRANSITION QUEUING --- ###

func _queue_scene_change(path: String) -> void:
	# Call deferred to avoid physics/frame issues
	call_deferred("_safe_change_scene", path)

### --- SCENE TRANSITION EXECUTION --- ###

func _safe_change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		printerr("Scene path does not exist:", path)
		return
	
	var tree := await _get_valid_tree()
	if not tree:
		printerr("Cannot change scene - invalid scene tree")
		return
	
	var err := tree.change_scene_to_file(path)
	if err != OK:
		printerr("Scene change failed (", error_string(err), "):", path)
	else:
		print("Successfully changed scene to:", path)

### --- SCENE TREE VALIDATION --- ###

func _get_valid_tree() -> SceneTree:
	if not is_inside_tree():
		await get_tree().process_frame
	
	var tree := get_tree()
	if not tree:
		printerr("Scene tree reference is null")
		return null
	
	if not tree.current_scene:
		printerr("Current scene reference is null")
	
	return tree

### --- DEPRECATED METHODS --- ###

func _change_scene(path: String) -> void:
	printerr("Deprecated _change_scene called - use _safe_change_scene instead")
	_safe_change_scene(path)
