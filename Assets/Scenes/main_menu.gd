extends Control

func _on_play_pressed() -> void:
	call_deferred("_deferred_change_scene", "res://Assets/Scenes/level_menu.tscn")

func _on_settings_pressed() -> void:
	pass 

func _on_exit_pressed() -> void:
	get_tree().quit()

func _deferred_change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
