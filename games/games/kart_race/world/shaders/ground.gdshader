// The meadow (#43): the ground plane, the embankments beyond the barriers and the rolling
// hills, textured in world space so they meet seamlessly. Grass in two greens with sunlit and
// shaded patches, and wildflowers speckled in from the noise texture. Lit by hand (the normal
// comes from the mesh, so the hills shade); COLOR darkens and tints the far hills.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.33, 0.58, 0.19);
uniform vec3 grass_b : source_color = vec3(0.50, 0.71, 0.25);
uniform vec3 dry : source_color = vec3(0.70, 0.68, 0.36);
uniform float flowers = 1.0;

varying vec3 v_world;
varying vec3 v_light;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_light = hemi(wn) * 0.55 + sun_color * max(dot(wn, normalize(sun_dir)), 0.0) * 1.25;
}

void fragment() {
	vec2 p = v_world.xz;
	float big = vnoise(p * 0.035);
	float mid = vnoise(p * 0.21 + 5.0);
	float fine = vnoise(p * 1.9);
	vec3 col = mix(grass_a, grass_b, smoothstep(0.3, 0.75, big * 0.7 + mid * 0.3));
	col = mix(col, dry, 0.28 * smoothstep(0.6, 0.85, vnoise(p * 0.06 + 31.0)));
	col *= 0.86 + 0.24 * fine;
	// Wildflowers: sparse bright dots, denser in drifts.
	float dist = length(VERTEX);
	if (flowers > 0.0 && dist < 140.0) {
		float drift = smoothstep(0.45, 0.8, vnoise(p * 0.05 + 77.0));
		float dots = texture(noise_tex, p * 0.9).r;
		float pick = texture(noise_tex, p * 0.37 + 0.5).r;
		float f = smoothstep(0.93 - 0.08 * drift, 0.97 - 0.08 * drift, dots) * flowers * smoothstep(140.0, 60.0, dist);
		vec3 fc = pick < 0.33 ? vec3(1.0, 0.95, 0.35) : (pick < 0.66 ? vec3(0.98, 0.98, 1.0) : vec3(0.95, 0.45, 0.75));
		col = mix(col, fc, f);
	}
	ALBEDO = haze(col * COLOR.rgb * v_light, dist);
}
