extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var dialoge_bar: Sprite2D = $"Player/Camera2D/Dialoge Bar"
@onready var dialoge: Label = $"Player/Camera2D/Dialoge Bar/Dialoge"
@onready var interaction_area: Area2D = $InteractionArea
@onready var king_bread_c_lose: AnimatedSprite2D = $"Player/Camera2D/Dialoge Bar/KingBreadCLose"
@onready var flash_layer: CanvasLayer = $FlashLayer 
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var camera_2d_2: Camera2D = $Player/Camera2D2
@onready var spawn_area: Area2D = $SpawnArea
@onready var label: Label = $Player/Camera2D2/Label
@onready var pin: Node2D = $Pin
@onready var king_bread: CharacterBody2D = $"King Bread"

@onready var enemywave_1: Node2D = $Enemywave1
@onready var bread_1: CharacterBody2D = $Enemywave1/Bread1
@onready var bread_2: CharacterBody2D = $Enemywave1/Bread2
@onready var bread_3: CharacterBody2D = $Enemywave1/Bread3
@onready var bread_4: CharacterBody2D = $Enemywave1/Bread4
@onready var bread_5: CharacterBody2D = $Enemywave1/Bread5
@onready var bread_6: CharacterBody2D = $Enemywave1/Bread6
@onready var bread_7: CharacterBody2D = $Enemywave1/Bread7
@onready var bread_8: CharacterBody2D = $Enemywave1/Bread8
@onready var bread_9: CharacterBody2D = $Enemywave1/Bread9
@onready var bread_10: CharacterBody2D = $Enemywave1/Bread10

@onready var enemywave_2: Node2D = $Enemywave2
@onready var baguette_1: CharacterBody2D = $Enemywave2/Baguette1
@onready var baguette_2: CharacterBody2D = $Enemywave2/Baguette2
@onready var baguette_3: CharacterBody2D = $Enemywave2/Baguette3
@onready var baguette_4: CharacterBody2D = $Enemywave2/Baguette4
@onready var baguette_5: CharacterBody2D = $Enemywave2/Baguette5
@onready var baguette_6: CharacterBody2D = $Enemywave2/Baguette6

@onready var enemywave_3: Node2D = $Enemywave3
@onready var big_bread: CharacterBody2D = $"Enemywave3/Big Bread"
@onready var big_black_bread: CharacterBody2D = $"Enemywave3/Big Black Bread"

var dialogue_state: int = 0  # 0 = not in dialogue, 1 = typing, 2 = waiting for input
var current_message: int = 0
var messages: Array = []
var typewriter_tween: Tween
var player_was_movable: bool = true  # Track player's movement state before dialogue
var king_health_threshold_75_reached: bool = false
var king_health_threshold_50_reached: bool = false
var king_health_threshold_25_reached: bool = false
var enemy_wave_1_active: bool = false
var enemy_wave_2_active: bool = false
var enemy_wave_3_active: bool = false
var king_initial_health: int = 0

func _ready() -> void:
	# Connect interaction area
	if not interaction_area.is_connected("interacted", Callable(self, "_on_interaction_area_interacted")):
		interaction_area.connect("interacted", Callable(self, "_on_interaction_area_interacted"))
	
	# Hide dialogue bar and label at start
	dialoge_bar.visible = false
	label.visible = false
	
	# Completely disable King Bread at start
	if king_bread:
		king_bread.process_mode = Node.PROCESS_MODE_DISABLED
		king_bread.visible = false
	
	# Completely disable Enemy Wave 1 at start
	if enemywave_1:
		enemywave_1.process_mode = Node.PROCESS_MODE_DISABLED
		enemywave_1.visible = false
	
	# Completely disable Enemy Wave 2 at start
	if enemywave_2:
		enemywave_2.process_mode = Node.PROCESS_MODE_DISABLED
		enemywave_2.visible = false
	
	# Completely disable Enemy Wave 3 at start
	if enemywave_3:
		enemywave_3.process_mode = Node.PROCESS_MODE_DISABLED
		enemywave_3.visible = false
	
	_load_player_stats()

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


func _process(_delta: float) -> void:
	# Check King Bread's health if he's active and we haven't triggered the thresholds yet
	if king_bread and king_bread.process_mode != Node.PROCESS_MODE_DISABLED:
		if not king_health_threshold_75_reached or not king_health_threshold_50_reached or not king_health_threshold_25_reached:
			check_king_health()

