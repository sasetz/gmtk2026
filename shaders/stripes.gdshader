shader_type canvas_item;

// Horizontal two-tone stripes for the felt background — N equal rows alternating
// a base green and a slightly darker green across the whole rect. Apply to a
// full-screen ColorRect; UV.y spans the screen, so the bands fill it evenly.

uniform int rows : hint_range(1, 32) = 6;
uniform vec4 color_a : source_color = vec4(0.078, 0.22, 0.16, 1.0);
uniform vec4 color_b : source_color = vec4(0.055, 0.16, 0.115, 1.0);

void fragment() {
	int row = int(floor(UV.y * float(rows)));
	COLOR = (row % 2 == 0) ? color_a : color_b;
}
