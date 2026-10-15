// The Shield Bubble (#43): a soap-film sphere round the kart. Iridescent fresnel edge, a
// procedural hex lattice that shimmers across it, a ripple on a blocked hit (`hit`), and a
// flicker when it is about to run out (`flicker`). Additive-ish alpha: the kart stays visible.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, blend_mix, depth_draw_never;

uniform vec3 color : source_color = vec3(0.35, 0.85, 1.0);
uniform float hit = 0.0;
uniform float flicker = 0.0;
uniform float grow = 1.0;

varying vec3 v_wn;
varying vec3 v_wp;
varying vec3 v_lp;

float hex(vec2 p) {
	p *= vec2(1.0, 1.1547);
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 f = abs(fract(p) - 0.5);
	return max(f.x * 1.5 + f.y, f.y * 2.0);
}

void vertex() {
	v_wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_lp = VERTEX;
	VERTEX *= grow * (1.0 + hit * 0.08 * sin(TIME * 40.0 + VERTEX.y * 6.0));
}

void fragment() {
	vec3 n = normalize(v_wn);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wp);
	float fres = pow(1.0 - abs(dot(n, V)), 2.0);
	// Thin-film colours shifting with the view angle and time.
	float film = fres * 3.0 + TIME * 0.35 + v_lp.y * 0.6;
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (film + vec3(0.0, 0.33, 0.67)));
	vec3 col = mix(color, irid, 0.45);
	// The lattice, sweeping up.
	vec2 uv = vec2(atan(v_lp.x, v_lp.z) * 2.2, v_lp.y * 3.2 - TIME * 0.7);
	float h = hex(uv * 1.6);
	float line = smoothstep(0.88, 0.97, h);
	float sweep = smoothstep(0.6, 1.0, sin(v_lp.y * 2.5 - TIME * 3.0));
	float a = 0.08 + fres * 0.65 + line * (0.18 + 0.4 * sweep) + hit * 0.5;
	col += vec3(1.0) * (line * sweep * 0.6 + hit * 0.8);
	float on = 1.0 - flicker * step(0.5, fract(TIME * 9.0));
	ALBEDO = col;
	ALPHA = clamp(a * on, 0.0, 0.9);
}
