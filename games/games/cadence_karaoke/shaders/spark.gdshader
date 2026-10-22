// Beat-line sparks (Cadence Karaoke, in the bonus band): a pooled MultiMesh of streaks that fly
// up off the white line as a ring lands. The motion is all here: each instance's custom data is
// (birth time, x across the line 0-1, two seeds), written once per burst by CadenceWorld, and
// `now` is the world's clock. A streak is stretched along its velocity, a white-hot core blending
// to the state colour. Dead sparks collapse to a point. Additive.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform;

#define CADENCE_ADDITIVE
#include "res://games/cadence_karaoke/shaders/cadence_look.gdshaderinc"

uniform float now = 0.0;
uniform float life = 0.55;
uniform vec3 spark_color : source_color = vec3(0.45, 1.0, 0.65);
uniform vec3 origin = vec3(0.0, -3.27, -18.0);  // the beat line's top, centre
uniform float half_width = 3.6;

varying float age_t;

void vertex() {
	vec4 data = INSTANCE_CUSTOM;
	float age = now - data.x;
	age_t = age / life;
	vec3 p0 = origin + vec3((data.y * 2.0 - 1.0) * half_width, 0.0, 0.0);
	vec3 vel = vec3((data.z - 0.5) * 3.0, 3.0 + 3.0 * data.w, (data.w - 0.5) * 2.0);
	vec3 g = vec3(0.0, -9.0, 0.0);
	vec3 p = p0 + vel * age + 0.5 * g * age * age;
	vec3 v = vel + g * age;
	vec3 pv = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	vec3 vv = (VIEW_MATRIX * vec4(v, 0.0)).xyz;
	vec2 axis = normalize(vv.xy + vec2(0.0, 1e-4));
	vec2 perp = vec2(-axis.y, axis.x);
	float len = clamp(length(v) * 0.05, 0.08, 0.5);
	pv.xy += axis * VERTEX.x * len + perp * VERTEX.y * 0.05;
	float alive = step(0.0, age) * step(age_t, 1.0);
	VERTEX = pv * alive;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	float along = 1.0 - abs(UV.x - 0.5) * 2.0;
	float fade = 1.0 - smoothstep(0.4, 1.0, age_t);
	vec3 c = mix(spark_color, vec3(1.0), smoothstep(0.3, 0.9, across * along)) * across * along * fade * 1.6;
	ALBEDO = grade(c, SCREEN_UV);
}