func check_king_health() -> void:
	# Access King Bread's health directly from the script
	var health_percentage = 100.0
	
	if king_bread.has_method("get_health_percentage"):
		health_percentage = king_bread.get_health_percentage()
	elif king_bread.has_method("get_health") and king_bread.has_method("get_max_health"):
		var current_health = king_bread.get_health()
		var max_health = king_bread.get_max_health()
		health_percentage = (float(current_health) / float(max_health)) * 100
	elif king_bread.get("health") and king_bread.get("max_health"):
		var current_health = king_bread.health
		var max_health = king_bread.max_health
		health_percentage = (float(current_health) / float(max_health)) * 100
	
	# Check for 75% threshold
	if health_percentage <= 75 and not king_health_threshold_75_reached:
		king_health_threshold_75_reached = true
		trigger_king_to_wave_1_transition()
	# Check for 50% threshold
	elif health_percentage <= 50 and not king_health_threshold_50_reached:
		king_health_threshold_50_reached = true
		trigger_king_to_wave_2_transition()
	# Check for 25% threshold
	elif health_percentage <= 25 and not king_health_threshold_25_reached:
		king_health_threshold_25_reached = true
		trigger_king_to_wave_3_transition()

func trigger_king_to_wave_1_transition() -> void:
	# Store King's current health for later restoration
	if king_bread:
		if king_bread.has_method("get_health"):
			king_initial_health = king_bread.get_health()
		elif king_bread.get("health"):
			king_initial_health = king_bread.health
	
	# Disable King Bread
	if king_bread:
		king_bread.process_mode = Node.PROCESS_MODE_DISABLED
		king_bread.visible = false
	
	# Teleport player to pin
	_teleport_player_to_pin()
	
	# Trigger flash effect
	if flash_layer and flash_layer.has_method("trigger_flash"):
		flash_layer.trigger_flash()
	
	# Enable enemy wave 1
	if enemywave_1:
		enemywave_1.process_mode = Node.PROCESS_MODE_INHERIT
		enemywave_1.visible = true
		enemy_wave_1_active = true
		
		# Pass player position to all bread enemies
		set_bread_targets_to_player()
		
		# Start checking if wave 1 is cleared
		start_wave_1_clear_check()

func trigger_king_to_wave_2_transition() -> void:
	# Store King's current health for later restoration
	if king_bread:
		if king_bread.has_method("get_health"):
			king_initial_health = king_bread.get_health()
		elif king_bread.get("health"):
			king_initial_health = king_bread.health
	
	# Disable King Bread
	if king_bread:
		king_bread.process_mode = Node.PROCESS_MODE_DISABLED
		king_bread.visible = false
	
	# Teleport player to pin
	_teleport_player_to_pin()
	
	# Trigger flash effect
	if flash_layer and flash_layer.has_method("trigger_flash"):
		flash_layer.trigger_flash()
	
	# Enable enemy wave 2
	if enemywave_2:
		enemywave_2.process_mode = Node.PROCESS_MODE_INHERIT
		enemywave_2.visible = true
		enemy_wave_2_active = true
		
		# Pass player position to all baguette enemies
		set_baguette_targets_to_player()
		
		# Start checking if wave 2 is cleared
		start_wave_2_clear_check()

func trigger_king_to_wave_3_transition() -> void:
	# Store King's current health for later restoration
	if king_bread:
		if king_bread.has_method("get_health"):
			king_initial_health = king_bread.get_health()
		elif king_bread.get("health"):
			king_initial_health = king_bread.health
	
	# Disable King Bread
	if king_bread:
		king_bread.process_mode = Node.PROCESS_MODE_DISABLED
		king_bread.visible = false
	
	# Teleport player to pin
	_teleport_player_to_pin()
	
	# Trigger flash effect
	if flash_layer and flash_layer.has_method("trigger_flash"):
		flash_layer.trigger_flash()
	
	# Enable enemy wave 3
	if enemywave_3:
		enemywave_3.process_mode = Node.PROCESS_MODE_INHERIT
		enemywave_3.visible = true
		enemy_wave_3_active = true
		
		# Pass player position to all big bread enemies
		set_big_bread_targets_to_player()
		
		# Start checking if wave 3 is cleared
		start_wave_3_clear_check()

