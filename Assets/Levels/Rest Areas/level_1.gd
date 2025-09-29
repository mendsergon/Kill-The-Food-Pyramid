extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var interaction_area_1: Area2D = $InteractionArea1  
@onready var interaction_area_2: Area2D = $InteractionArea2  
@onready var fade_layer: CanvasLayer = $FadeLayer  
@onready var save: Label = $Player/Camera2D/Save
@onready var locked: Label = $InteractionArea2/Locked
var save_timer: float = 0.0
var locked_timer: float = 0.0  
var current_tween: Tween = null

func _ready() -> void:
	# Connect interaction area 1 (floor transition)
	if not interaction_area_1.is_connected("interacted", Callable(self, "_on_interaction_area_1_interacted")):
		interaction_area_1.connect("interacted", Callable(self, "_on_interaction_area_1_interacted"))
	
	# Connect interaction area 2 (locked area)
	if not interaction_area_2.is_connected("interacted", Callable(self, "_on_interaction_area_2_interacted")):
		interaction_area_2.connect("interacted", Callable(self, "_on_interaction_area_2_interacted"))
	
	save.modulate.a = 0.0  # Start fully transparent
	save.visible = false
	locked.modulate.a = 0.0  # Start fully transparent
	locked.visible = false
	
	
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
	
	# Handle locked label timer
	if locked_timer > 0:
		locked_timer -= delta
		if locked_timer <= 0.5 and locked.modulate.a > 0:  # Fade out last 0.5 seconds
			if current_tween:
				current_tween.kill()
			current_tween = create_tween()
			current_tween.tween_property(locked, "modulate:a", 0.0, 0.5)
		elif locked_timer <= 0:
			locked.visible = false

func _save_player_on_scene_start() -> void:
	if not has_node("/root/SaveManager"):
		printerr("SaveManager autoload not found")
		return

	var ok := SaveManager.save_player()
	if not ok:
		printerr("Save failed: no active slot or other error.")
		return

	var current_slot := SaveManager.current_slot
	var path := ""
	if SaveManager.has_method("_get_slot_path"):
		path = SaveManager._get_slot_path(current_slot)
	else:
		path = "user://player_slot_%d.tres" % current_slot

	if path == "":
		printerr("Invalid path for current slot")
		return

	var save_res = load(path)
	if save_res and save_res is PlayerSaveData:
		save_res.save_name = " 0-1"
		var err = ResourceSaver.save(save_res, path)
		if err != OK:
			printerr("Failed to rewrite save with new name:", error_string(err))
		else:
			print("Save renamed to 0-1 at %s" % path)
	else:
		printerr("Save resource corrupted or missing")

	# Show save UI
	if current_tween:
		current_tween.kill()
	save.visible = true
	save_timer = 2.0
	current_tween = create_tween()
	current_tween.tween_property(save, "modulate:a", 1.0, 0.2).from(0.0)

func _on_interaction_area_1_interacted() -> void:
	fade_layer.start_fade("res://Assets/Levels/0-2/0_2.tscn")

func _on_interaction_area_2_interacted() -> void:
	if current_tween:
		current_tween.kill()
	
	locked.visible = true
	locked_timer = 1.0
	
	current_tween = create_tween()
	current_tween.tween_property(locked, "modulate:a", 1.0, 0.2).from(0.0)
