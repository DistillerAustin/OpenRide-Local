// The inverted-hull outline pass for karts and drivers (#43): back faces pushed out along the
// normal, drawn flat dark. Thicker with distance a little, so far karts keep a readable edge.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_front;

uniform vec3 color : source_color = vec3(0.1, 0.07, 0.12);
uniform float width = 0.022;

void vertex() {
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += NORMAL * width * clamp(dist * 0.08, 0.7, 2.5);
}

void fragment() {
	ALBEDO = color;
}
