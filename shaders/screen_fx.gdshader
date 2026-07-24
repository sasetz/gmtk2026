shader_type canvas_item;
render_mode unshaded;

// Global screen post-process: chunky pixelation, a fisheye (barrel) bulge, and
// a VHS tape look. Lives on a full-viewport ColorRect on the topmost
// CanvasLayer, so it samples everything already drawn beneath it — game, menus
// and all.
//
// Unlike shaders/crt.gdshader (a pure multiply overlay), this one READS the
// screen, which is what warping UVs and splitting the RGB channels requires.
// The three `*_amount` uniforms are the on/off switches driven by Settings; at
// 0/0/0 this is a straight blit, and ScreenFX hides the rect entirely so the
// screen-texture pass costs nothing at all.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform vec2 view_size = vec2(1280.0, 720.0);

// Master switches (0 = off, 1 = on).
uniform float fisheye_amount : hint_range(0.0, 1.0) = 1.0;
uniform float vhs_amount : hint_range(0.0, 1.0) = 1.0;
uniform float pixelate_amount : hint_range(0.0, 1.0) = 1.0;

// Taste knobs. Tuned deliberately GENTLE — this is a flavour pass over a game
// about reading small numbers, so legibility beats spectacle. The tape wobble
// in particular is kept to a fraction of a pixel: enough to feel like tape,
// not enough to make the digits swim.
uniform float fisheye_strength : hint_range(0.0, 1.0) = 0.06;
uniform float aberration_px : hint_range(0.0, 8.0) = 1.3;
uniform float scanline_strength : hint_range(0.0, 0.6) = 0.07;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.38;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.016;
uniform float wobble_strength : hint_range(0.0, 0.02) = 0.0002;
uniform float bar_strength : hint_range(0.0, 0.5) = 0.03;

// Pixelation: side of one chunky "pixel", in real screen pixels. Kept low (1.2)
// so it's a whisper of retro quantise, not a legibility fight — this is a
// whole-screen downsample over small card text.
uniform float pixel_size : hint_range(1.0, 12.0) = 1.1;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

void fragment() {
	// `screen` stays the raw, undistorted coordinate. Every post effect
	// (scanlines, bar, grain, vignette) is measured against IT rather than the
	// warped/wobbled one, so those layers sit still while only the picture
	// underneath moves. Letting them ride the wobble is what made the old
	// version feel seasick.
	vec2 screen = SCREEN_UV;
	vec2 s = screen;

	// --- Pixelation ---
	// Snap to a screen-aligned block grid BEFORE any warping, so every fragment
	// inside a block resolves to the same sample point — crisp, uniform squares
	// instead of a grid that smears along the lens curve.
	if (pixelate_amount > 0.001) {
		vec2 grid = max(view_size / max(pixel_size, 1.0), vec2(1.0));
		s = (floor(s * grid) + 0.5) / grid;
	}

	vec2 cc = s - vec2(0.5);
	float r2 = dot(cc, cc);

	// --- Fisheye: bulge pixels outward proportional to r^2, then OVERSCAN back
	// so the corners land exactly on the corners. Without that divide the bulge
	// pushes the picture off-screen, black-barring the edges and clipping the
	// HUD; with it you get the real lens feel (centre magnified, rim compressed)
	// and not a single pixel of the frame is lost.
	float k = fisheye_strength * fisheye_amount;
	vec2 uv = 0.5 + (cc * (1.0 + r2 * k)) / (1.0 + 0.5 * k);

	// --- VHS: ONE slow, low-frequency tape sway ---
	// There is deliberately no high-frequency ripple here. The previous version
	// used sin(uv.y * 190.0 + TIME * 5.0), which is a full oscillation every ~4
	// screen rows animating fast — neighbouring rows shove opposite ways every
	// frame, which reads as strobing vertical lines and is a real motion-
	// sickness trigger. Keep the frequency low (a few cycles down the whole
	// screen) and the speed slow; anything finer must stay static.
	if (vhs_amount > 0.001) {
		float w = sin(uv.y * 4.0 - TIME * 0.5);
		uv.x += w * wobble_strength * vhs_amount;
	}

	// The sampler is clamp-to-edge (repeat_disable), so the tape wobble smears
	// the edge pixel instead of tearing a black sliver at the frame boundary.
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// --- Chromatic aberration, widening toward the rim like real optics ---
	vec3 col;
	float ab = (aberration_px / view_size.x) * vhs_amount * (0.35 + r2 * 2.5);
	col.r = texture(screen_tex, vec2(uv.x + ab, uv.y)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, vec2(uv.x - ab, uv.y)).b;

	if (vhs_amount > 0.001) {
		// Scanlines.
		col *= 1.0 - scanline_strength * vhs_amount
			* (0.5 + 0.5 * sin(screen.y * view_size.y * 3.14159));

		// Rolling tape-head bar, drifting slowly enough to read as an object
		// passing by rather than a flicker.
		float bar = fract(screen.y - TIME * 0.025);
		col *= 1.0 + bar_strength * vhs_amount
			* smoothstep(0.90, 0.98, bar) * (1.0 - smoothstep(0.98, 1.0, bar));

		// Grain, stepped to ~8 refreshes a second and in coarser cells. Noise
		// re-randomised every frame is full-screen high-frequency flicker —
		// the other half of what made this nauseating.
		float tq = floor(TIME * 8.0);
		float n = hash21(floor(screen * view_size * 0.5) + vec2(tq * 37.0, tq * 11.0));
		col += (n - 0.5) * noise_strength * vhs_amount;
	}

	// Vignette — either tube effect implies curved glass, so tie it to both.
	vec2 vc = screen - vec2(0.5);
	col *= 1.0 - clamp(vignette_strength * dot(vc, vc)
		* max(vhs_amount, fisheye_amount), 0.0, 1.0);

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
