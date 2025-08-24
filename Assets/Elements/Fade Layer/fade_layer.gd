extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect

var fading := false
var fade_duration := 2.0
var fade_timer := 0.0
var target_scene := ""
var fade_in := false  

func _ready() -> void:
	fade_rect.color.a = 0.0  # Start fully transparent

func start_fade(scene_path: String, duration: float = 2.0) -> void:
	fade_duration = duration
	fading = true
	fade_timer = 0.0
	target_scene = scene_path
	fade_in = false

func _process(delta: float) -> void:
	if fading:
		fade_timer += delta
		var alpha = clamp(fade_timer / fade_duration, 0, 1)

		if fade_in:
			alpha = 1.0 - alpha  # Fade in
		fade_rect.color.a = alpha

		if fade_timer >= fade_duration:
			fading = false
			if not fade_in and target_scene != "":
				# Safely change scene deferred
				call_deferred("_change_scene_deferred", target_scene)
			elif fade_in:
				fade_rect.color.a = 0.0  # Ensure fully transparent after fade in

func _change_scene_deferred(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

# Optional helper to fade in from black
func start_fade_in(duration: float = 2.0) -> void:
	fade_duration = duration
	fade_timer = 0.0
	fading = true
	fade_in = true
