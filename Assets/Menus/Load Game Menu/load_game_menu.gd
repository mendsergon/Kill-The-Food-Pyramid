extends Control

@onready var slot_1: Button = $"MarginContainer/VBoxContainer/SLOT 1"
@onready var slot_2: Button = $"MarginContainer/VBoxContainer/SLOT 2"
@onready var slot_3: Button = $"MarginContainer/VBoxContainer/SLOT 3"

### --- LOAD GAME MENU --- ###
func _ready() -> void:
	await get_tree().process_frame
	_update_slot_labels()

func _on_back_pressed() -> void:
	_queue_scene_change("res://Assets/Menus/Level Menu/level_menu.tscn")

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

	var path := SaveManager._get_slot_path(slot) if SaveManager.has_method("_get_slot_path") else "user://player_slot_%d.tres" % slot
	if not FileAccess.file_exists(path):
		print("No save in slot %d — nothing to load." % slot)
		return

	var res = load(path)
	if not (res and res is PlayerSaveData) or res.scene_path == "":
		printerr("_on_slot_pressed: Save file for slot %d invalid or missing scene_path" % slot)
		return

	# Set active slot first so in-level saves go to this slot
	if SaveManager.has_method("set_active_slot"):
		if not SaveManager.set_active_slot(slot):
			printerr("_on_slot_pressed: SaveManager refused set_active_slot(%d)" % slot)
			return
	else:
		if "current_slot" in SaveManager:
			SaveManager.current_slot = slot

	# Ask SaveManager to continue (it will change scene and apply save)
	if SaveManager.has_method("continue_game"):
		var ok := SaveManager.continue_game(slot)
		if not ok:
			printerr("_on_slot_pressed: SaveManager.continue_game failed for slot %d" % slot)
	else:
		printerr("_on_slot_pressed: SaveManager missing continue_game method")

### --- SLOT BUTTON LABELS --- ###
func _update_slot_labels() -> void:
	var buttons = [slot_1, slot_2, slot_3]
	for i in range(3):
		var slot = i + 1
		var button: Button = buttons[i]

		var path := SaveManager._get_slot_path(slot) if SaveManager.has_method("_get_slot_path") else "user://player_slot_%d.tres" % slot
		if path == "" or not FileAccess.file_exists(path):
			button.text = "SLOT %d: EMPTY" % slot
			continue

		var res = load(path)
		if res and res is PlayerSaveData:
			var name_to_show: String = ""
			if res.save_name != "":
				name_to_show = res.save_name
			elif res.scene_path != "":
				name_to_show = res.scene_path.get_file()
			else:
				name_to_show = "<corrupt>"
			button.text = "SLOT %d: %s" % [slot, name_to_show]
		else:
			button.text = "SLOT %d: <corrupt>" % slot

### --- SCENE HELPERS --- ###
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
