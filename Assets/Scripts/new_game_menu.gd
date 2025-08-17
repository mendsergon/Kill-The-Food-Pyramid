extends Control

@onready var slot_1: Button = $"MarginContainer/VBoxContainer/SLOT 1"
@onready var slot_2: Button = $"MarginContainer/VBoxContainer/SLOT 2"
@onready var slot_3: Button = $"MarginContainer/VBoxContainer/SLOT 3"

### --- NEW GAME MENU --- ###

func _ready() -> void:
	await get_tree().process_frame
	_update_slot_labels()

func _on_back_pressed() -> void:
	_queue_scene_change("res://Assets/Scenes/main_menu.tscn")

func _on_slot_1_pressed() -> void:
	_start_new_game(1)

func _on_slot_2_pressed() -> void:
	_start_new_game(2)

func _on_slot_3_pressed() -> void:
	_start_new_game(3)

### --- START NEW GAME --- ###
func _start_new_game(slot: int) -> void:
	if not has_node("/root/SaveManager"):
		printerr("SaveManager autoload not found")
		return

	# 1) Set active slot on SaveManager
	var set_ok := false
	if SaveManager.has_method("set_active_slot"):
		set_ok = SaveManager.set_active_slot(slot)
	elif "current_slot" in SaveManager:
		SaveManager.current_slot = slot
		set_ok = true
		print("SaveManager: current_slot set to %d (direct write)" % slot)

	if not set_ok:
		printerr("_start_new_game: SaveManager did not accept slot %d" % slot)
		return

	# 2) Create initial PlayerSaveData
	var initial := PlayerSaveData.new()
	initial.scene_path = "res://Assets/Scenes/level_0.tscn"
	initial.position = Vector2.ZERO
	# Default save names per slot
	match slot:
		1: initial.save_name = "1-1"
		2: initial.save_name = "1-1"
		3: initial.save_name = "1-1"
		_: initial.save_name = "NEW"

	# 3) Determine file path
	var path := ""
	if SaveManager.has_method("_get_slot_path"):
		path = SaveManager._get_slot_path(slot)
	else:
		path = "user://player_slot_%d.tres" % slot

	if path == "":
		printerr("_start_new_game: invalid path for slot %d" % slot)
		return

	# Ensure user:// exists
	var dir_ok = DirAccess.make_dir_recursive_absolute("user://")
	if dir_ok != OK and dir_ok != ERR_ALREADY_EXISTS:
		printerr("_start_new_game: failed to ensure user:// directory (err=%s)" % dir_ok)

	# 4) Save the initial resource
	var err := ResourceSaver.save(initial, path)
	if err != OK:
		printerr("_start_new_game: Failed to write initial save to slot %d: %s" % [slot, error_string(err)])
		return

	print("_start_new_game: Slot %d initialized and saved to %s" % [slot, path])

	# 5) Refresh button labels and change scene
	_update_slot_labels()
	_queue_scene_change(initial.scene_path)

### --- SLOT BUTTON LABELS --- ###
func _update_slot_labels() -> void:
	var buttons = [slot_1, slot_2, slot_3]
	for i in range(3):
		var slot = i + 1
		var button: Button = buttons[i]

		var path := ""
		if has_node("/root/SaveManager") and SaveManager.has_method("_get_slot_path"):
			path = SaveManager._get_slot_path(slot)
		else:
			path = "user://player_slot_%d.tres" % slot

		if path == "" or not FileAccess.file_exists(path):
			button.text = "SLOT %d: EMPTY" % slot
			continue

		var res = load(path)
		if res and res is PlayerSaveData:
			var name_to_show := ""
			if res.save_name != "":
				name_to_show = res.save_name
			elif res.scene_path != "":
				name_to_show = res.scene_path.get_file()
			else:
				name_to_show = "<corrupt>"

			button.text = "SLOT %d:  %s" % [slot, name_to_show]
		else:
			button.text = "SLOT %d: <corrupt>" % slot

### --- SCENE CHANGE HELPERS --- ###
func _queue_scene_change(path: String) -> void:
	call_deferred("_safe_change_scene", path)

func _safe_change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		printerr("Scene path does not exist:", path)
		return
	var tree := await _get_valid_tree()
	if not tree:
		printerr("Invalid scene tree")
		return
	var err := tree.change_scene_to_file(path)
	if err != OK:
		printerr("Scene change failed:", error_string(err))

func _get_valid_tree() -> SceneTree:
	if not is_inside_tree():
		await get_tree().process_frame
	return get_tree()
