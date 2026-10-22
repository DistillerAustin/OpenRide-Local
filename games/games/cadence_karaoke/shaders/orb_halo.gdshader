// The orb's halo (Cadence Karaoke): a camera-facing quad, additive, in the orb's state colour. It
// starts just outside the orb's edge (`inner`, as a share of the quad's half-size) so it never
// washes over the orb's dark outline. No texture: the falloff is maths.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_add, cull_disabled, depth_draw_never;

#define CADENCE_ADDITIVE
#include "res://games/cadence_karaoke/shaders/cadence_look.gdshaderinc"

uniform vec3 state_color : source_color = vec3(0.6, 1.0, 0.5);
uniform float strength = 0.5;
uniform float inner = 0.33;

void vertex() {
	// A billboard that keeps the node's scale (as BaseMaterial3D's BILLBOARD_ENABLED does).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float t = max(r - inner, 0.0) / max(1.0 - inner, 1e-3);
	float a = exp(-t * 3.5) * (1.0 - smoothstep(0.75, 1.0, r)) * smoothstep(inner - 0.02, inner + 0.04, r);
	ALBEDO = grade(state_color * a * strength, SCREEN_UV);
}
