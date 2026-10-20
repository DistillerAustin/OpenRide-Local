// The rider's gloves on the rope (ART_BIBLE §5): hand-lit by a fixed key light in view space
// (upper left, toward the camera) so they never go flat at night, tinted a little by the scene's
// light so they still sit in it. Graded like the world; no haze (they are a metre away).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

varying vec3 v_light;

void vertex() {
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float key = max(dot(n, normalize(vec3(-0.45, 0.75, 0.5))), 0.0);
	float fill = 0.5 + 0.5 * n.y;
	vec3 scene = clamp(sky_color + sun_color * 0.5, vec3(0.0), vec3(1.2));
	v_light = vec3(1.0, 0.97, 0.92) * (0.3 + 0.18 * fill + 0.62 * key) * mix(vec3(1.0), scene, 0.3);
}

void fragment() {
	ALBEDO = grade(COLOR.rgb * v_light, SCREEN_UV);
}
