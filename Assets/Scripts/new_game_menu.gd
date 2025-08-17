extends Control

### --- SCENE TRANSITION SYSTEM --- ###

func _ready() -> void:
	# Wait a frame to ensure UI elements are initialized
	await get_tree().process_frame
	_update_slot_labels()

### --- UI BUTTON HANDLERS --- ###

func _on_back_pressed() -> void:
	_queue_scene_change("res://Assets/Scenes/main_menu.tscn")

# Pressing a slot: continue if a save exists for that slot, otherwise start a new game in that slot.
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

	# If a save exists in this slot -> set it active and continue
	var data := SaveManager.load_save_resource(slot)
	if data != null and data.scene_path != "":
		# set active slot first
		_set_active_slot_on_manager(slot)
		print("Slot %d has a save — continuing." % slot)
		SaveManager.continue_game(slot)
	else:
		# No save: initialize slot then set it active and start new game
		_start_new_game(slot)

### --- SLOT HANDLING --- ###

func _update_slot_labels() -> void:
	for slot in [1, 2, 3]:
		var label: Label = get_node_or_null("SLOT %d" % slot)
		if not label:
			continue
		
		if not has_node("/root/SaveManager"):
			label.text = "SLOT %d: EMPTY" % slot
			continue
		
		# Use explicit slot load: SaveManager.load_save_resource(slot) should accept a slot param
		var data = SaveManager.load_save_resource(slot)
		if not data or data.scene_path == "":
			label.text = "SLOT %d: EMPTY" % slot
		else:
			# Show just the scene file name for readability
			label.text = "SLOT %d: %s" % [slot, data.scene_path.get_file()]

# Start a new game in a given slot (initialize and set active)
func _start_new_game(slot: int) -> void:
	if not has_node("/root/SaveManager"):
		printerr("SaveManager autoload not found")
		return

	# Set active slot on SaveManager (so in-scene saves will go there)
	if not _set_active_slot_on_manager(slot):
		printerr("_start_new_game: Failed to set active slot %d" % slot)
		# still continue, but SaveManager.save_player() will fail until fixed
	# Prepare initial save data
	var data := PlayerSaveData.new()
	data.scene_path = "res://Assets/Scenes/level_0.tscn"
	data.position = Vector2.ZERO

	# Save initial data into slot via SaveManager API (recommended)
	var saved_ok := false
	if SaveManager.has_method("save_player"):
		saved_ok = SaveManager.save_player(slot)
	else:
		# fallback: write resource directly (kept for compatibility)
		var path := SaveManager._get_slot_path(slot) if SaveManager.has_method("_get_slot_path") else "user://player_slot_%d.tres" % slot
		if path != "":
			var err := ResourceSaver.save(data, path)
			saved_ok = (err == OK)
	
	if not saved_ok:
		printerr("_start_new_game: Failed to write initial save to slot %d" % slot)
	else:
		print("_start_new_game: Slot %d initialized and saved" % slot)

	_update_slot_labels()
	_queue_scene_change(data.scene_path)

# Helper that tries to set active slot using SaveManager API, returns true on success
func _set_active_slot_on_manager(slot: int) -> bool:
	# Use API method if present, otherwise write field directly
	if SaveManager.has_method("set_active_slot"):
		return SaveManager.set_active_slot(slot)
	elif SaveManager.has_variable("current_slot"):
		SaveManager.current_slot = slot
		print("SaveManager: current_slot set to %d (direct write)" % slot)
		return true
	else:
		# fallback attempt: set property via raw assignment (might still work)
		if "current_slot" in SaveManager:
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
