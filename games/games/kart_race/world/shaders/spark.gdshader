// The additive spark pool (#43, KartFx): drift sparks, flames, contact and hit sparks, drawn as
// streaks stretched along their velocity. KartFx writes each instance's velocity into its
// transform's first basis column (the slots a uniform scale left at zero) and its size into the
// second, so the stretch costs no extra GDScript. Facing the camera: the quad lies in view space
// along the velocity's screen direction, its head at the particle, its tail trailing back.
// Procedural shape, no texture: a white-hot core blending to the instance colour; a still
// instance (the drift's wheel glow) is a hard-edged four-point flare instead.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, skip_vertex_transform;

uniform float exposure = 0.06;  // seconds of travel in a streak's length
uniform float streak_width = 0.5;  // a moving streak's width, against its size

varying float v_streak;

void vertex() {
	vec3 vel = MODEL_MATRIX[0].xyz;
	float size = length(MODEL_MATRIX[1].xyz);
	vec3 origin = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	vec2 v = (VIEW_MATRIX * vec4(vel, 0.0)).xy;
	float speed = length(v);
	vec2 dir = speed > 0.001 ? v / speed : vec2(0.0, 1.0);
	vec2 side = vec2(-dir.y, dir.x);
	float trail = speed * exposure;
	v_streak = clamp(trail / max(size * 0.5, 0.001), 0.0, 1.0);
	float len = size + trail;
	float wid = size * mix(1.0, streak_width, v_streak);
	vec2 off = dir * (VERTEX.x * len - trail * 0.5) + side * VERTEX.y * wid;
	VERTEX = origin + vec3(off, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 u = UV * 2.0 - 1.0;
	// The streak: an ellipse brighter at its head (+x), a hot core down its middle.
	float d = length(u);
	float head = 0.55 + 0.45 * (u.x * 0.5 + 0.5);
	float streak = (1.0 - smoothstep(0.55, 1.0, d)) * head;
	float core = 1.0 - smoothstep(0.0, 0.5, length(vec2(u.x * 0.8, u.y * 1.6)));
	// The flare: a hard round centre and two thin crossed rays.
	float ax = abs(u.x);
	float ay = abs(u.y);
	float rays = max((1.0 - smoothstep(0.04, 0.1, ay)) * (1.0 - ax), (1.0 - smoothstep(0.04, 0.1, ax)) * (1.0 - ay));
	float flare = max(1.0 - smoothstep(0.32, 0.4, d), rays) * (1.0 - smoothstep(0.85, 1.0, d));
	float a = mix(flare, streak, v_streak) * COLOR.a;
	float hot = mix(1.0 - smoothstep(0.0, 0.3, d), core, v_streak);
	ALBEDO = mix(COLOR.rgb, vec3(1.0, 0.98, 0.92), hot * 0.85);
	ALPHA = a;
}
