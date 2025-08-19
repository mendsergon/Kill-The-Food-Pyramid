extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var interaction_area_1: Area2D = $InteractionArea1  
@onready var interaction_area_2: Area2D = $InteractionArea2
@onready var interaction_area_3: Area2D = $InteractionArea3
@onready var fade_layer: CanvasLayer = $FadeLayer  
@onready var save: Label = $Player/Camera2D/Save
var save_timer: float = 0.0
var current_tween: Tween = null

func _ready() -> void:
	# Connect interaction area 1 (floor transition)
	if not interaction_area_1.is_connected("interacted", Callable(self, "_on_interaction_area_1_interacted")):
		interaction_area_1.connect("interacted", Callable(self, "_on_interaction_area_1_interacted"))
	
	# Connect interaction area 2 (teleport to 3)
	if not interaction_area_2.is_connected("interacted", Callable(self, "_on_interaction_area_2_interacted")):
		interaction_area_2.connect("interacted", Callable(self, "_on_interaction_area_2_interacted"))

	# Connect interaction area 3 (teleport to 2)
	if not interaction_area_3.is_connected("interacted", Callable(self, "_on_interaction_area_3_interacted")):
		interaction_area_3.connect("interacted", Callable(self, "_on_interaction_area_3_interacted"))
	
	save.modulate.a = 0.0  # Start fully transparent
	save.visible = false

	# --- Save immediately on scene start ---
	_save_player_on_scene_start()

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
		save_res.save_name = " 1-2"
		var err = ResourceSaver.save(save_res, path)
		if err != OK:
			printerr("Failed to rewrite save with new name:", error_string(err))
		else:
			print("Save renamed to 1-3 at %s" % path)
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
	fade_layer.start_fade("res://Assets/Scenes/floor_2.tscn")

# --- Teleportation handlers with temporary disable ---
func _on_interaction_area_2_interacted() -> void:
	if is_instance_valid(player) and is_instance_valid(interaction_area_3):
		player.global_position = interaction_area_3.global_position
		# disable 3 for 2 seconds
		interaction_area_3.set_deferred("monitoring", false)
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(interaction_area_3):
			interaction_area_3.monitoring = true

func _on_interaction_area_3_interacted() -> void:
	if is_instance_valid(player) and is_instance_valid(interaction_area_2):
		player.global_position = interaction_area_2.global_position
		# disable 2 for 2 seconds
		interaction_area_2.set_deferred("monitoring", false)
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(interaction_area_2):
			interaction_area_2.monitoring = true
