// The piers' decks (ART_BIBLE §3-4): planks along z drawn in world space, so the near field is
// crisp at any resolution. Dark gaps, grain from one noise read stretched along the plank, a tone
// per plank from a second, staggered butt joints, nail dots at the joists, darker and wetter in
// the last 0.6 m before the water, and the bot's blob shadow. Lines fade with their screen size
// (fwidth), so nothing shimmers. Two noise reads a pixel.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform vec3 wood : source_color = vec3(0.549, 0.380, 0.220);
uniform vec3 gap_color : source_color = vec3(0.180, 0.122, 0.078);
uniform float plank_w = 0.18;
uniform float plank_len = 2.4;
uniform float joist = 0.6;
uniform float near_end = -2.6;  // the piers' ends over the water (z)
uniform float far_end = -11.0;
uniform vec4 shadow = vec4(0.0, -13.6, 0.85, 0.0);  // the bot's blob: x, z, radius, strength
uniform float lamp = 0.0;  // the far torches' warm pools on the far deck (dusk and night)
uniform vec2 torches = vec2(2.35, -11.15);  // |x| and z of the far torches

varying vec3 v_light;
varying vec3 v_wp;
varying float v_haze;

void vertex() {
	v_light = sun_light(vec3(0.0, 1.0, 0.0));
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_haze = haze_amount(length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz));
}

void fragment() {
	float u = v_wp.x / plank_w;
	float pi = floor(u);
	float fu = fract(u);
	// Per plank: a tone and an offset for its joints (one read, at the plank's texel).
	float tone = vnoise(vec2(pi * 7.0 + 0.5, 11.5));
	float along = v_wp.z / plank_len + tone * 3.7;
	float fz = fract(along);
	// Grain: stretched along the plank.
	float grain = vnoise(vec2(fu * 3.0 + pi * 13.0, v_wp.z * 1.3));
	vec3 col = wood * (0.78 + 0.36 * tone) * (0.84 + 0.3 * grain);
	// Gaps between planks, antialiased, fading out when thinner than a pixel.
	float du = fwidth(u);
	float gw = 0.045;
	float d = min(fu, 1.0 - fu);
	float gap = (1.0 - smoothstep(gw - du, gw + du, d)) * clamp(gw * 2.0 / du, 0.25, 1.0);
	// Butt joints across each plank.
	float dz = fwidth(along);
	float j = 0.012;
	float dj = min(fz, 1.0 - fz);
	gap = max(gap, (1.0 - smoothstep(j - dz, j + dz, dj)) * clamp(j * 2.0 / dz, 0.0, 1.0) * 0.8);
	// Nail dots at the joists, two per plank, gone before they'd sparkle.
	float jz = fract(v_wp.z / joist);
	vec2 nail = vec2((min(abs(fu - 0.22), abs(fu - 0.78))) * plank_w, min(jz, 1.0 - jz) * joist);
	float nd = fwidth(v_wp.z);
	float nails = (1.0 - smoothstep(0.006, 0.006 + nd, length(nail))) * (1.0 - smoothstep(0.004, 0.012, nd));
	col = mix(col, vec3(0.12, 0.11, 0.11), nails * 0.8);
	// Darker and wetter toward the water.
	float e = min(abs(v_wp.z - near_end), abs(v_wp.z - far_end));
	float wet = smoothstep(0.6, 0.0, e);
	col *= 1.0 - 0.35 * wet;
	col = mix(col, col * vec3(0.9, 0.95, 1.05), wet * 0.5);
	// The bot's blob shadow.
	float sd = length(v_wp.xz - shadow.xy) / shadow.z;
	col *= 1.0 - shadow.w * (1.0 - smoothstep(0.35, 1.0, sd));
	col = mix(col, gap_color, gap);
	float pool = exp(-length(vec2(abs(v_wp.x) - torches.x, v_wp.z - torches.y)) * 0.9);
	vec3 light = v_light + vec3(1.0, 0.6, 0.3) * pool * lamp * 0.7;
	ALBEDO = grade(hazed(col * light, v_haze), SCREEN_UV);
}
