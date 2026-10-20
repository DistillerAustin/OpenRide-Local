// The wind-up tin robot (ART_BIBLE §4-5): matte painted tin lit per vertex by hand, a soft fake
// highlight band from the view (pow(1 - N.V, 2)), painted AO in the vertex colours, and warm
// light from the far torches so it reads at night. Vertex data (TugMeshes.bot_body):
//   UV.x = 1 takes `body_color` (set per rung: no new material), UV.y = 1 is the wind-up key,
//   turned by `key_angle` about z through `key_pivot` (the world winds it per state).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform vec3 body_color : source_color = vec3(0.68, 0.32, 0.16);
uniform float key_angle = 0.0;
uniform vec2 key_pivot = vec2(0.0, 1.12);
uniform float torch_fill = 0.0;  // 0-1: the torches' warm light on the bot's front

varying vec3 v_light;
varying vec3 v_tint;

void vertex() {
	if (UV.y > 0.5) {
		float c = cos(key_angle);
		float s = sin(key_angle);
		vec2 p = VERTEX.xy - key_pivot;
		VERTEX.xy = key_pivot + vec2(p.x * c - p.y * s, p.x * s + p.y * c);
		NORMAL.xy = vec2(NORMAL.x * c - NORMAL.y * s, NORMAL.x * s + NORMAL.y * c);
	}
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 torch = vec3(1.0, 0.62, 0.32) * torch_fill * (0.35 + 0.65 * max(wn.z, 0.0)) * 0.55;
	v_light = sun_light(wn) + torch;
	v_tint = mix(vec3(1.0), body_color, UV.x);
}

void fragment() {
	vec3 col = COLOR.rgb * v_tint * v_light;
	float band = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 2.0);
	col += band * 0.28 * (sky_color + sun_color * 0.35) * (0.4 + 0.6 * COLOR.rgb);
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
}
