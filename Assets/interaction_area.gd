extends Area2D

@export var action_name: String = "interact"  # Text describing the interaction action

@onready var player = get_tree().get_first_node_in_group("player")  # Reference to player node by group
@onready var label = $Label  # Label node to show the interaction prompt

var player_inside: bool = false  # Tracks if player is inside interaction area
var can_interact: bool = true  # Controls if interaction is currently allowed
var has_interacted: bool = false  # Tracks if interaction happened this enter


func _ready() -> void:
	label.visible = false  # Hide label initially
	# Connect signals for body entering and exiting the area
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		has_interacted = false  # Reset interaction flag on new enter
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
	label.position = Vector2(-30, -30)
	label.position = Vector2(-30, -50)


func _input(event: InputEvent) -> void:
	if player_inside and can_interact and not has_interacted and event.is_action_pressed("Interact"):
		can_interact = false
		label.visible = false
		@warning_ignore("redundant_await")
		await interact()
		can_interact = true
		has_interacted = true  # Mark interaction done so it won't repeat


func interact() -> void:
	print("Interacted with ", action_name)