func set_bread_targets_to_player() -> void:
	var bread_enemies = [
		bread_1, bread_2, bread_3, bread_4, bread_5,
		bread_6, bread_7, bread_8, bread_9, bread_10
	]
	
	for bread in bread_enemies:
		if bread and bread.has_method("set_player_reference"):
			bread.set_player_reference(player)

func set_baguette_targets_to_player() -> void:
	var baguette_enemies = [
		baguette_1, baguette_2, baguette_3, baguette_4, baguette_5, baguette_6
	]
	
	for baguette in baguette_enemies:
		if baguette and baguette.has_method("set_player_reference"):
			baguette.set_player_reference(player)

func set_big_bread_targets_to_player() -> void:
	var big_bread_enemies = [
		big_bread, big_black_bread
	]
	
	for big_bread_enemy in big_bread_enemies:
		if big_bread_enemy and big_bread_enemy.has_method("set_player_reference"):
			big_bread_enemy.set_player_reference(player)

func start_wave_1_clear_check() -> void:
	# Start a timer to periodically check if wave 1 is cleared
	var timer = Timer.new()
	timer.wait_time = 0.5  # Check every half second
	timer.timeout.connect(_check_wave_1_clear)
	add_child(timer)
	timer.start()

func start_wave_2_clear_check() -> void:
	# Start a timer to periodically check if wave 2 is cleared
	var timer = Timer.new()
	timer.wait_time = 0.5  # Check every half second
	timer.timeout.connect(_check_wave_2_clear)
	add_child(timer)
	timer.start()

func start_wave_3_clear_check() -> void:
	# Start a timer to periodically check if wave 3 is cleared
	var timer = Timer.new()
	timer.wait_time = 0.5  # Check every half second
	timer.timeout.connect(_check_wave_3_clear)
	add_child(timer)
	timer.start()

func _check_wave_1_clear() -> void:
	if not enemy_wave_1_active:
		return
	
	var alive_enemies = 0
	var bread_enemies = [
		bread_1, bread_2, bread_3, bread_4, bread_5,
		bread_6, bread_7, bread_8, bread_9, bread_10
	]
	
	for bread in bread_enemies:
		if bread and is_instance_valid(bread) and bread.process_mode != Node.PROCESS_MODE_DISABLED:
			# Check if the bread is alive (has health and not dying)
			if bread.has_method("is_dying"):
				if not bread.is_dying:
					alive_enemies += 1
			elif bread.has_method("get_health"):
				if bread.get_health() > 0:
					alive_enemies += 1
			elif bread.get("health"):
				if bread.health > 0:
					alive_enemies += 1
			else:
				# If we can't check health, assume it's alive if process mode is enabled
				alive_enemies += 1
	
	# If all enemies are defeated, trigger the transition back to King Bread
	if alive_enemies == 0:
		enemy_wave_1_active = false
		# Stop the timer
		for child in get_children():
			if child is Timer and child.timeout.is_connected(_check_wave_1_clear):
				child.stop()
				child.queue_free()
		trigger_wave_1_to_king_transition()

func _check_wave_2_clear() -> void:
	if not enemy_wave_2_active:
		return
	
	var alive_enemies = 0
	var baguette_enemies = [
		baguette_1, baguette_2, baguette_3, baguette_4, baguette_5, baguette_6
	]
	
	for baguette in baguette_enemies:
		if baguette and is_instance_valid(baguette) and baguette.process_mode != Node.PROCESS_MODE_DISABLED:
			# Check if the baguette is alive (has health and not dying)
			if baguette.has_method("is_dying"):
				if not baguette.is_dying:
					alive_enemies += 1
			elif baguette.has_method("get_health"):
				if baguette.get_health() > 0:
					alive_enemies += 1
			elif baguette.get("health"):
				if baguette.health > 0:
					alive_enemies += 1
			else:
				# If we can't check health, assume it's alive if process mode is enabled
				alive_enemies += 1
	
	# If all enemies are defeated, trigger the transition back to King Bread
	if alive_enemies == 0:
		enemy_wave_2_active = false
		# Stop the timer
		for child in get_children():
			if child is Timer and child.timeout.is_connected(_check_wave_2_clear):
				child.stop()
				child.queue_free()
		trigger_wave_2_to_king_transition()

