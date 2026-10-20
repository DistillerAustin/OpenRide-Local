// The handlebars (one merged, vertex-coloured mesh in the camera's frame): hand-lit matte metal,
// rubber and the accent stem, from a fixed top light (in view space, so the bars never flicker
// as the rider leans), tinted by the time of day's sky and sun so they darken at night, with a
// soft sheen band on the metal (vertex alpha) and a cool rim. Never engine specular.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

#include "res://games/dodge_ball/shaders/look.gdshaderinc"

void fragment() {
	vec3 n = normalize(NORMAL);
	float sheen = COLOR.a;
	vec3 light = hemi(n) + sun_color * (0.2 + 0.5 * smoothstep(-0.1, 0.9, n.y));
	vec3 col = COLOR.rgb * light;
	// The sheen: a bright band where the tube turns up towards the light, a darker core below.
	float band = smoothstep(0.45, 0.8, n.y) * smoothstep(1.0, 0.86, n.y);
	col += sheen * band * 0.45 * (sky_color + sun_color * 0.6);
	col *= 1.0 - sheen * 0.25 * smoothstep(0.0, -0.6, n.y);
	float rim = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	col += vec3(0.55, 0.72, 1.0) * rim * 0.3 * (0.25 + 0.75 * sky_color);
	ALBEDO = grade(col, SCREEN_UV);
}
