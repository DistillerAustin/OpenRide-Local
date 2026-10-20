shader_type canvas_item;
// Masks a picture to a rounded rectangle (the Games hub's cards, spec §7.2): an alpha mask from
// a rounded-rect SDF, anti-aliased over `feather` px. A card with corner radius R and a picture
// inset by `inset` uses radius R - inset, so the picture is concentric with the card's outline.
// Drawn inside a bake, so it costs nothing per frame.

uniform vec2 rect_size = vec2(314.0, 177.0);  // the picture's size in px
uniform float radius = 16.0;
uniform float feather = 1.5;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	float d = rounded_box(p, rect_size * 0.5, radius);
	vec4 c = COLOR;  // the texture, already sampled and tinted
	c.a *= clamp(0.5 - d / feather, 0.0, 1.0);
	COLOR = c;
}
