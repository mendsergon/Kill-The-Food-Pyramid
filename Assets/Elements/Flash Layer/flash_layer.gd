extends CanvasLayer

@onready var flash_rect: ColorRect = $FlashRect

const FLASH_DURATION = 1.0 # adjust this to your liking (in seconds)
const FADE_SPEED = 0.05 # adjust this to control the speed of the transition

var is_fading_out = false
var fade_amount = (flash_rect.rect_size.x / 100)

func _process(_delta):
	if not is_fading_out:
		# Flash once
		flash_rect.color = Color(1, 0, 0) # Red flash
		
		# Gradually fade out to black over the specified duration
		for t in range(int(FLASH_DURATION * 10)): 
			var progress = (t / float(FLASH_DURATION * 10))
			flash_rect.color = Color(1, 0, 0, 1 - (progress * FADE_SPEED))
		
		# Fade back in to the initial color over a shorter duration
		for t in range(int((flash_rect.rect_size.x / 100) * 2)): 
			var progress = (t / float((flash_rect.rect_size.x / 100))) 
			flash_rect.color = Color(1, 0, 0, 1 - (progress * FADE_SPEED))

	else:
		# Fade back in to the initial color
		for t in range(int(FLASH_DURATION * 10)): 
			var progress = (t / float(FLASH_DURATION * 10)) 
			flash_rect.color = Color(1, 0, 0, 1 - (progress * FADE_SPEED))

	if not is_fading_out:
		is_fading_out = true
	else:
		is_fading_out = false
