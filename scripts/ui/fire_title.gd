extends Control
## A title whose LETTERS smoulder like charcoal: pixel embers spawn along the
## outline of the glyphs and float up like a torch.
##
## To emit from the letter shapes (not just a band), the text is rasterised once
## into an offscreen SubViewport, its image is read back on the CPU, and the
## border pixels (ink next to empty) become the particle emission points. The
## reading is a CPU get_image() readback — unlike sampling a viewport texture in
## a shader, that is reliable under GL Compatibility.

@export var text: String = "BALATRO COUNT-DOWN"
@export var font_size: int = 68
@export var color: Color = Color(0.98, 0.86, 0.4)

var _label: Label
var _fire: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)
	# Wait for layout so our size is valid, then light the coals.
	await get_tree().process_frame
	await _ignite()


func _ignite() -> void:
	var points: PackedVector2Array = await _glyph_border_points()
	if points.is_empty():
		return
	_fire = Fx.charcoal(points)
	_fire.position = size * 0.5   # points are stored relative to centre
	add_child(_fire)               # in FRONT of the label, so embers lick over it


## Rasterise the title and return the outline pixels of the glyphs, in
## emitter-local (centre-origin) coordinates.
func _glyph_border_points() -> PackedVector2Array:
	var w: int = maxi(8, int(ceil(size.x)))
	var h: int = maxi(8, int(ceil(size.y)))

	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.size = Vector2i(w, h)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(l)

	# Let the viewport actually paint before reading it back.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()

	var pts := PackedVector2Array()
	var centre := Vector2(float(w), float(h)) * 0.5
	var step: int = 2
	for y in range(step, h - step, step):
		for x in range(step, w - step, step):
			if img.get_pixel(x, y).a <= 0.4:
				continue
			# Border = ink with at least one empty 4-neighbour.
			if img.get_pixel(x - step, y).a <= 0.4 or img.get_pixel(x + step, y).a <= 0.4 \
					or img.get_pixel(x, y - step).a <= 0.4 or img.get_pixel(x, y + step).a <= 0.4:
				pts.append(Vector2(float(x), float(y)) - centre)
	return pts
