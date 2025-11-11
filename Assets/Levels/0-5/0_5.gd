extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var dialoge_bar: Sprite2D = $"Player/Camera2D/Dialoge Bar"
@onready var dialoge: Label = $"Player/Camera2D/Dialoge Bar/Dialoge"
@onready var interaction_area: Area2D = $InteractionArea
@onready var king_bread_c_lose: AnimatedSprite2D = $"Player/Camera2D/Dialoge Bar/KingBreadCLose"

var dialogue_state: int = 0  # 0 = not in dialogue, 1 = typing, 2 = waiting for input
var current_message: int = 0
var messages: Array = []
var typewriter_tween: Tween
var player_was_movable: bool = true  # Track player's movement state before dialogue

func _ready() -> void:
	# Connect interaction area
	if not interaction_area.is_connected("interacted", Callable(self, "_on_interaction_area_interacted")):
		interaction_area.connect("interacted", Callable(self, "_on_interaction_area_interacted"))
	
	# Hide dialogue bar at start
	dialoge_bar.visible = false

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
