extends Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false  # Start hidden

func resume():
	get_tree().paused = false
	visible = false  # Hide menu

func pause():
	get_tree().paused = true
	visible = true   # Show menu immediately
	# No animation - just show it

func ESC():
	if Input.is_action_just_pressed("PAUSE") and get_tree().paused == false:
		pause()
	elif Input.is_action_just_pressed("PAUSE") and get_tree().paused:
		resume()

func _on_resume_pressed() -> void:
	resume()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Assets/Menus/Main Menu/main_menu.tscn")

func _process(_delta):
	ESC()
