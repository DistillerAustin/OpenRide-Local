// Track furniture painted over the road (#43): boost pads and item rows, one mesh of quads a
// few centimetres above the tarmac. UV.x runs across a quad (0-1), UV.y along it in the driving
// direction (0-1); COLOR.r picks the kind (0 = boost pad, 1 = item row), COLOR.g the quad's
// length in metres. Pads glow with chevrons racing forward; item rows are a rainbow band of
// diamonds under the pods. Unlit (they glow); hazed and graded like the rest of the world.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform vec3 pad_base : source_color = vec3(0.10, 0.12, 0.30);
uniform vec3 pad_glow : source_color = vec3(0.20, 0.95, 1.0);
uniform vec3 pad_chevron : source_color = vec3(1.0, 0.86, 0.2);

vec3 rainbow(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	float len = max(COLOR.g * 20.0, 0.5);
	vec3 col;
	if (COLOR.r < 0.5) {
		// Boost pad: a dark plate with a glowing rim and chevrons running forward.
		float rim = max(smoothstep(0.1, 0.0, min(uv.x, 1.0 - uv.x)), smoothstep(0.6 / len, 0.0, min(uv.y, 1.0 - uv.y)));
		float v = fract(uv.y * len / 1.6 - abs(uv.x - 0.5) * 0.9 - TIME * 2.2);
		float chev = smoothstep(0.0, 0.08, v) * smoothstep(0.5, 0.42, v);
		col = mix(pad_base, pad_glow, rim * 0.9);
		col = mix(col, pad_chevron * (1.1 + 0.3 * sin(TIME * 9.0)), chev * (1.0 - rim) * 0.95);
	} else {
		// Item row: a band of diamonds in shifting rainbow colours on a dark stripe.
		float x = uv.x * 9.0;
		vec2 f = vec2(fract(x) - 0.5, (uv.y - 0.5) * len / 2.2);
		float dia = smoothstep(0.42, 0.36, abs(f.x) + abs(f.y));
		col = mix(vec3(0.12, 0.12, 0.2), rainbow(floor(x) / 9.0 + TIME * 0.25) * 1.15, dia);
	}
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
}