func _check_wave_3_clear() -> void:
	if not enemy_wave_3_active:
		return
	
	var alive_enemies = 0
	var big_bread_enemies = [
		big_bread, big_black_bread
	]
	
	for big_bread_enemy in big_bread_enemies:
		if big_bread_enemy and is_instance_valid(big_bread_enemy) and big_bread_enemy.process_mode != Node.PROCESS_MODE_DISABLED:
			# Check if the big bread is alive (has health and not dying)
			if big_bread_enemy.has_method("is_dying"):
				if not big_bread_enemy.is_dying:
					alive_enemies += 1
			elif big_bread_enemy.has_method("get_health"):
				if big_bread_enemy.get_health() > 0:
					alive_enemies += 1
			elif big_bread_enemy.get("health"):
				if big_bread_enemy.health > 0:
					alive_enemies += 1
			else:
				# If we can't check health, assume it's alive if process mode is enabled
				alive_enemies += 1
	
	# If all enemies are defeated, trigger the transition back to King Bread
	if alive_enemies == 0:
		enemy_wave_3_active = false
		# Stop the timer
		for child in get_children():
			if child is Timer and child.timeout.is_connected(_check_wave_3_clear):
				child.stop()
				child.queue_free()
		trigger_wave_3_to_king_transition()

func trigger_wave_1_to_king_transition() -> void:
	# Disable enemy wave 1
	if enemywave_1:
		enemywave_1.process_mode = Node.PROCESS_MODE_DISABLED
		enemywave_1.visible = false
	
	# Teleport player to pin
	_teleport_player_to_pin()
	
	# Trigger flash effect
	if flash_layer and flash_layer.has_method("trigger_flash"):
		flash_layer.trigger_flash()
	
	# Re-enable King Bread with 75% health
	if king_bread:
		king_bread.process_mode = Node.PROCESS_MODE_INHERIT
		king_bread.visible = true
		
		# Set King Bread's health to 75% of max health
		if king_bread.has_method("set_health_percentage"):
			king_bread.set_health_percentage(75)
		elif king_bread.has_method("set_health"):
			var max_health = king_bread.max_health
			var new_health = max_health * 0.75
			king_bread.set_health(int(new_health))
		elif king_bread.get("max_health"):
			var max_health = king_bread.max_health
			king_bread.health = int(max_health * 0.75)

func trigger_wave_2_to_king_transition() -> void:
	# Disable enemy wave 2
	if enemywave_2:
		enemywave_2.process_mode = Node.PROCESS_MODE_DISABLED
		enemywave_2.visible = false
	
	# Teleport player to pin
	_teleport_player_to_pin()
	
	# Trigger flash effect
	if flash_layer and flash_layer.has_method("trigger_flash"):
		flash_layer.trigger_flash()
	
	# Re-enable King Bread with 50% health
	if king_bread:
		king_bread.process_mode = Node.PROCESS_MODE_INHERIT
		king_bread.visible = true
		
		# Set King Bread's health to 50% of max health
		if king_bread.has_method("set_health_percentage"):
			king_bread.set_health_percentage(50)
		elif king_bread.has_method("set_health"):
			var max_health = king_bread.max_health
			var new_health = max_health * 0.50
			king_bread.set_health(int(new_health))
		elif king_bread.get("max_health"):
			var max_health = king_bread.max_health
			king_bread.health = int(max_health * 0.50)

func trigger_wave_3_to_king_transition() -> void:
	# Disable enemy wave 3
	if enemywave_3:
		enemywave_3.process_mode = Node.PROCESS_MODE_DISABLED
		enemywave_3.visible = false
	
	# Teleport player to pin
	_teleport_player_to_pin()
	
	# Trigger flash effect
	if flash_layer and flash_layer.has_method("trigger_flash"):
		flash_layer.trigger_flash()
	
	# Re-enable King Bread with 25% health
	if king_bread:
		king_bread.process_mode = Node.PROCESS_MODE_INHERIT
		king_bread.visible = true
		
		# Set King Bread's health to 25% of max health
		if king_bread.has_method("set_health_percentage"):
			king_bread.set_health_percentage(25)
		elif king_bread.has_method("set_health"):
			var max_health = king_bread.max_health
			var new_health = max_health * 0.25
			king_bread.set_health(int(new_health))
		elif king_bread.get("max_health"):
			var max_health = king_bread.max_health
			king_bread.health = int(max_health * 0.25)

