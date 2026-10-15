// The Goo Puddle (#43): a glossy, wobbling violet slime. The disc mesh's COLOR.a is 1 at the
// rim and 0 in the middle: the rim bulges up and darkens, the middle is a deep glossy pool with
// slow-moving highlights and little bubbles from the shared noise. Hand-lit (sun, sky, rim),
// like the karts.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.30, 0.06, 0.42);
uniform vec3 bright : source_color = vec3(0.78, 0.30, 0.95);
uniform float wobble = 1.0;
uniform float seed = 0.0;
uniform float fade = 1.0;

varying vec3 v_wn;
varying vec3 v_wp;
varying vec2 v_uv;
varying float v_rim;

void vertex() {
	v_rim = COLOR.a;
	v_uv = VERTEX.xz;
	float w = sin(TIME * 2.3 + VERTEX.x * 2.1 + seed) * sin(TIME * 1.7 + VERTEX.z * 2.6 + seed * 1.7);
	VERTEX.y += w * 0.025 * wobble * (1.0 - v_rim * 0.5);
	VERTEX.y *= fade;
	v_wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(v_wn);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wp);
	vec3 L = normalize(sun_dir);
	// Slow swirling depth.
	float sw = vnoise(v_uv * 7.0 + vec2(TIME * 0.6 + seed, -TIME * 0.4));
	vec3 base = mix(deep, bright, clamp(0.35 + sw * 0.45 - v_rim * 0.25, 0.0, 1.0));
	float ndl = dot(n, L);
	vec3 col = base * (hemi(n) * 0.7 + sun_color * (0.25 + 0.6 * smoothstep(-0.1, 0.3, ndl)));
	// Wet gloss: a hard sun highlight and a sky reflection at grazing angles.
	vec3 H = normalize(L + V);
	float spec = pow(max(dot(n, H), 0.0), 70.0);
	col += sun_color * smoothstep(0.3, 0.55, spec) * 1.2;
	float fres = pow(1.0 - max(dot(n, V), 0.0), 3.0);
	col += sky_color * fres * 0.55;
	// Bubbles: bright rings where the noise peaks, drifting.
	float b = vnoise(v_uv * 26.0 + vec2(seed * 3.0, TIME * 0.9));
	col += vec3(1.0, 0.85, 1.0) * smoothstep(0.78, 0.82, b) * (1.0 - smoothstep(0.84, 0.9, b)) * (1.0 - v_rim);
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
}
