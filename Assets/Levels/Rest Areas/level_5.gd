extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var interaction_area_1: Area2D = $InteractionArea1  
@onready var fade_layer: CanvasLayer = $FadeLayer  
@onready var save: Label = $Player/Camera2D/Save

var save_timer: float = 0.0
var current_tween: Tween = null
var dialogue_state: int = 0  # 0 = not in dialogue, 1 = typing, 2 = waiting for input
var current_message: int = 0
var messages: Array = []
var typewriter_tween: Tween
var player_was_movable: bool = true  # Track player's movement state before dialogue
var dialogue_source: String = ""  # Tracks which NPC/dialogue started

func _ready() -> void:
	# Connect interaction area 1 (floor transition)
	if not interaction_area_1.is_connected("interacted", Callable(self, "_on_interaction_area_1_interacted")):
		interaction_area_1.connect("interacted", Callable(self, "_on_interaction_area_1_interacted"))
	
	save.modulate.a = 0.0  # Start fully transparent
	save.visible = false
	
	_load_player_stats()
	# --- Save immediately on scene start ---
	_save_player_on_scene_start()

func _load_player_stats() -> void:
	if not has_node("/root/SaveManager"):
		printerr("SaveManager autoload not found")
		return

	var save_data := SaveManager.load_save_resource()
	if save_data == null:
		print("No save data found for this slot — starting fresh")
		return

	if not is_instance_valid(player):
		printerr("Player node not found, cannot apply stats")
		return

	player.health = clamp(save_data.health, 0, save_data.max_health)
	player.max_health = save_data.max_health
	player.current_orb_charges = clamp(save_data.current_orb_charges, 0, save_data.max_melee_orbs)
	player.MAX_MELEE_ORBS = save_data.max_melee_orbs
	player.current_dash_slabs = clamp(save_data.current_dash_slabs, 0, save_data.max_dash_slabs)
	player.MAX_DASH_SLABS = save_data.max_dash_slabs
	player.current_weapon_index = save_data.current_weapon_index
	player.unlocked_weapons = save_data.unlocked_weapons

	if player.has_method("update_health_bar"):
		player.update_health_bar()
		
	if player.has_method("update_melee_orb_bar"):
		player.update_melee_orb_bar()

	player.switch_weapon(save_data.current_weapon_index)

	print("Loaded player stats from save slot %d" % SaveManager.current_slot)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		get_tree().reload_current_scene()
	
	# Handle save label timer
	if save_timer > 0:
		save_timer -= delta
		if save_timer <= 0.5 and save.modulate.a > 0:  # Fade out last 0.5 seconds
			if current_tween:
				current_tween.kill()
			current_tween = create_tween()
			current_tween.tween_property(save, "modulate:a", 0.0, 0.5)
		elif save_timer <= 0:
			save.visible = false
	
func _save_player_on_scene_start() -> void:
	if not has_node("/root/SaveManager"):
		printerr("SaveManager autoload not found")
		return

	var ok := SaveManager.save_player()
	if not ok:
		printerr("Save failed: no active slot or other error.")
		return

	# Wait until next frame to ensure save is complete
	await get_tree().process_frame
	_rename_save_to_0_5()

	# Show save UI
	if current_tween:
		current_tween.kill()
	save.visible = true
	save_timer = 2.0
	current_tween = create_tween()
	current_tween.tween_property(save, "modulate:a", 1.0, 0.2).from(0.0)

func _rename_save_to_0_5() -> void:
	var current_slot := SaveManager.current_slot
	print("=== DEBUG RENAME START ===")
	print("Current slot: ", current_slot)
	
	var path := ""
	if SaveManager.has_method("_get_slot_path"):
		path = SaveManager._get_slot_path(current_slot)
		print("Using _get_slot_path: ", path)
	else:
		path = "user://player_slot_%d.tres" % current_slot
		print("Using fallback path: ", path)

	if path == "":
		printerr("Invalid path for current slot")
		return

	# Check if file exists
	if not FileAccess.file_exists(path):
		printerr("SAVE FILE DOESN'T EXIST AT PATH: ", path)
		print("=== DEBUG RENAME END ===")
		return

	var save_res = load(path)
	if save_res and save_res is PlayerSaveData:
		print("BEFORE - Save name was: '", save_res.save_name, "'")
		save_res.save_name = " 0-5"
		print("AFTER - Save name set to: '", save_res.save_name, "'")
		
		var err = ResourceSaver.save(save_res, path)
		if err != OK:
			printerr("Failed to rewrite save with new name: ", error_string(err))
		else:
			print("SUCCESS: Save renamed to ' 0-5'")
			
			# Verify the change
			var verify_res = load(path)
			if verify_res and verify_res is PlayerSaveData:
				print("VERIFICATION - Save name is now: '", verify_res.save_name, "'")
			else:
				printerr("VERIFICATION FAILED: Could not reload save file")
	else:
		printerr("Save resource corrupted or missing - loaded: ", save_res)

	print("=== DEBUG RENAME END ===")

func _on_interaction_area_1_interacted() -> void:
	# Check player health to determine behavior
	return
