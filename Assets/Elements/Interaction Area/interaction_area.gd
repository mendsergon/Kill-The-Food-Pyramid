extends Area2D

signal interacted  # Signal to tell other scripts when the player interacts

@export var action_name: String = "interact"  # Text describing the interaction action
@onready var player = get_tree().get_first_node_in_group("player")
@onready var label = $Label

var player_inside: bool = false
var can_interact: bool = true
var has_interacted: bool = false


func _ready() -> void:
	label.visible = false
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		has_interacted = false
		label.visible = true
		update_label_position()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		label.visible = false


func _process(_delta: float) -> void:
	if player_inside:
		update_label_position()


func update_label_position() -> void:
	label.position = Vector2(-30, -40)


func _input(event: InputEvent) -> void:
	if player_inside and can_interact and not has_interacted and event.is_action_pressed("Interact"):
		can_interact = false
		label.visible = false
		emit_signal("interacted")  # Tell other scripts interaction happened
		can_interact = true
		has_interacted = true
