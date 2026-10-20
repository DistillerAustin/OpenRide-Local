// Lily pads drifting down the river (ART_BIBLE §6): one MultiMesh of flat notched discs, carried
// along x by TIME in the vertex shader and wrapped over `span` metres (the wrap happens far off
// to the side), each turning slowly. Lit like the scenery; no per-frame script.
//   INSTANCE_CUSTOM: r = start x 0-1 along the span, g = drift speed 0-1, b = spin 0-1.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, skip_vertex_transform;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform float span = 60.0;
uniform float speed = 0.22;  // metres a second at full drift

varying vec3 v_light;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float x = fract(c.r + TIME * speed * (0.6 + 0.4 * c.g) / span) * span - span * 0.5;
	float a = TIME * (c.b - 0.5) * 0.2 + c.b * 6.2831;
	vec2 r = vec2(VERTEX.x * cos(a) - VERTEX.z * sin(a), VERTEX.x * sin(a) + VERTEX.z * cos(a)) * s;
	vec3 world = vec3(x, origin.y + VERTEX.y * s, origin.z) + vec3(r.x, 0.0, r.y);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	v_light = sun_light(vec3(0.0, 1.0, 0.0));
}

void fragment() {
	ALBEDO = grade(haze(COLOR.rgb * v_light, length(VERTEX)), SCREEN_UV);
}
