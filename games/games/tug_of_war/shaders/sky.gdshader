// Tug of War's sky: Dodge Ball's (games/dodge_ball/shaders/sky.gdshader; the same presets) with
// Tug's grade (tug_look.gdshaderinc, no vignette), so the sky and the world agree. A horizon
// gradient, a sun (or moon) disc with a soft halo, hazy cloud bands and stars at night. No TIME,
// so the sky's radiance is only rebuilt when the time of day changes.
shader_type sky;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.25, 0.5, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.85, 0.95);
uniform vec3 below_color : source_color = vec3(0.3, 0.32, 0.3);
uniform vec3 disc_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_size = 0.03;
uniform float halo = 0.4;
uniform float stars = 0.0;
uniform float clouds = 0.5;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D star_tex : repeat_enable, filter_nearest;

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	col = mix(col, below_color, smoothstep(0.0, -0.08, h));
	float s = dot(dir, LIGHT0_DIRECTION);
	col += disc_color * halo * pow(max(s, 0.0), 8.0) * 0.6;
	col += disc_color * 0.25 * halo * pow(max(s, 0.0), 2.0) * smoothstep(0.35, 0.0, h);
	col = mix(col, disc_color * 1.6, smoothstep(1.0 - sun_size * 0.6, 1.0 - sun_size * 0.5, s));
	if (h > 0.0 && clouds > 0.0) {
		vec2 uv = dir.xz / (h + 0.18);
		float n = vnoise(uv * 1.3) * 0.6 + vnoise(uv * 3.1) * 0.3 + vnoise(uv * 7.0) * 0.1;
		float c = smoothstep(0.5, 0.8, n) * smoothstep(0.0, 0.15, h) * clouds;
		col = mix(col, cloud_color, c * 0.8);
	}
	if (stars > 0.0 && h > 0.0) {
		vec2 suv = dir.xz / (h + 0.35) * 3.0 + dir.y * 7.0;
		float r = texture(star_tex, suv).r;
		float star = step(0.993, r) * smoothstep(0.02, 0.25, h);
		col += vec3(0.9, 0.92, 1.0) * star * stars * (0.5 + 0.5 * texture(star_tex, suv * 1.7).r);
	}
	COLOR = grade(col, vec2(0.5));
}
