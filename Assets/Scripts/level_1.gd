extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var interaction_area: Area2D = $InteractionArea
@onready var fade_layer: CanvasLayer = $FadeLayer  

func _ready() -> void:
	interaction_area.connect("interacted", Callable(self, "_on_interaction_area_3_interacted"))

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		get_tree().reload_current_scene()

func _on_interaction_area_3_interacted() -> void:
	SaveManager.save_player()
	print("Game saved from interaction")
