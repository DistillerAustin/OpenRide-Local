// The grandstand crowd (#43): one MultiMesh of upright quads that face the camera about the
// vertical axis, cut out of a generated two-frame sprite (R = shirt, G = head, B = arms; the left
// half has the arms up, the right half out to the sides). Each fan bobs on its own phase; wavers
// flap their arms between the two frames, and a slow stadium wave runs along the stand raising
// everyone's arms as it passes. All of it from TIME and the instance data: no per-frame script.
//   COLOR (the instance colour): the shirt.
//   INSTANCE_CUSTOM: r = height (scale), g = phase 0-1, b = skin tone 0-1, a = the fan's place
//   along the stand 0-1 (the stadium wave) + 2 for a waver.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, skip_vertex_transform;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform sampler2D sprite : filter_linear_mipmap, source_color;
uniform float excite = 1.0;
uniform float wave_speed = 0.35;  // stand lengths per second

varying vec3 v_shirt;
varying vec2 v_info;  // x: skin, y: the arm frame's UV offset (0 or 0.5)

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	v_shirt = COLOR.rgb;
	float ph = c.g * 6.2831;
	float along = fract(c.a);
	float waver = step(1.5, c.a);
	// The stadium wave: a crest travelling along the stand.
	float crest = smoothstep(0.82, 1.0, sin((along - TIME * wave_speed) * 6.2831 * 1.5)) * excite;
	float rate = 5.0 + c.g * 3.0;
	float hop = max(sin(TIME * rate + ph), 0.0) * (0.6 + 0.4 * crest) + crest * 0.8;
	// Two-frame arm wave for wavers (about 2.5 flaps a second); arms up while the crest passes.
	float flap = step(0.5, fract(TIME * (2.2 + c.g) + c.g)) * waver;
	float frame = mix(flap, 0.0, step(0.3, crest));
	v_info = vec2(c.b, frame * 0.5);
	// Y-axis billboard: keep the instance's up, turn its right toward the camera.
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	vec3 right = normalize(vec3(to_cam.z, 0.0, -to_cam.x));
	float scale = length(MODEL_MATRIX[1].xyz);
	float tall = scale * c.r;
	vec3 world = origin + right * VERTEX.x * scale + vec3(0.0, 1.0, 0.0) * (VERTEX.y * tall + hop * 0.14 * excite);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
}

void fragment() {
	vec4 t = texture(sprite, vec2(UV.x * 0.5 + v_info.y, UV.y));
	if (t.a < 0.5) {
		discard;
	}
	vec3 skin = mix(vec3(0.98, 0.78, 0.62), vec3(0.45, 0.29, 0.2), v_info.x);
	vec3 col = v_shirt * t.r + skin * t.g + mix(v_shirt, skin, 0.6) * t.b;
	col *= 0.75 + 0.3 * (1.0 - UV.y);
	vec3 lit = col * (sky_color * 0.55 + sun_color * 0.7);
	ALBEDO = grade(haze(lit, length(VERTEX)), SCREEN_UV);
}
