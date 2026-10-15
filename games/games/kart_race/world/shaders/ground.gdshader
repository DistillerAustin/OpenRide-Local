// The ground (#43): the terrain, the embankments beyond the barriers and the far hills,
// textured in world space so they meet seamlessly. Two ground colours (grass, sand or snow,
// by theme) with sunlit and shaded patches and bright specks (wildflowers, pebbles, glints);
// steep slopes and high ground turn to rock in layered strata (Canyon Dash's red bands). Lit by
// hand per vertex (the normal comes from the mesh, so the hills shade); COLOR tints (the far
// hills bluer). Three texture reads at most: the tablet is fill-rate bound.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.33, 0.58, 0.19);
uniform vec3 grass_b : source_color = vec3(0.50, 0.71, 0.25);
uniform vec3 dry : source_color = vec3(0.70, 0.68, 0.36);
uniform float flowers = 1.0;
uniform vec3 speck_a : source_color = vec3(1.0, 0.95, 0.35);
uniform vec3 speck_b : source_color = vec3(0.98, 0.98, 1.0);
uniform vec3 speck_c : source_color = vec3(0.95, 0.45, 0.75);
// Rock: below this normal.y a slope is rock; strata are bands `strata` metres tall.
uniform vec3 rock_a : source_color = vec3(0.55, 0.52, 0.46);
uniform vec3 rock_b : source_color = vec3(0.46, 0.43, 0.38);
uniform vec3 rock_c : source_color = vec3(0.62, 0.58, 0.5);
uniform float rock_slope = 0.55;
uniform float strata = 2.5;
uniform float detail = 1.0;  // 0: no rock strata, specks or fine grain (a dev switch)

varying vec3 v_world;
varying vec3 v_light;
varying float v_rock;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_light = hemi(wn) * 0.55 + sun_color * max(dot(wn, normalize(sun_dir)), 0.0) * 1.25;
	v_rock = smoothstep(rock_slope + 0.08, rock_slope - 0.08, wn.y);
}

void fragment() {
	vec2 p = v_world.xz;
	float big = vnoise(p * 0.035);
	float fine = detail > 0.0 ? vnoise(p * 0.9) : 0.5;
	vec3 col = mix(grass_a, grass_b, smoothstep(0.3, 0.75, big * 0.8 + fine * 0.2));
	col = mix(col, dry, 0.28 * smoothstep(0.62, 0.8, 1.0 - big));
	col *= 0.86 + 0.24 * fine;
	float dist = length(VERTEX);
	// Rock in strata: bands by height, wobbling with the noise, lighter and darker layers.
	if (v_rock > 0.01 && detail > 0.0) {
		float y = v_world.y / strata + big * 1.6;
		float band = fract(y);
		float layer = fract(floor(y) * 0.618);
		vec3 rock = mix(rock_a, rock_b, step(0.5, layer));
		rock = mix(rock, rock_c, step(0.82, layer));
		// A lit lip at the top of each band, a shadowed undercut at its foot.
		rock *= 0.82 + 0.26 * smoothstep(0.0, 0.85, band) - 0.18 * smoothstep(0.12, 0.0, band);
		rock *= 0.9 + 0.2 * fine;
		col = mix(col, rock, v_rock);
	}
	// Specks: sparse bright dots, denser in drifts (flowers, pebbles or glints by theme).
	if (flowers * detail > 0.0 && dist < 140.0) {
		float drift = smoothstep(0.45, 0.8, big);
		float dots = texture(noise_tex, p * 0.9).r;
		float pick = fract(fine * 7.31);
		float f = smoothstep(0.93 - 0.08 * drift, 0.97 - 0.08 * drift, dots) * flowers * smoothstep(140.0, 60.0, dist) * (1.0 - v_rock);
		vec3 fc = pick < 0.33 ? speck_a : (pick < 0.66 ? speck_b : speck_c);
		col = mix(col, fc, f);
	}
	ALBEDO = grade(haze(col * COLOR.rgb * v_light, dist), SCREEN_UV);
}
