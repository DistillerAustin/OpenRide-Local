// The orb's light on the floor (Cadence Karaoke): a pool of its state colour under it and a short
// light trail behind it toward the rider (the tunnel streams that way), longer and brighter with
// the streak. One flat quad, additive; the mesh's origin is under the orb, +z toward the rider.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_add, cull_disabled, depth_draw_never;

#define CADENCE_ADDITIVE
#include "res://games/cadence_karaoke/shaders/cadence_look.gdshaderinc"

uniform vec3 state_color : source_color = vec3(0.6, 1.0, 0.5);
uniform float strength = 0.6;
uniform float trail = 0.0;  // 0-1, the streak

varying vec2 local;

void vertex() {
	local = VERTEX.xz;
}

void fragment() {
	vec2 p = local;
	float pool = exp(-(p.x * p.x * 1.6 + p.y * p.y * 2.4));
	float behind = max(p.y, 0.0);
	float len = 0.8 + 3.2 * trail;
	float tail = exp(-behind / len) * exp(-p.x * p.x * 9.0) * smoothstep(-0.2, 0.3, p.y) * (0.12 + 0.4 * trail);
	float edge = 1.0 - smoothstep(0.8, 1.0, max(abs(p.x) / 1.5, abs(p.y - 3.0) / 4.5));
	ALBEDO = grade(state_color * (pool * strength + tail) * edge, SCREEN_UV);
}
