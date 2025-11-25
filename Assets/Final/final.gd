extends Camera2D

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		get_tree().change_scene_to_file("res://Assets/Menus/Main Menu/main_menu.tscn")
