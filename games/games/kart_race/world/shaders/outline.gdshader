// The inverted-hull outline pass for karts and drivers (#43): back faces pushed out along the
// normal. A soft line: tinted by the surface's own colour (a deep shade of it, not black), and
// per-vertex width (UV.x: 0 on eye glints and blush, thinner on small parts). Thicker with
// distance a little, so far karts keep a readable edge.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_front;

uniform vec3 color : source_color = vec3(0.12, 0.07, 0.16);
uniform float width = 0.02;
uniform float tint = 0.35;  // how much of the surface's colour the line takes

varying vec3 v_col;

void vertex() {
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += NORMAL * width * UV.x * clamp(dist * 0.08, 0.7, 2.5);
	v_col = COLOR.rgb;
}

void fragment() {
	ALBEDO = mix(color, v_col * 0.3, tint);
}
