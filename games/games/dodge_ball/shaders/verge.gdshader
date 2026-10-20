// The grass verges either side of the road: mown stripes and noise, scrolled with the road.
shader_type spatial;
render_mode unshaded, fog_disabled;

// Lit and hazed by hand with the shared light (look.gdshaderinc): these planes cover most of the
// screen, and the engine's per-pixel light and fog cost the tablet about a third of its frame.
#include "res://games/dodge_ball/shaders/look.gdshaderinc"

uniform float scroll = 0.0;
uniform vec3 grass_a : source_color = vec3(0.24, 0.45, 0.18);
uniform vec3 grass_b : source_color = vec3(0.3, 0.52, 0.2);
uniform vec3 dirt : source_color = vec3(0.42, 0.36, 0.26);
uniform float road_half = 6.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// A flat surface's light: the sky ambient plus the sun at its elevation, never quite dark on
// the low dawn and dusk suns (the floor the road had before the shared light).
vec3 flat_light() {
	return hemi(vec3(0.0, 1.0, 0.0)) + sun_color * max(normalize(sun_dir).y, 0.12);
}

void fragment() {
	float z = world_pos.z - scroll;
	float ax = abs(world_pos.x);
	float stripe = step(0.5, fract(z / 9.0));
	vec3 col = mix(grass_a, grass_b, stripe);
	col *= 0.8 + 0.4 * vnoise(vec2(world_pos.x, z) * 1.7);
	// A dirt shoulder along the kerb.
	col = mix(dirt, col, smoothstep(road_half + 0.3, road_half + 1.1, ax + vnoise(vec2(ax, z) * 2.0) * 0.4));
	col = haze(col * flat_light() * 0.85, length(VERTEX));
	ALBEDO = grade(col, SCREEN_UV);
}
