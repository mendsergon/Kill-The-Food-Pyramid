extends Control

func _on_test_area_pressed() -> void:
	call_deferred("_deferred_change_scene", "res://Assets/Scenes/game.tscn")


func _on_level_1_pressed() -> void:
	call_deferred("_deferred_change_scene", "res://Assets/Scenes/level_1.tscn")

func _deferred_change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
