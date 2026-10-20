// Dodge Ball's scenery (the Kenney trees, bushes, rocks, lamps and cones; the fence, the horizon):
// lit per vertex by the shared hand light, with painted AO by height, hazed and graded per pixel
// like the road under it (ART_BIBLE.md §4). One material per surface colour, shared by every chunk
// (DodgeWorld._hand_lit), so it adds no draw calls.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

#include "res://games/dodge_ball/shaders/look.gdshaderinc"

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform bool use_vertex_color = false;  // the procedural meshes carry their colours per vertex
uniform bool glow_mask = false;  // COLOR.a marks the self-lit part (the lamp heads)
uniform float sway = 0.0;  // metres of sway per metre of height squared (foliage)
uniform float ao_height = 1.5;  // metres over which the painted AO lifts from 0.7 to 1
uniform float haze_scale = 1.0;  // the horizon hazes as if further away than it is
uniform float lamp_glow = 0.0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.78, 0.45);

varying vec3 v_light;
varying float v_glow;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float h = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - base.y;
	if (sway > 0.0) {
		// Phase from the instance's place, so a row of trees doesn't sway in step.
		float phase = base.x * 0.37 + base.z * 0.23;
		float s = sway * h * h * (sin(TIME * 1.3 + phase) + 0.4 * sin(TIME * 2.9 + phase * 1.7));
		VERTEX.x += s / max(length(MODEL_MATRIX[0].xyz), 0.001);
	}
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ao = mix(0.7, 1.0, smoothstep(0.0, ao_height, h));
	v_light = sun_light(n) * ao;
	v_glow = glow_mask ? COLOR.a : 0.0;
	if (use_vertex_color) {
		v_light *= COLOR.rgb;
	}
}

void fragment() {
	vec3 col = albedo * texture(albedo_tex, UV).rgb * v_light;
	col += lamp_color * lamp_glow * v_glow * 1.6;
	col = haze(col, length(VERTEX) * haze_scale);
	ALBEDO = grade(col, SCREEN_UV);
}
