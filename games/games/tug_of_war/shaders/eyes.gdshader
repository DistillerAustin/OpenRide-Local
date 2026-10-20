// The bot's eyes: self-lit lenses whose colour and glow animate with its state (cyan, amber on a
// telegraph, red in a surge). The core whitens as the glow rises. Not graded: they are lights.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

uniform vec3 eye_color : source_color = vec3(0.3, 0.9, 1.0);
uniform float glow = 1.5;

void fragment() {
	float core = pow(clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 2.0);
	vec3 c = eye_color * min(0.55 + glow * 0.3, 1.6);
	ALBEDO = mix(c, vec3(1.0), core * clamp((glow - 1.0) * 0.12, 0.0, 0.35));
}
