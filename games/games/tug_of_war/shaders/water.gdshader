// The river between the piers (Tug of War, #40; graphics pass 2026-10-19). Hand-lit on the
// shared look (tug_look.gdshaderinc): two drifting ripple reads, which also tilt the normal; a
// fresnel to the two-colour sky; glitter only along the sun's (or the moon's) path; a soft foam
// band where the water meets the banks and around the pilings; darker under each pier's deck.
// The river covers a third of the screen, so it stays at two noise reads.
shader_type spatial;
render_mode unshaded, fog_disabled;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.071, 0.251, 0.361);
uniform vec3 shallow : source_color = vec3(0.161, 0.459, 0.549);
uniform vec3 sky_top : source_color = vec3(0.2, 0.46, 0.92);
uniform vec3 sky_horizon : source_color = vec3(0.72, 0.84, 0.96);
uniform float sparkle = 0.45;
uniform vec2 waterlines = vec2(-1.95, -11.65);  // where each bank meets the water (z)
uniform vec2 pier_ends = vec2(-2.6, -11.0);
uniform float pier_half = 2.5;
uniform float piling_x = 2.3;

varying vec3 v_wp;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The river flows across the view (along x).
	vec2 uv = v_wp.xz;
	float a = texture(noise_tex, uv * 0.045 + vec2(TIME * 0.05, TIME * 0.012)).r;
	float b = texture(noise_tex, uv * 0.13 + vec2(TIME * 0.11, -TIME * 0.02)).r;
	float ripple = a * 0.6 + b * 0.4;
	vec3 n = normalize(vec3((a - 0.5) * 0.32 + (b - 0.5) * 0.22, 1.0, (b - 0.5) * 0.32 - (a - 0.5) * 0.14));
	vec3 v = normalize(CAMERA_POSITION_WORLD - v_wp);
	vec3 r = reflect(-v, n);
	// The body of the water, lit, with a floor so the river never goes black at night.
	vec3 body = mix(deep, shallow, ripple) * max(sun_light(vec3(0.0, 1.0, 0.0)), vec3(0.45));
	// Fresnel: the sky shows at a grazing view, overhead blue higher up the reflection.
	vec3 sky = mix(sky_horizon, sky_top, pow(clamp(r.y, 0.0, 1.0), 0.6));
	float fres = 0.08 + 0.72 * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	vec3 col = mix(body, sky, fres);
	// Glitter in a band toward the sun, broken up by the fine ripples.
	float spec = pow(max(dot(r, normalize(sun_dir)), 0.0), 24.0);
	float glints = smoothstep(0.55, 0.85, b) * (0.5 + 0.5 * a);
	col += sun_color * (spec * 2.2 * glints + spec * 0.25) * sparkle;
	// Foam: along the banks (broken by the slow ripples) and around the pilings.
	float bank = min(waterlines.x - v_wp.z, v_wp.z - waterlines.y);
	float foam = (1.0 - smoothstep(0.0, 0.32, bank + (a - 0.5) * 0.35)) * 0.75;
	float px = abs(abs(v_wp.x) - piling_x);
	float pz = min(abs(v_wp.z - (pier_ends.x + 0.16)), abs(v_wp.z - (pier_ends.y - 0.16)));
	float pile = length(vec2(px, pz));
	foam = max(foam, (1.0 - smoothstep(0.13, 0.3, pile + (b - 0.5) * 0.12)) * 0.8);
	vec3 foam_col = vec3(0.9, 0.95, 0.97) * max(sun_light(vec3(0.0, 1.0, 0.0)), vec3(0.35));
	col = mix(col, foam_col, foam * smoothstep(0.3, 0.6, ripple + 0.15));
	// Shade under the piers' decks.
	float inside = 1.0 - smoothstep(pier_half - 0.15, pier_half + 0.15, abs(v_wp.x));
	float under = max(smoothstep(pier_ends.x - 0.2, pier_ends.x + 0.2, v_wp.z),
		smoothstep(pier_ends.y + 0.2, pier_ends.y - 0.2, v_wp.z));
	col *= 1.0 - 0.45 * inside * under;
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
}
