// The grandstand crowd (#43): one MultiMesh of upright quads that face the camera about the
// vertical axis, cut out of a generated sprite (R = shirt, G = head, B = raised arms). Each fan
// bobs and cheers on its own phase. INSTANCE_CUSTOM: rgb = shirt colour, a = phase 0-1.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, skip_vertex_transform;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform sampler2D sprite : filter_linear_mipmap, source_color;
uniform float excite = 1.0;

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	float ph = INSTANCE_CUSTOM.a * 6.2831;
	float rate = 5.0 + INSTANCE_CUSTOM.a * 3.0;
	float hop = max(sin(TIME * rate + ph), 0.0);
	// Y-axis billboard: keep the instance's up, turn its right toward the camera.
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	vec3 right = normalize(vec3(to_cam.z, 0.0, -to_cam.x));
	float scale = length(MODEL_MATRIX[1].xyz);
	vec3 world = origin + right * VERTEX.x * scale + vec3(0.0, 1.0, 0.0) * (VERTEX.y * scale + hop * 0.14 * excite);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
}

void fragment() {
	vec4 t = texture(sprite, UV);
	if (t.a < 0.5) {
		discard;
	}
	vec3 shirt = v_custom.rgb;
	vec3 skin = mix(vec3(0.98, 0.78, 0.62), vec3(0.55, 0.36, 0.24), fract(v_custom.a * 7.3));
	vec3 col = shirt * t.r + skin * t.g + mix(shirt, skin, 0.5) * t.b;
	col *= 0.75 + 0.3 * (1.0 - UV.y);
	vec3 lit = col * (sky_color * 0.55 + sun_color * 0.7);
	ALBEDO = haze(lit, length(VERTEX));
}
