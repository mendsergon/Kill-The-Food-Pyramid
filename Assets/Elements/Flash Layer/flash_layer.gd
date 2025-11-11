extends CanvasLayer

@onready var flash_rect: ColorRect = $FlashRect

const FLASH_DURATION = 2.0

func _ready():
	# Make sure the ColorRect covers the entire viewport
	_resize_flash_rect()

func _resize_flash_rect():
	# Get the viewport size and set the flash rect to match
	var viewport_size = get_viewport().get_visible_rect().size
	flash_rect.size = viewport_size

func trigger_flash():
	# Make sure the canvas layer is visible
	show()
	
	# Ensure the flash rect covers the entire screen
	_resize_flash_rect()
	
	# Set initial red color
	flash_rect.color = Color(1, 0, 0, 1)
	flash_rect.show()
	
	# Create tween for fade out
	var tween = create_tween()
	tween.tween_property(flash_rect, "color", Color(1, 0, 0, 0), FLASH_DURATION)
	tween.tween_callback(_on_flash_complete)

func _on_flash_complete():
	# Hide the flash rect and the entire canvas layer
	flash_rect.hide()
	hide()
