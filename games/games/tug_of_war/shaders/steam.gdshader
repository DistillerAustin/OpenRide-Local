// Steam from the bot's chimney on a telegraph and in a surge (ART_BIBLE §2, §7): a tiny pooled
// MultiMesh of soft puffs that rise, grow and fade on their own phase (INSTANCE_ID), billboarded
// here. `steam` 0-1 sets how much (0.5 telegraph puffs, 1 surge jets). Alpha, never additive.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform float steam = 0.0;
uniform float count = 4.0;

varying float v_age;

void vertex() {
	float id = float(INSTANCE_ID);
	float rate = 0.9 + steam * 0.9;
	float age = fract(TIME * rate + id / count);
	v_age = age;
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 rise = vec3(sin(id * 2.3 + TIME) * 0.12 * age, age * (0.6 + 0.9 * steam), -0.25 * age);
	float size = (0.14 + 0.42 * age) * (0.7 + 0.5 * steam);
	vec4 centre = VIEW_MATRIX * vec4(origin + rise, 1.0);
	VERTEX = centre.xyz + vec3(VERTEX.xy * size, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float soft = 1.0 - smoothstep(0.35, 1.0, r);
	float a = soft * steam * smoothstep(0.0, 0.12, v_age) * (1.0 - v_age) * 0.75;
	vec3 col = vec3(0.92) * max(sky_color + sun_color * 0.5, vec3(0.45));
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
	ALPHA = a;
}
