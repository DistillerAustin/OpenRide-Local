// A beat ring (Cadence Karaoke, #42): a rectangular neon frame that flies down the tunnel, one per
// beat. The mesh is the frame itself (CadenceWorld.frame_mesh: thin mitred strips, UV.y 0-1
// across the strip, UV.x the metres from the nearest corner), so nothing is discarded and the
// middle of the screen costs nothing: a bright core and a soft halo across the strip, a white
// glint at the corners, brightest as the ring lands on the beat line. Additive.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_add, cull_disabled, depth_draw_never;

#define CADENCE_ADDITIVE
#include "res://games/cadence_karaoke/shaders/cadence_look.gdshaderinc"

uniform vec3 ring_color : source_color = vec3(0.2, 0.8, 1.0);
uniform float pulse = 0.0;  // 0-1, the beat's flare
uniform float energy = 1.0;  // the theme's brightness
uniform float line_z = -18.0;  // the beat line: a ring near it is brighter
uniform float core_width = 0.16;  // the core's half-width, as a share of the strip's half-width

varying float landing;

void vertex() {
	landing = exp(-abs(MODEL_MATRIX[3].z - line_z) * 0.25);
}

void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;  // 0 at the strip's centre, 1 at its edges
	float fw = max(fwidth(UV.y) * 2.0, 1e-4);  // one pixel, in `d`
	float wc = max(core_width, fw * 0.7);
	float core = (1.0 - smoothstep(wc - fw, wc + fw, d)) * min(core_width / wc, 1.0);
	// The halo reaches zero at the strip's edge; once the strip is a few pixels wide, its average.
	float halo = mix(exp(-d * 4.0) * (1.0 - d), 0.22, smoothstep(0.25, 0.8, fw));
	float glint = exp(-UV.x * 1.6);
	float lift = 1.0 + landing * (0.8 + pulse);
	vec3 c = ring_color * (core * (1.1 + 1.6 * pulse) + halo * (0.45 + 0.6 * pulse)) * lift;
	c += vec3(1.0) * core * glint * (0.5 + pulse);
	// Haze toward black (`haze_color` is black on this material): an additive layer fades out.
	ALBEDO = grade(haze(c * energy, length(VERTEX)), SCREEN_UV);
}
