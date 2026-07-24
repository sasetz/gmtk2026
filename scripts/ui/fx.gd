class_name Fx
extends RefCounted
## Particle-effect factory. Each function returns a configured CPUParticles2D
## (GL-Compatibility-safe) the caller adds to the tree and positions. One-shot
## bursts free themselves when they finish, so callers can fire-and-forget.
##
## A shared soft round "dot" texture is used for every effect so flames, embers
## and sparks all read as soft blobs rather than hard 1px points.

static var _dot_tex: ImageTexture = null


## A soft radial dot, built once and reused.
static func _dot() -> ImageTexture:
	if _dot_tex != null:
		return _dot_tex
	var size: int = 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = float(size) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) - c + 0.5, float(y) - c + 0.5).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex


## A small solid square, for chunky "pixel" embers (reads great under the
## pixelation pass). Built once and reused.
static var _sq_tex: ImageTexture = null
static func _square() -> ImageTexture:
	if _sq_tex != null:
		return _sq_tex
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_sq_tex = ImageTexture.create_from_image(img)
	return _sq_tex


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


static func _shrink_curve(from: float = 1.0) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, 0.0))
	return c


## Rising flames emitted along a horizontal band `width` wide. Loops. Position
## it at the base of whatever should burn.
static func fire(width: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _dot()
	p.material = _additive()
	p.amount = 130
	p.lifetime = 0.85
	p.preprocess = 0.85          # already full when it appears
	p.local_coords = false        # particles detach and rise in world space
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width * 0.5, 10.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 20.0
	p.gravity = Vector2(0.0, -55.0)   # buoyancy: flames accelerate upward
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.damping_min = 8.0
	p.damping_max = 24.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.7
	p.scale_amount_curve = _grow_then_shrink()
	p.color_ramp = _fire_ramp()
	return p


## Burning-charcoal embers: pixel sparks that spawn ON the given points (the
## border of some text/shape, in the emitter's local space), swirl briefly at
## the edge, then float upward and cool from white-hot to ash. This is the
## "letters as glowing charcoal / a torch" look — feed it a glyph outline.
static func charcoal(points: PackedVector2Array) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _square()
	p.material = _additive()
	p.amount = clampi(points.size() * 2 / 3, 220, 500)
	p.lifetime = 1.0
	p.preprocess = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = points
	p.direction = Vector2(0.0, -1.0)
	p.spread = 18.0                       # mostly straight up, like a torch
	p.gravity = Vector2(0.0, -38.0)       # buoyant rise
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 46.0
	p.orbit_velocity_min = -0.12          # a little swirl "around the border"
	p.orbit_velocity_max = 0.12
	p.damping_min = 6.0
	p.damping_max = 20.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.scale_amount_curve = _shrink_curve(1.0)
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.98, 0.85, 1.0))   # white-hot at the coal
	g.set_color(1, Color(0.12, 0.02, 0.0, 0.0))   # cooled ash, gone
	g.add_point(0.25, Color(1.0, 0.72, 0.22, 1.0))
	g.add_point(0.55, Color(1.0, 0.33, 0.07, 0.9))
	g.add_point(0.8, Color(0.5, 0.08, 0.02, 0.5))
	p.color_ramp = g
	return p


## Slow, sparse embers drifting up over a rectangle (ambient menu atmosphere).
static func embers(width: float, height: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _dot()
	p.material = _additive()
	p.amount = 46
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width * 0.5, height * 0.5)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 35.0
	p.gravity = Vector2(0.0, -12.0)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 34.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.7
	p.scale_amount_curve = _twinkle_curve()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.75, 0.35, 0.0))
	g.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
	g.add_point(0.3, Color(1.0, 0.8, 0.4, 0.55))
	p.color_ramp = g
	return p


## A one-shot radial burst that frees itself. Great for hits, pops and pickups.
static func burst(col: Color, count: int = 26, speed: float = 240.0,
		life: float = 0.6, fall: float = 480.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _dot()
	p.material = _additive()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = Vector2(0.0, fall)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _shrink_curve()
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 1.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	p.finished.connect(p.queue_free)
	p.emitting = true
	return p


## Multicolour celebration that rains down. Returns several emitters (one per
## colour, since CPUParticles2D is single-ramp); caller adds them all.
static func confetti(count: int = 22) -> Array[CPUParticles2D]:
	var cols: Array[Color] = [
		Color(0.98, 0.82, 0.3), Color(0.4, 0.9, 0.55),
		Color(0.5, 0.8, 0.98), Color(0.95, 0.45, 0.75),
	]
	var out: Array[CPUParticles2D] = []
	for col: Color in cols:
		var p := burst(col, count, 320.0, 1.4, 620.0)
		p.material = null               # confetti reads better opaque
		p.spread = 60.0                 # mostly upward fountain
		p.initial_velocity_min = 180.0
		p.initial_velocity_max = 420.0
		out.append(p)
	return out


static func _fire_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.96, 0.6, 1.0))
	g.set_color(1, Color(0.7, 0.06, 0.02, 0.0))
	g.add_point(0.3, Color(1.0, 0.62, 0.12, 0.95))
	g.add_point(0.65, Color(0.95, 0.26, 0.06, 0.55))
	return g


static func _grow_then_shrink() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(0.22, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


static func _twinkle_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.5, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c
