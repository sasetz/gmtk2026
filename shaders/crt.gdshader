shader_type canvas_item;
render_mode blend_mul, unshaded;

// Full-screen CRT feel as a MULTIPLY overlay: it darkens scanlines and edges
// without reading the screen texture, so it's fully portable to web/GL
// Compatibility (no hint_screen_texture, which is unreliable on web export).
// Put it on a ColorRect covering the viewport on a high CanvasLayer.

uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.10;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float flicker_strength : hint_range(0.0, 0.1) = 0.015;

void fragment() {
	// Scanlines: darken every other logical row.
	float row = UV.y * view_size.y;
	float scan = 1.0 - scanline_strength * (0.5 + 0.5 * sin(row * 3.14159));

	// Vignette: fall off toward the corners.
	vec2 d = UV - vec2(0.5);
	float vig = 1.0 - vignette_strength * dot(d, d) * 2.2;

	// A hair of global flicker so the panel feels alive.
	float flick = 1.0 - flicker_strength * (0.5 + 0.5 * sin(TIME * 8.0));

	float lum = clamp(scan * vig * flick, 0.0, 1.0);
	COLOR = vec4(vec3(lum), 1.0);
}
