// Karts and drivers (#43): a toon ramp with a soft terminator, a glossy highlight, a warm rim
// light and painted AO (vertex colours), lit by hand like the rest of the world. COLOR.a is the
// gloss mask (paint and visors shine, rubber and fur don't). Small on screen, so per pixel.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform vec3 rim_color : source_color = vec3(1.0, 0.88, 0.7);
uniform float rim = 0.55;
uniform float gloss = 1.0;
uniform float flash = 0.0;  // a white hit / boost flash

varying vec3 v_wn;
varying vec3 v_wp;

void vertex() {
	v_wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(v_wn);
	vec3 L = normalize(sun_dir);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wp);
	float ndl = dot(n, L);
	float ramp = smoothstep(-0.08, 0.18, ndl);
	vec3 base = COLOR.rgb;
	vec3 col = base * (hemi(n) * 0.75 + sun_color * (0.2 + 0.95 * ramp));
	vec3 H = normalize(L + V);
	float spec = pow(max(dot(n, H), 0.0), 60.0);
	col += sun_color * smoothstep(0.35, 0.55, spec) * 0.85 * gloss * COLOR.a * ramp;
	// A broad sheen for the lacquer.
	col += sky_color * pow(1.0 - max(dot(n, V), 0.0), 2.0) * 0.25 * COLOR.a;
	float r = pow(1.0 - max(dot(n, V), 0.0), 3.0);
	col += rim_color * r * rim * (0.35 + 0.65 * ramp);
	col = mix(col, vec3(1.0), flash);
	ALBEDO = haze(col, length(VERTEX));
}
