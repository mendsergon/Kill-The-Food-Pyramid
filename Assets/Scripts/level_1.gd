extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var interaction_area_3: Area2D = $InteractionArea3
@onready var interaction_area_1: Area2D = $InteractionArea1  
@onready var interaction_area_2: Area2D = $InteractionArea2  
@onready var fade_layer: CanvasLayer = $FadeLayer  
@onready var save: Label = $Player/Camera2D/Save
@onready var locked: Label = $InteractionArea2/Locked
var save_timer: float = 0.0
var locked_timer: float = 0.0  
var current_tween: Tween = null

func _ready() -> void:
	# Connect interaction area 3 (save point)
	if not interaction_area_3.is_connected("interacted", Callable(self, "_on_interaction_area_3_interacted")):
		interaction_area_3.connect("interacted", Callable(self, "_on_interaction_area_3_interacted"))
	
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

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		get_tree().reload_current_scene()
	
	# Handle save label timer
	if save_timer > 0:
		save_timer -= delta
		if save_timer <= 0.5 and save.modulate.a > 0:  # Start fading out last 0.5 seconds
			if current_tween:
				current_tween.kill()
			current_tween = create_tween()
			current_tween.tween_property(save, "modulate:a", 0.0, 0.5)
		elif save_timer <= 0:
			save.visible = false
	
	# Handle locked label timer
	if locked_timer > 0:
		locked_timer -= delta
		if locked_timer <= 0.5 and locked.modulate.a > 0:  # Start fading out last 0.5 seconds
			if current_tween:
				current_tween.kill()
			current_tween = create_tween()
			current_tween.tween_property(locked, "modulate:a", 0.0, 0.5)
		elif locked_timer <= 0:
			locked.visible = false

func _on_interaction_area_3_interacted() -> void:
	# Try to save to active slot. If none active, do NOT show success UI.
	var ok := SaveManager.save_player()
	if ok:
		print("Game saved from InteractionArea3")
		# Show save UI
		if current_tween:
			current_tween.kill()
		save.visible = true
		save_timer = 2.0
		current_tween = create_tween()
		current_tween.tween_property(save, "modulate:a", 1.0, 0.2).from(0.0)
	else:
		# Save failed — give clear feedback
		printerr("InteractionArea3: Save failed. No active slot set or other error.")
		# Optionally show a 'save failed' UI or a tooltip


func _on_interaction_area_1_interacted() -> void:
	fade_layer.start_fade("res://Assets/Scenes/floor_2.tscn")

func _on_interaction_area_2_interacted() -> void:
	# Show locked label
	if current_tween:
		current_tween.kill()
	
	locked.visible = true
	locked_timer = 1.0
	
	# Fade in quickly
	current_tween = create_tween()
	current_tween.tween_property(locked, "modulate:a", 1.0, 0.2).from(0.0)
