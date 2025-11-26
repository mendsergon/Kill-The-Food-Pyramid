extends Control
@onready var label: Label = $MarginContainer/VBoxContainer/Settings/Label

func _on_play_pressed() -> void:
	call_deferred("_deferred_change_scene", "res://Assets/Menus/Level Menu/level_menu.tscn")

func _on_settings_pressed() -> void:
	label.visible = true
	label.modulate.a = 0.0

	var t := get_tree().create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.5)   # fade in
	t.tween_property(label, "modulate:a", 0.0, 0.5)   # fade out

func _on_exit_pressed() -> void:
	get_tree().quit()

func _deferred_change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