func _input(event: InputEvent) -> void:
	if dialogue_state > 0 and event.is_action_pressed("Interact"): 
		if dialogue_state == 1:
			# Skip typewriter effect
			if typewriter_tween:
				typewriter_tween.kill()
				typewriter_tween = null
			dialoge.text = messages[current_message]
			dialogue_state = 2
			king_bread_c_lose.play("Idle")
		elif dialogue_state == 2:
			# Go to next message
			next_message()

func _on_interaction_area_interacted() -> void:
	# Start dialogue with KingBread
	start_dialogue([
		"HALT,  intruder!",
		"You  stand  before  King  Bread!",
		"The  Proud...",
		"Ruler  of  crumb...",
		"Master  of  starch...",
		"Chosen  wielder  of...",
		"The  GREEN  SHARD!",
		"You  have  wiped  out  my  bread\n...",
		"crushed  my  pasta...",
		"mashed  my  potatoes!",
		"My  kingdom  reduced  to\ncrumbs  and  noodles!",
		"FOOL!",
		"Now...",
		"Prepare  your  self  invader!",
		"For  today,  I  king  bread...",
		"shall butter  your  destiny...",
		"toast  your  dreams...",
		"and  spread  your  defeat...",
		"thicker  than  grandma's\nSunday  margarine!!!"
	], "Idle")

func start_dialogue(dialogue_messages: Array, Idle: String = "Idle") -> void:
	if dialogue_state > 0:
		return
	
	# Disable player movement
	if player.has_method("set_movement_enabled"):
		player_was_movable = player.movement_enabled
		player.set_movement_enabled(false)
	elif player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	# Set up dialogue
	messages = dialogue_messages
	current_message = 0
	dialoge_bar.visible = true
	king_bread_c_lose.play(Idle)
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
	king_bread_c_lose.play("Idle")

func next_message() -> void:
	current_message += 1
	if current_message < messages.size():
		king_bread_c_lose.play("Idle")
		show_message()
	else:
		end_dialogue()

func end_dialogue() -> void:
	dialogue_state = 0
	dialoge_bar.visible = false
	king_bread_c_lose.stop()
	
	# Re-enable player movement
	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(player_was_movable)
	elif player.has_method("set_physics_process"):
		player.set_physics_process(true)
	
	# Kill the interaction area after dialogue
	if is_instance_valid(interaction_area):
		interaction_area.queue_free()
	
	# Trigger flash effect and camera switch
	trigger_flash_and_switch_camera()

func trigger_flash_and_switch_camera() -> void:
	# Teleport the player immediately (before the flash)
	_teleport_player_to_pin()
	
	# Switch cameras
	camera_2d.enabled = false
	camera_2d_2.enabled = true
	
	# Enable King Bread now
	if king_bread:
		king_bread.process_mode = Node.PROCESS_MODE_INHERIT
		king_bread.visible = true
		king_bread.set_player_reference(player)
	
	# Trigger the flash effect
	if flash_layer and flash_layer.has_method("trigger_flash"):
		flash_layer.trigger_flash()
		
		# Wait for flash to complete then show King Bread text
		await get_tree().create_timer(2.0).timeout  # Wait for flash duration
		show_king_bread_text()

func _teleport_player_to_pin() -> void:
	# Teleport the player to the pin position
	if player and pin:
		player.global_position = pin.global_position
		print("Player teleported to pin position")
	else:
		print("Error: Player or pin not found for teleportation")

func show_king_bread_text() -> void:
	# Show the label and set up the text
	label.visible = true
	label.text = ""
	label.modulate = Color(1, 1, 1, 1)  # Ensure it's fully visible
	
	# Text to display with two spaces between words
	var king_text = "KING  BREAD"
	
	# Create typewriter effect for the text
	var tween = create_tween()
	var text_length = king_text.length()
	
	# Typewriter effect
	tween.tween_method(Callable(self, "_update_king_text").bind(king_text), 0, text_length, text_length * 0.1)
	
	# After typewriter completes, wait a moment then fade out
	tween.tween_callback(Callable(self, "_start_fade_out"))
	
func _update_king_text(letter_index: int, full_text: String) -> void:
	label.text = full_text.substr(0, letter_index)

func _start_fade_out() -> void:
	# Wait a moment before starting the fade out
	await get_tree().create_timer(1.0).timeout
	
	# Create fade out tween
	var fade_tween = create_tween()
	fade_tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 2.0)
	fade_tween.tween_callback(Callable(self, "_on_text_fade_complete"))

func _on_text_fade_complete() -> void:
	# Hide the label after fade out
	label.visible = false
