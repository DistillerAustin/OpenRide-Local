// Bursts and sparks (one pooled MultiMesh of quads, DodgeWorld.burst): each instance is written
// once and moved here, so nothing simulates on the main thread. Per instance:
//   origin (the transform's origin)        where it started
//   basis column 0                         its velocity, m/s
//   basis column 1 (gravity, life, size)   m/s² on y, seconds, metres
//   basis column 2 (kind, seed)            0 a streak stretched along its motion, 1 a tumbling chunk
//   INSTANCE_CUSTOM.r                      its birth, on the `now` clock (DodgeWorld's _anim_t)
//   COLOR                                  its colour
// pos = origin + v·t + ½·g·t². Streaks add light (the ball's colour, cyan or gold); chunks are
// solid bits of the ball. Premultiplied alpha does both in one draw call. A dead instance
// collapses behind the camera.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, skip_vertex_transform;

uniform float now = 0.0;

varying vec4 v_color;
varying float v_fade;
varying float v_kind;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 p1 = MODEL_MATRIX[1].xyz;
	vec3 p2 = MODEL_MATRIX[2].xyz;
	float t = now - INSTANCE_CUSTOM.r;
	float k = t / max(p1.y, 0.001);
	vec3 g = vec3(0.0, p1.x, 0.0);
	vec3 pos = origin + v0 * t + 0.5 * g * t * t;
	vec3 vel = (VIEW_MATRIX * vec4(v0 + g * t, 0.0)).xyz;
	vec3 c = (VIEW_MATRIX * vec4(pos, 1.0)).xyz;
	float size = p1.z * (1.0 - 0.45 * k);
	vec2 along = length(vel.xy) > 0.001 ? normalize(vel.xy) : vec2(0.0, 1.0);
	vec2 extent;
	vec2 offset = VERTEX.xy;
	if (p2.x < 0.5) {
		// A streak: its head at the particle, its tail trailing back along its motion.
		extent = vec2(size * 0.35, size + length(vel.xy) * 0.04);
		offset.y -= 0.5;
	} else {
		float a = t * (7.0 + p2.y * 9.0) + p2.y * 6.283;
		along = vec2(cos(a), sin(a));
		extent = vec2(size * (0.7 + 0.3 * p2.y), size);
	}
	vec2 across = vec2(along.y, -along.x);
	VERTEX = c + vec3(across * offset.x * extent.x + along * offset.y * extent.y, 0.0);
	bool alive = t >= 0.0 && k < 1.0;
	if (!alive) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_color = COLOR;
	v_fade = alive ? 1.0 - k : 0.0;
	v_kind = p2.x;
}

void fragment() {
	if (v_kind < 0.5) {
		float across = 1.0 - abs(UV.x * 2.0 - 1.0);
		float a = smoothstep(0.0, 0.7, across) * pow(1.0 - UV.y, 1.5) * v_fade;
		ALBEDO = v_color.rgb * a * 1.8;
		ALPHA = 0.0;
	} else {
		float a = smoothstep(0.0, 0.25, v_fade);
		ALBEDO = v_color.rgb * (0.7 + 0.3 * (1.0 - UV.y)) * a;
		ALPHA = a;
	}
}
