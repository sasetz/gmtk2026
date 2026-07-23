shader_type canvas_item;

// Holographic "foil" sheen for special/rare cards. Reads only the node's own
// UV/TIME (no screen texture), so it runs unchanged on GL Compatibility. Apply
// to a card's background ColorRect; it tints and adds a moving rainbow band.

uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform vec4 base_color : source_color = vec4(0.14, 0.12, 0.24, 1.0);

// Cheap hue → rgb.
vec3 hue(float h) {
	vec3 k = vec3(1.0, 2.0 / 3.0, 1.0 / 3.0);
	vec3 p = abs(fract(vec3(h) + k) * 6.0 - 3.0);
	return clamp(p - 1.0, 0.0, 1.0);
}

void fragment() {
	// Diagonal travelling band.
	float band = sin((UV.x + UV.y) * 6.0 - TIME * speed);
	float sheen = smoothstep(0.4, 1.0, band);
	vec3 rainbow = hue(fract((UV.x - UV.y) * 0.5 + TIME * 0.05 * speed));
	vec3 col = base_color.rgb + rainbow * sheen * intensity;
	COLOR = vec4(col, base_color.a);
}
