// Open water and lake ice (#43): Harbor Lights' sea at sunset and Frost Pass's frozen lake.
// Unshaded and opaque (no blending): a deep-to-shallow colour rippled by two scrolling noise
// reads, the sky's horizon reflected at grazing angles, and the sun's glitter path off a wavy
// normal. With `ice` = 1 the ripples stop, the glitter sharpens to glints, and pale cracks and
// snow drifts and skate scratches show. Three texture reads (the tablet is fill-rate bound).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.10, 0.22, 0.40);
uniform vec3 shallow : source_color = vec3(0.18, 0.42, 0.58);
uniform vec3 reflect_color : source_color = vec3(1.0, 0.62, 0.4);
uniform float ice = 0.0;
uniform vec3 snow : source_color = vec3(0.92, 0.95, 1.0);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_world);
	float t = TIME * (1.0 - ice);
	float n1 = vnoise(p * 0.32 + vec2(t * 0.55, t * 0.2));
	float n2 = vnoise(p * 0.85 - vec2(t * 0.35, -t * 0.6));
	float wave = n1 * 0.6 + n2 * 0.4;
	float rough = 0.32 * (1.0 - ice) + 0.06 * ice;
	vec3 N = normalize(vec3((n1 - 0.5) * rough, 1.0, (n2 - 0.5) * rough));
	float fres = pow(1.0 - max(dot(N, V), 0.0), 3.0);
	vec3 col = mix(deep, shallow, 0.25 + 0.5 * wave);
	col = mix(col, reflect_color, clamp(fres * 0.9, 0.0, 0.85 - 0.35 * ice));
	vec3 R = reflect(-V, N);
	float sp = pow(max(dot(R, normalize(sun_dir)), 0.0), mix(60.0, 400.0, ice));
	col += sun_color * sp * mix(2.2 * smoothstep(0.35, 0.7, wave), 3.0, ice);
	if (ice > 0.0) {
		float big = vnoise(p * 0.07 + 31.0);
		float crack = (1.0 - smoothstep(0.0, 0.025, abs(n1 - 0.5))) * smoothstep(0.3, 0.6, n2);
		col = mix(col, snow * 0.95, crack * 0.55 * ice);
		col = mix(col, snow, smoothstep(0.7, 0.85, big) * ice * 0.8);
		// Skate scratches: long thin pale arcs, broken up by the ripple read.
		float sk = abs(fract(dot(p, vec2(0.37, 0.93)) * 0.6 + n2 * 1.5) - 0.5);
		col = mix(col, snow, (1.0 - smoothstep(0.0, 0.035, sk)) * smoothstep(0.35, 0.6, n1) * 0.4 * ice);
	}
	col *= 0.85 + 0.25 * sun_color.r;
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
}
