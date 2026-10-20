// The riverside crowd (ART_BIBLE §5): one MultiMesh of upright quads that face the camera about
// the vertical axis, cut from a generated two-frame sprite (TugMeshes.crowd_sprite: R = shirt,
// G = skin, B = trousers, black = hair; arms down, then arms up), each with a blob shadow on the
// ground (the flat quad, NORMAL.y = 1). Fans bob on their own phase and throw their arms up more
// often as `excite` rises. All from TIME and the instance data: no per-frame script.
//   COLOR (the instance colour): the shirt.
//   INSTANCE_CUSTOM: r = height, g = phase 0-1, b = skin tone 0-1, a = trousers tone 0-1.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, skip_vertex_transform;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform sampler2D sprite : filter_linear_mipmap, source_color;
uniform float excite = 0.2;
uniform vec3 ground_tint : source_color = vec3(0.302, 0.502, 0.2);

varying vec3 v_shirt;
varying vec4 v_info;  // x: skin, y: frame offset (0 or 0.5), z: 1 on the blob, w: trousers
varying vec3 v_light;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	v_shirt = COLOR.rgb;
	float ph = c.g * 6.2831;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float blob = step(0.5, NORMAL.y);
	vec3 world;
	if (blob > 0.5) {
		world = origin + VERTEX;
		v_light = sun_light(vec3(0.0, 1.0, 0.0));
	} else {
		float rate = 5.5 + c.g * 3.0;
		float hop = max(sin(TIME * rate + ph), 0.0) * (0.04 + 0.26 * excite);
		// Arms up for part of each cheer cycle, longer the more excited the crowd.
		float up = step(1.0 - (0.15 + 0.7 * excite), fract(TIME * (0.9 + c.g * 0.5) + c.g));
		vec3 to_cam = CAMERA_POSITION_WORLD - origin;
		vec3 right = normalize(vec3(to_cam.z, 0.0, -to_cam.x));
		world = origin + right * VERTEX.x * c.r + vec3(0.0, VERTEX.y * c.r + hop, 0.0);
		v_light = sky_color * 0.6 + sun_color * 0.65;
		v_info.y = up * 0.5;
	}
	v_info.x = c.b;
	v_info.z = blob;
	v_info.w = c.a;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	vec3 col;
	if (v_info.z > 0.5) {
		float r = length(UV * 2.0 - 1.0);
		if (r > 1.0) {
			discard;
		}
		col = ground_tint * mix(0.55, 1.0, smoothstep(0.2, 1.0, r));
	} else {
		vec4 t = texture(sprite, vec2(UV.x * 0.5 + v_info.y, UV.y));
		if (t.a < 0.5) {
			discard;
		}
		vec3 skin = mix(vec3(0.95, 0.74, 0.58), vec3(0.42, 0.27, 0.18), v_info.x);
		vec3 trousers = mix(vec3(0.12, 0.16, 0.3), vec3(0.32, 0.26, 0.2), v_info.w);
		col = v_shirt * t.r + skin * t.g + trousers * t.b + vec3(0.07, 0.05, 0.05) * (1.0 - min(t.r + t.g + t.b, 1.0));
		col *= 0.8 + 0.28 * (1.0 - UV.y);
	}
	ALBEDO = grade(haze(col * v_light, length(VERTEX)), SCREEN_UV);
}
