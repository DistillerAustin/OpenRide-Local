// Ribbon trails behind pucks and drones (#43): vertex colours carry the fade (alpha) along the
// ribbon; UV.x runs across it, so the edges soften. Additive.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_add, depth_draw_never;

void fragment() {
	float edge = 1.0 - pow(abs(UV.x * 2.0 - 1.0), 2.0);
	ALBEDO = COLOR.rgb * COLOR.a * edge;
}
