// Soft round shadows (MultiMeshes of flat quads): under the balls, where INSTANCE_CUSTOM.r is the
// darkness (0-1) and they show how far away and how high a ball is; and the painted contact
// discs under the scenery, at a fixed `darkness`. Cheaper than real-time shadows. They fade with
// the haze, so a far disc never reads darker than the hazed ground around it.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://games/dodge_ball/shaders/look.gdshaderinc"

uniform float darkness = -1.0;  // below 0: per instance, from INSTANCE_CUSTOM.r
uniform float core = 0.2;  // where the falloff starts (0 centre, 1 the rim)
uniform float strength = 0.55;

varying float dark;

void vertex() {
	dark = darkness < 0.0 ? INSTANCE_CUSTOM.r : darkness;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float fog = min(1.0 - exp(-haze_density * length(VERTEX)), haze_max);
	// Navy, not black: the shadows lean to the UI's ink like the grade's lift.
	ALBEDO = vec3(0.0, 0.01, 0.03);
	ALPHA = smoothstep(1.0, core, d) * strength * dark * (1.0 - fog);
}
