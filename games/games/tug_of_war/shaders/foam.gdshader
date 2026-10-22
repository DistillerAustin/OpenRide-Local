// A splash's foam on the water (ART_BIBLE §7): a ripple ring spreading out over a foam disc that
// fades, broken by noise. `progress` runs 0-1 over the splash (a tween); alpha blended.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, cull_disabled;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform float progress = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = vnoise(p * 9.0 + vec2(progress * 3.0, 0.0));
	float ring_r = mix(0.1, 0.92, sqrt(progress));
	float ring = 1.0 - smoothstep(0.02, 0.07 + 0.05 * progress, abs(r - ring_r + (n - 0.5) * 0.06));
	float disc = (1.0 - smoothstep(0.0, ring_r * 0.85, r)) * smoothstep(0.25, 0.75, n + 0.3 * (1.0 - progress));
	float a = max(ring * 0.85, disc * 0.7) * (1.0 - progress) * step(r, 1.0);
	vec3 col = vec3(0.92, 0.97, 1.0) * max(sun_light(vec3(0.0, 1.0, 0.0)), vec3(0.55));
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
	ALPHA = a;
}
