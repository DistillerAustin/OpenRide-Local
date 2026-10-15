// Item pods' glass capsules (#43): faceted, see-through glass with a bright fresnel rim, a sharp
// sun glint and vertical sheen bands that sweep as the capsule turns, tinted by the core's hue
// (INSTANCE_CUSTOM.r) and popping white on respawn (INSTANCE_CUSTOM.g). Lit by hand like the
// rest of the world; alpha-blended, small on screen.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, blend_mix, depth_draw_never;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform float time_scale = 1.0;

varying vec3 v_wn;
varying vec3 v_wp;
varying vec3 v_lp;
varying float v_hue;
varying float v_pop;

vec3 hue_rgb(float h) {
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k;
}

void vertex() {
	v_wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_lp = VERTEX;
	v_hue = INSTANCE_CUSTOM.r;
	v_pop = INSTANCE_CUSTOM.g;
}

void fragment() {
	vec3 n = normalize(v_wn);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wp);
	vec3 L = normalize(sun_dir);
	float fres = pow(1.0 - abs(dot(n, V)), 2.2);
	vec3 tint = mix(vec3(0.75, 0.92, 1.0), hue_rgb(v_hue) * 0.6 + 0.5, 0.45);
	vec3 col = tint * (hemi(n) * 0.6 + 0.5);
	// Sheen bands up the glass, turning with the capsule.
	float a = atan(v_lp.x, v_lp.z);
	float band = smoothstep(0.82, 0.97, sin(a * 3.0 + v_lp.y * 1.4));
	col += vec3(1.0) * band * 0.35;
	// The sun glint.
	vec3 H = normalize(L + V);
	float spec = pow(max(dot(n, H), 0.0), 90.0);
	col += sun_color * smoothstep(0.25, 0.5, spec) * 1.4;
	col += vec3(1.0, 0.97, 0.9) * fres * 0.9;
	col = mix(col, vec3(1.0), v_pop);
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
	ALPHA = clamp(0.2 + fres * 0.8 + band * 0.3 + spec * 0.8 + v_pop, 0.0, 0.95);
}
