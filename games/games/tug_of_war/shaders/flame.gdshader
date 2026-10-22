// The far torches' flames (ART_BIBLE §7): one additive card each, a teardrop drawn from its UV,
// licking and flickering from TIME and one noise read, with a soft glow halo around it. Brighter
// at dusk and night (`lamp`). COLOR.a is each flame's phase. No engine lights.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_add, depth_draw_never, cull_disabled;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform float lamp = 0.0;

varying float v_ph;

void vertex() {
	v_ph = COLOR.a * 10.0;
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);  // x -1..1, y 0 at the cup to 1 at the top
	float flick = vnoise(vec2(TIME * 9.0 + v_ph * 7.0, v_ph * 5.0));
	float tall = 0.62 + 0.22 * flick;
	float y = p.y / tall;
	float lick = sin(p.y * 7.0 - TIME * 11.0 + v_ph) * 0.07 * p.y;
	float width = 0.42 * pow(max(1.0 - y, 0.0), 0.75) * smoothstep(-0.05, 0.18, y);
	float d = abs(p.x - lick);
	float body = 1.0 - smoothstep(width * 0.55, width, d);
	float core = 1.0 - smoothstep(width * 0.15, width * 0.5, d);
	core *= smoothstep(0.75, 0.2, y);
	vec3 flame = vec3(1.0, 0.36, 0.08) * body + vec3(1.0, 0.82, 0.45) * core * 0.9;
	float halo = exp(-length(vec2(p.x * 1.1, (p.y - 0.28) * 1.3)) * 3.2) * (0.12 + 0.3 * lamp) * (0.85 + 0.3 * flick);
	float edge = smoothstep(1.0, 0.8, abs(p.x)) * smoothstep(1.0, 0.85, p.y) * smoothstep(0.0, 0.06, p.y + 0.02);
	ALBEDO = (flame * (0.75 + 0.5 * lamp) + vec3(1.0, 0.55, 0.22) * halo) * edge;
}
