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
		save_res.save_name = " 0-2"
		var err = ResourceSaver.save(save_res, path)
		if err != OK:
			printerr("Failed to rewrite save with new name:", error_string(err))
		else:
			print("Save renamed to 0-2 at %s" % path)
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

func _input(event: InputEvent) -> void:
	# Only process input if in dialogue
	if dialogue_state > 0 and event.is_action_pressed("Interact"): 
		if dialogue_state == 1:  # Currently typing
			# Skip to end of current message
			if typewriter_tween:
				typewriter_tween.kill()
				typewriter_tween = null
			dialoge.text = messages[current_message]
			dialogue_state = 2
			cyber_cat_close_up.play("Idle")  # Change to idle animation
		elif dialogue_state == 2:  # Waiting for input to continue
			next_message()

# New function to start dialogue
func start_dialogue(dialogue_messages: Array, cat_animation: String = "Idle") -> void:
	if dialogue_state > 0:
		return  # Already in dialogue
	
	# Lock player movement
	if player.has_method("set_movement_enabled"):
		player_was_movable = player.movement_enabled
		player.set_movement_enabled(false)
	elif player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	messages = dialogue_messages
	current_message = 0
	dialoge_bar.visible = true
	cyber_cat_close_up.play(cat_animation)
	
	# Start with an empty message and wait a frame before showing text
	dialoge.text = ""
	dialogue_state = 1
	
	# Wait one frame before starting the typewriter effect
	await get_tree().process_frame
	show_message()

func show_message() -> void:
	if current_message >= messages.size():
		end_dialogue()
		return
	
	dialogue_state = 1
	
	# Typewriter effect
	typewriter_tween = create_tween()
	var message_length = messages[current_message].length()
	typewriter_tween.tween_method(Callable(self, "_add_letter"), 0, message_length, message_length * 0.05)
	typewriter_tween.finished.connect(Callable(self, "_on_message_finished"))

func _add_letter(letter_index: int) -> void:
	dialoge.text = messages[current_message].substr(0, letter_index)

func _on_message_finished() -> void:
	dialogue_state = 2
	cyber_cat_close_up.play("Idle")  # Switch to idle after typing

func next_message() -> void:
	current_message += 1
	if current_message < messages.size():
		cyber_cat_close_up.play("Idle")  # Switch animation for next message
		show_message()
	else:
		end_dialogue()

func end_dialogue() -> void:
	dialogue_state = 0
	dialoge_bar.visible = false
	cyber_cat_close_up.stop()  # Stop animation
	
	# Unlock player movement
	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(player_was_movable)
	elif player.has_method("set_physics_process"):
		player.set_physics_process(true)

func _on_interaction_area_4_interacted() -> void:
	start_dialogue([
		"Hello...",
		"Exploring  the  food  pyramid  \ntoo?"
	], "Idle")
