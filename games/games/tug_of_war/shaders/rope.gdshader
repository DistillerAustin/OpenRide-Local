// The rope (ART_BIBLE §1, §3): the lightest warm line on screen. A twisted-strand stripe from the
// segments' UV (no texture), two tones, mostly self-lit so it reads in every light. The stripe
// fades to the average tone where it would be thinner than a pixel. One MultiMesh of segments.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://games/tug_of_war/shaders/tug_look.gdshaderinc"

uniform vec3 light_tone : source_color = vec3(0.780, 0.659, 0.420);
uniform vec3 dark_tone : source_color = vec3(0.549, 0.420, 0.259);
uniform float twists = 7.0;  // strand turns per segment

varying vec3 v_light;
varying float v_along;

void vertex() {
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_light = mix(sun_light(wn), vec3(1.0), 0.6);
	v_along = UV.y + float(INSTANCE_ID);
}

void fragment() {
	float s = UV.x * 3.0 + v_along * twists;
	float tri = abs(fract(s) - 0.5) * 2.0;  // 0 at a strand's middle, 1 at the groove
	float w = fwidth(s) * 2.0;
	float stripe = smoothstep(0.55 - w, 0.55 + w, tri);
	stripe = mix(0.45, stripe, clamp(1.0 - w, 0.0, 1.0));
	vec3 col = mix(light_tone, dark_tone, stripe);
	// A soft cylinder shade so it reads round.
	col *= 0.82 + 0.25 * clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	ALBEDO = grade(haze(col * v_light, length(VERTEX)), SCREEN_UV);
}
