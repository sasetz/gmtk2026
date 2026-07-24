extends CanvasLayer
## Global screen effects (autoloaded): the fisheye bulge + VHS tape look that
## sit on top of EVERY scene, menus included.
##
## On the highest CanvasLayer so it samples the finished frame beneath it, and
## PROCESS_MODE_ALWAYS so the tape keeps rolling while the game is paused.
## When both effects are off the rect is hidden outright — no screen-texture
## copy, no cost, and nothing that could misbehave on a web export.

@onready var _rect: ColorRect = $Rect


func _ready() -> void:
	# Never eat a click meant for the UI underneath.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Settings.changed.connect(apply)
	get_viewport().size_changed.connect(_update_view_size)
	_update_view_size()
	apply()


## Push the current Settings into the shader.
func apply() -> void:
	var mat: ShaderMaterial = _rect.material
	if mat == null:
		return
	mat.set_shader_parameter("vhs_amount", 1.0 if Settings.vhs_effect else 0.0)
	mat.set_shader_parameter("fisheye_amount", 1.0 if Settings.fisheye_effect else 0.0)
	mat.set_shader_parameter("pixelate_amount", 1.0 if Settings.pixelate_effect else 0.0)
	# Skip the whole pass when there's nothing to draw.
	_rect.visible = Settings.vhs_effect or Settings.fisheye_effect or Settings.pixelate_effect


## Scanline pitch and aberration are in pixels, so the shader needs the real
## viewport size — and needs it again whenever the window is resized.
func _update_view_size() -> void:
	var mat: ShaderMaterial = _rect.material
	if mat == null:
		return
	mat.set_shader_parameter("view_size", get_viewport().get_visible_rect().size)
