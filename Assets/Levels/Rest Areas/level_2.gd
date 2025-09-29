extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var interaction_area_1: Area2D = $InteractionArea1  
@onready var interaction_area_2: Area2D = $InteractionArea2
@onready var interaction_area_3: Area2D = $InteractionArea3
@onready var fade_layer: CanvasLayer = $FadeLayer  
@onready var save: Label = $Player/Camera2D/Save
@onready var cyber_cat: CharacterBody2D = $"Cyber Cat"
@onready var dialoge_bar: Sprite2D = $"Player/Camera2D/Dialoge Bar"
@onready var cyber_cat_close_up: AnimatedSprite2D = $"Player/Camera2D/Dialoge Bar/CyberCatCloseUp"
@onready var dialoge: Label = $"Player/Camera2D/Dialoge Bar/Dialoge"
@onready var interaction_area_4: Area2D = $"Cyber Cat/InteractionArea4"

var save_timer: float = 0.0
var current_tween: Tween = null
var dialogue_state: int = 0  # 0 = not in dialogue, 1 = typing, 2 = waiting for input
var current_message: int = 0
var messages: Array = []
var typewriter_tween: Tween
var player_was_movable: bool = true  # Track player's movement state before dialogue
var dialogue_source: String = ""  # Tracks which NPC/dialogue started

func _ready() -> void:
	# --- give Cyber Cat the player reference ---
	if cyber_cat.has_method("set_player_reference"):
		cyber_cat.set_player_reference(player)

	# Connect interaction area 1 (floor transition)
	if not interaction_area_1.is_connected("interacted", Callable(self, "_on_interaction_area_1_interacted")):
		interaction_area_1.connect("interacted", Callable(self, "_on_interaction_area_1_interacted"))
	
	# Connect interaction area 2 (teleport to 3)
	if not interaction_area_2.is_connected("interacted", Callable(self, "_on_interaction_area_2_interacted")):
		interaction_area_2.connect("interacted", Callable(self, "_on_interaction_area_2_interacted"))

	# Connect interaction area 3 (teleport to 2)
	if not interaction_area_3.is_connected("interacted", Callable(self, "_on_interaction_area_3_interacted")):
		interaction_area_3.connect("interacted", Callable(self, "_on_interaction_area_3_interacted"))
	
	# Connect interaction area 4
	if not interaction_area_4.is_connected("interacted", Callable(self, "_on_interaction_area_4_interacted")):
		interaction_area_4.connect("interacted", Callable(self, "_on_interaction_area_4_interacted"))
	
	# Hide dialogue bar at start
	dialoge_bar.visible = false
	
	save.modulate.a = 0.0  # Start fully transparent
	save.visible = false
	
	# Check if player already has full health and disable area 4 if true
	if is_instance_valid(player) and player.health >= 4:
		if is_instance_valid(interaction_area_4):
			interaction_area_4.queue_free()
	
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
	
func _save_player_on_scene_start() -> void:
	if not has_node("/root/SaveManager"):
		printerr("SaveManager autoload not found")
		return

	var ok := SaveManager.save_player()
	if not ok:
		printerr("Save failed: no active slot or other error.")
		return

	_rename_save_to_0_2()

	# Show save UI
	if current_tween:
		current_tween.kill()
	save.visible = true
	save_timer = 2.0
	current_tween = create_tween()
	current_tween.tween_property(save, "modulate:a", 1.0, 0.2).from(0.0)

# Function to rename the save file to " 0-2"
func _rename_save_to_0_2() -> void:
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
		save_res.save_name = " 0-2"
		var err = ResourceSaver.save(save_res, path)
		if err != OK:
			printerr("Failed to rewrite save with new name:", error_string(err))
		else:
			print("Save renamed to 0-2 at %s" % path)
	else:
		printerr("Save resource corrupted or missing")

func _on_interaction_area_1_interacted() -> void:
	fade_layer.start_fade("res://Assets/Levels/0-3/0_3.tscn")

func _on_interaction_area_2_interacted() -> void:
	if is_instance_valid(player) and is_instance_valid(interaction_area_3):
		player.global_position = interaction_area_3.global_position
		interaction_area_3.set_deferred("monitoring", false)
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(interaction_area_3):
			interaction_area_3.monitoring = true

