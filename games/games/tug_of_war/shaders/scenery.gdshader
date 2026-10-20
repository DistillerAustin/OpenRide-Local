// Tug of War's riverside (one baked mesh: banks, hills, trees, piers, masts, bunting, string
// lights, reeds, the tent) and the flag on the rope. Lit per vertex by hand, hazed and graded per
// pixel (tug_look.gdshaderinc). Vertex data (TugMeshes):
//   COLOR.a  1 - sway weight: reeds and bunting sway, the flag's cloth flutters (`wave`).
//   UV.x     ground grain: one noise read breaks up the banks' grass and earth.
//   UV.y     glow: the string lights' bulbs, brighter with `lamp`.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform float sway = 0.07;  // metres at full weight
uniform float sway_speed = 1.7;
uniform float wave = 0.0;  // the flag: a travelling wave along local x, in metres
uniform float lamp = 0.0;  // 0-1: the bulbs' glow (dusk and night)
uniform float self_lit = 0.0;  // 0-1: share of light that ignores the sun (the flag)

varying vec3 v_light;
varying vec2 v_ground;
varying float v_grain;

void vertex() {
	float w = 1.0 - COLOR.a;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (w > 0.0) {
		float ph = dot(wp, vec3(0.31, 0.0, 0.23));
		VERTEX.x += sin(TIME * sway_speed + ph) * sway * w;
		VERTEX.z += sin(TIME * sway_speed * 1.37 + ph * 1.7) * sway * w * 0.8;
		VERTEX.z += sin(TIME * 7.0 - VERTEX.x * 7.0) * wave * w;
		VERTEX.y += sin(TIME * 5.3 - VERTEX.x * 5.0) * wave * 0.3 * w;
	}
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_light = mix(sun_light(wn), vec3(1.0), self_lit);
	v_light = mix(v_light, vec3(0.75 + 1.1 * lamp), UV.y);
	v_ground = wp.xz;
	v_grain = UV.x;
}

void fragment() {
	vec3 col = COLOR.rgb;
	if (v_grain > 0.0) {
		float g = vnoise(v_ground * 1.6 + vec2(17.0, 3.0));
		col *= mix(1.0, 0.8 + 0.4 * g, v_grain);
	}
	ALBEDO = grade(haze(col * v_light, length(VERTEX)), SCREEN_UV);
}
