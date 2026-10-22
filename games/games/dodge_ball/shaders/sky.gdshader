// Dodge Ball's sky: a horizon gradient, a small sun (or moon) disc whose warmth is carried by a
// halo and a horizon glow toward its azimuth, cumulus clouds lit from the sun's side, and stars
// at night only. Graded like the world (look.gdshaderinc), without the vignette. No TIME, so the
// sky's radiance is only rebuilt when the time of day changes.
shader_type sky;

// The shared light's uniforms come with the include (only `grade` and `vnoise` are used here),
// so the sky's own colours have names of their own.
#include "res://games/dodge_ball/shaders/look.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.25, 0.5, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.85, 0.95);
uniform vec3 below_color : source_color = vec3(0.3, 0.32, 0.3);
uniform vec3 disc_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_size = 0.03;  // the disc's radius in radians (0.03 ≈ 1.7°, a 3.4° disc)
uniform float halo = 0.4;
uniform float stars = 0.0;
uniform float clouds = 0.5;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.75, 0.8, 0.9);  // the clouds' undersides
uniform sampler2D star_tex : repeat_enable, filter_nearest;

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	col = mix(col, below_color, smoothstep(0.0, -0.08, h));
	vec3 sun = LIGHT0_DIRECTION;
	float s = dot(dir, sun);
	// The halo, and a wide warm glow along the horizon toward the sun's azimuth.
	col += disc_color * halo * pow(max(s, 0.0), 8.0) * 0.55;
	vec2 az = normalize(sun.xz + vec2(0.0001));
	float toward = max(dot(normalize(dir.xz + vec2(0.0001)), az), 0.0);
	col += disc_color * halo * 0.35 * pow(toward, 3.0) * smoothstep(0.32, 0.0, abs(h)) * smoothstep(0.6, 0.0, sun.y);
	// Cumulus: one read for the shape at two scales, a third offset toward the sun for the lit
	// side (where the cloud thins toward the sun it's bright; its base is in shade).
	if (h > 0.0 && clouds > 0.0) {
		vec2 uv = dir.xz / (h + 0.18);
		float shape = vnoise(uv * 1.3) * 0.68 + vnoise(uv * 3.1) * 0.32;
		float lit_side = vnoise((uv + az * 0.35) * 1.3) * 0.68 + 0.16;
		float c = smoothstep(0.52, 0.72, shape) * smoothstep(0.0, 0.15, h) * clouds;
		float lit = clamp(0.55 + (shape - lit_side) * 3.0 + smoothstep(0.55, 0.8, shape) * 0.3, 0.0, 1.0);
		col = mix(col, mix(cloud_shade, cloud_color, lit), c * 0.85);
	}
	// The disc, small and crisp (about 3-4° across), over the clouds.
	float r = sun_size;
	col = mix(col, disc_color * 1.6, smoothstep(cos(r), cos(r * 0.8), s));
	// Stars.
	if (stars > 0.0 && h > 0.0) {
		vec2 suv = dir.xz / (h + 0.35) * 3.0 + dir.y * 7.0;
		float st = texture(star_tex, suv).r;
		float star = step(0.993, st) * smoothstep(0.02, 0.25, h);
		col += vec3(0.9, 0.92, 1.0) * star * stars * (0.5 + 0.5 * texture(star_tex, suv * 1.7).r);
	}
	COLOR = grade(col, vec2(0.5));
}
