extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect

var fading := false
var fade_duration := 2.0
var fade_timer := 0.0
var target_scene := ""

func _ready() -> void:
	fade_rect.color.a = 0.0  # Start fully transparent

func start_fade(scene_path: String, duration: float = 2.0) -> void:
	fade_duration = duration
	fading = true
	fade_timer = 0.0
	target_scene = scene_path

func _process(delta: float) -> void:
	if fading:
		fade_timer += delta
		var alpha = clamp(fade_timer / fade_duration, 0, 1)
		fade_rect.color.a = alpha

		if alpha >= 1.0:
			if target_scene != "":
				get_tree().change_scene_to_file(target_scene)
			fading = false