func _on_interaction_area_3_interacted() -> void:
	if is_instance_valid(player) and is_instance_valid(interaction_area_2):
		player.global_position = interaction_area_2.global_position
		interaction_area_2.set_deferred("monitoring", false)
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(interaction_area_2):
			interaction_area_2.monitoring = true

func _input(event: InputEvent) -> void:
	if dialogue_state > 0 and event.is_action_pressed("Interact"): 
		if dialogue_state == 1:
			if typewriter_tween:
				typewriter_tween.kill()
				typewriter_tween = null
			dialoge.text = messages[current_message]
			dialogue_state = 2
			cyber_cat_close_up.play("Idle")
		elif dialogue_state == 2:
			next_message()

func start_dialogue(dialogue_messages: Array, cat_animation: String = "Idle") -> void:
	if dialogue_state > 0:
		return
	if player.has_method("set_movement_enabled"):
		player_was_movable = player.movement_enabled
		player.set_movement_enabled(false)
	elif player.has_method("set_physics_process"):
		player.set_physics_process(false)
	messages = dialogue_messages
	current_message = 0
	dialoge_bar.visible = true
	cyber_cat_close_up.play(cat_animation)
	dialoge.text = ""
	dialogue_state = 1
	await get_tree().process_frame
	show_message()

func show_message() -> void:
	if current_message >= messages.size():
		end_dialogue()
		return
	dialogue_state = 1
	typewriter_tween = create_tween()
	var message_length = messages[current_message].length()
	typewriter_tween.tween_method(Callable(self, "_add_letter"), 0, message_length, message_length * 0.05)
	typewriter_tween.finished.connect(Callable(self, "_on_message_finished"))

func _add_letter(letter_index: int) -> void:
	dialoge.text = messages[current_message].substr(0, letter_index)

func _on_message_finished() -> void:
	dialogue_state = 2
	cyber_cat_close_up.play("Idle")

func next_message() -> void:
	current_message += 1
	if current_message < messages.size():
		cyber_cat_close_up.play("Idle")
		show_message()
	else:
		end_dialogue()

func end_dialogue() -> void:
	dialogue_state = 0
	dialoge_bar.visible = false
	cyber_cat_close_up.stop()
	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(player_was_movable)
	elif player.has_method("set_physics_process"):
		player.set_physics_process(true)

	if dialogue_source == "cyber_cat" and is_instance_valid(player):
		player.max_health = 4
		player.health = 4
		if player.has_method("update_health_bar"):
			player.update_health_bar()
		if SaveManager and SaveManager.current_slot != -1:
			var ok := SaveManager.save_player()
			if not ok:
				printerr("Failed to save after Cyber Cat reward!")
			else:
				# Rename the save to " 0-2" after the dialogue
				_rename_save_to_0_2()
		if is_instance_valid(interaction_area_4):
			interaction_area_4.queue_free()
	
	# Check if area 4 should be disabled after dialogue ends
	_check_and_disable_area_4()

	dialogue_source = ""

# Check if player has full health and disable area 4 if true
func _check_and_disable_area_4() -> void:
	if is_instance_valid(player) and player.health >= 4:
		if is_instance_valid(interaction_area_4):
			interaction_area_4.queue_free()

func _on_interaction_area_4_interacted() -> void:
	dialogue_source = "cyber_cat"
	
	# Check player health to determine which dialogue to play
	if is_instance_valid(player) and player.health >= 4:
		# Player already has full health - play simple greeting
		start_dialogue([
			"Had  a  good  nap???"
		], "Idle")
	else:
		# Player doesn't have full health - play original dialogue
		start_dialogue([
			"Hello...",
			"Exploring  the  food  pyramid  \ntoo?",
			"Or  are  you  simply  an ..........\nexterminator????",
			"Well ... doesn't  really  matter  \n.........",
			"I  myself  am  looking  for  \nsomething....",
			"A  GREEN  SHARD,  held  \nby  the  FOOD  LORDS!!!",
			"It  is  of  outmost  importance  \nthat  I  get  that  SHARD",
			"Will  you  help  me ????????",
			"You  will  be  rewarded ...",
			"NICE !!!",
			"Take  this  blessing  and  start \n.............",
			"KILLING !!!!!!!!"
		], "Idle")
