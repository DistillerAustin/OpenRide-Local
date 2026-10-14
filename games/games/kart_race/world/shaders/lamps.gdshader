// The start gantry's five lamps (#43). COLOR.r = the lamp's index / 5. stage 0: all dark;
// 1-5: that many lit red; 6: all green (GO). Lit lamps are full bright (they glow).
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform int stage = 0;

void fragment() {
	float idx = floor(COLOR.r * 5.0 + 0.5);
	vec3 off = vec3(0.12, 0.05, 0.05);
	vec3 col = off;
	if (stage >= 6) {
		col = vec3(0.35, 1.0, 0.45);
	} else if (idx < float(stage)) {
		col = vec3(1.0, 0.18, 0.12);
	}
	// A hot centre.
	ALBEDO = col * (0.8 + 0.4 * COLOR.g);
}
