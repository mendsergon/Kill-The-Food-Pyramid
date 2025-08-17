# SaveManager.gd - put this in Autoload as "SaveManager"
extends Node

### --- SAVE SYSTEM CONSTANTS --- ###
const SAVE_PATHS := {
	1: "user://player_slot_1.tres",
	2: "user://player_slot_2.tres",
	3: "user://player_slot_3.tres"
}

### --- STATE VARIABLES --- ###
var _pending_save: PlayerSaveData = null   # Data waiting to be applied after scene load
var current_slot: int = -1                 # Active save slot (-1 means none selected)

### --- API: set/get active slot --- ###
func set_active_slot(slot: int) -> bool:
	if not SAVE_PATHS.has(slot):
		printerr("SaveManager.set_active_slot: invalid slot:", slot)
		return false
	current_slot = slot
	print("SaveManager: active slot set to", slot)
	return true

func get_active_slot() -> int:
	return current_slot

### --- PLAYER REFERENCE METHODS --- ###
func get_player() -> Node:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		printerr("SaveManager.get_player: No current scene!")
		return null
	return find_player_in_scene(current_scene)

func find_player_in_scene(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	var player = scene_root.find_child("Player", true, false)
	if player:
		return player
	player = scene_root.find_child("CharacterBody2D", true, false)
	if player and player.is_in_group("player"):
		return player
	printerr("SaveManager.find_player_in_scene: Player node not found in scene!")
	return null

### --- SAVE DATA CREATION --- ###
func make_save_data() -> PlayerSaveData:
	var player = get_player()
	if player == null:
		printerr("SaveManager.make_save_data: Player not found, cannot make save data")
		return null
	var d = PlayerSaveData.new()
	d.scene_path = get_tree().current_scene.scene_file_path
	d.position = player.global_position
	d.aim_direction = player.aim_direction
	d.health = player.health
	d.max_health = player.max_health
	d.current_orb_charges = player.current_orb_charges
	d.max_melee_orbs = player.MAX_MELEE_ORBS
	d.current_dash_slabs = player.current_dash_slabs
	d.max_dash_slabs = player.MAX_DASH_SLABS
	return d

### --- INTERNAL PATH HELPERS --- ###
func _get_slot_path(slot: int) -> String:
	if not SAVE_PATHS.has(slot):
		printerr("SaveManager._get_slot_path: Invalid save slot:", slot)
		return ""
	return SAVE_PATHS[slot]

### --- SAVE / LOAD OPERATIONS --- ###
# Save to the active slot if slot == -1, otherwise to provided slot.
# Returns `true` on success, `false` on failure.
func save_player(slot: int = -1) -> bool:
	var target_slot = slot if slot != -1 else current_slot
	if target_slot == -1:
		printerr("SaveManager.save_player: No active save slot set! Cannot save.")
		return false

	var path := _get_slot_path(target_slot)
	if path == "":
		return false

	var data = make_save_data()
	if data == null:
		printerr("SaveManager.save_player: Failed to create save data.")
		return false

	# Ensure save directory exists
	var ok_dir = DirAccess.make_dir_recursive_absolute("user://")
	if ok_dir != OK and ok_dir != ERR_ALREADY_EXISTS:
		printerr("SaveManager.save_player: Failed to ensure user:// directory (err=%s)" % ok_dir)
		# still attempt save below; but warn

	var err = ResourceSaver.save(data, path)
	if err != OK:
		printerr("SaveManager.save_player: Save failed in slot %d: %s" % [target_slot, error_string(err)])
		return false

	print("SaveManager: Player saved to slot %d at %s" % [target_slot, path])
	return true

# Loads a resource from slot (if slot omitted uses active slot). Returns null on failure.
func load_save_resource(slot: int = -1) -> PlayerSaveData:
	var target_slot = slot if slot != -1 else current_slot
	if target_slot == -1:
		# Do not print heavy error here: menu may probe slots by passing explicit slot.
		return null

	var path := _get_slot_path(target_slot)
	if path == "":
		return null

	if not FileAccess.file_exists(path):
		return null

	var data = load(path)
	if not data is PlayerSaveData:
		printerr("SaveManager.load_save_resource: Invalid save file format in slot %d" % target_slot)
		return null
	return data

### --- CONTINUE / APPLY --- ###
func continue_game(slot: int = -1) -> bool:
	var target_slot = slot if slot != -1 else current_slot
	if target_slot == -1:
		printerr("SaveManager.continue_game: No active save slot set! Cannot continue.")
		return false

	var save_data = load_save_resource(target_slot)
	if save_data == null:
		print("SaveManager.continue_game: No save available in slot %d" % target_slot)
		return false

	if save_data.scene_path == "":
		printerr("SaveManager.continue_game: Save data has no scene path! (slot %d)" % target_slot)
		return false

	current_slot = target_slot
	_pending_save = save_data

	var err = get_tree().change_scene_to_file(save_data.scene_path)
	if err != OK:
		printerr("SaveManager.continue_game: Failed to change scene for slot %d: %s" % [target_slot, error_string(err)])
		_pending_save = null
		return false

	call_deferred("_apply_pending_save")
	return true

func _apply_pending_save():
	await get_tree().process_frame
	await get_tree().process_frame

	if _pending_save == null:
		return

	var player = get_player()
	if player == null:
		printerr("SaveManager._apply_pending_save: Player not found after scene load!")
		_pending_save = null
		return

	var d = _pending_save
	player.global_position = d.position
	player.aim_direction = d.aim_direction
	player.health = clamp(d.health, 0, d.max_health)
	player.max_health = d.max_health
	player.current_orb_charges = clamp(d.current_orb_charges, 0, d.max_melee_orbs)
	player.MAX_MELEE_ORBS = d.max_melee_orbs
	player.current_dash_slabs = clamp(d.current_dash_slabs, 0, d.max_dash_slabs)
	player.MAX_DASH_SLABS = d.max_dash_slabs
	player.is_dashing = false
	player.is_attacking = false
	player.is_hit = false
	player.is_dead = false

	print("SaveManager: Save data applied successfully (slot %d)" % current_slot)
	_pending_save = null
