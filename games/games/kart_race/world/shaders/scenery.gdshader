// Static scenery (#43): trees, stands, gate, fences, windmill, props. Lit per vertex by hand
// (sun + hemisphere ambient, painted AO in the vertex colours), hazed per pixel. COLOR.a is a
// sway weight: foliage and flags bend in the wind (`sway` metres at weight 1); with
// `alpha_glow` it is instead how much the vertex glows (lit windows, bulbs, signs).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform float sway = 0.0;
uniform float sway_speed = 1.4;
uniform bool tint_custom = false;  // multiply by the instance's custom data (MultiMesh)
uniform float emission = 0.0;  // 1 = ignore the light (lamps, signs)
uniform bool alpha_glow = false;  // COLOR.a = emission (not sway)

varying vec3 v_light;
varying vec3 v_tint;

void vertex() {
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (sway > 0.0) {
		// Phase from the vertex's world position: baked sectors share one origin.
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float ph = dot(wp, vec3(0.071, 0.0, 0.053));
		float w = COLOR.a * COLOR.a;
		VERTEX.x += sin(TIME * sway_speed + ph) * sway * w;
		VERTEX.z += sin(TIME * sway_speed * 0.77 + ph * 1.7) * sway * w * 0.6;
	}
	float ndl = max(dot(wn, normalize(sun_dir)), 0.0);
	float glow = alpha_glow ? COLOR.a : 0.0;
	v_light = mix(hemi(wn) + sun_color * ndl, vec3(1.25), max(emission, glow));
	v_tint = tint_custom ? INSTANCE_CUSTOM.rgb : vec3(1.0);
}

void fragment() {
	ALBEDO = grade(haze(COLOR.rgb * v_tint * v_light, length(VERTEX)), SCREEN_UV);
}
