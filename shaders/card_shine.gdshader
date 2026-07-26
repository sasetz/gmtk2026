shader_type canvas_item;
// A soft diagonal gloss whose highlight slides as the card tilts, for the hover
// effect. The `tilt` uniform is fed the mouse offset from the card's script.

uniform vec2 tilt = vec2(0.0);
uniform float strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float diagonal = UV.x - UV.y;          // -1 .. 1 across the card
	float center = tilt.x * 0.6;           // slide the band with horizontal tilt
	float band = smoothstep(0.30, 0.0, abs(diagonal - center));
	COLOR = vec4(vec3(1.0), band * strength);
}
