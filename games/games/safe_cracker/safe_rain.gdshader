shader_type canvas_item;

// Safe Cracker's office window (#41): the night outside, the moon's glow, slow rain streaks
// running down (from TIME, never a redraw), the blinds' slats over the top and the mullion.
// On one ColorRect the size of the glass.

uniform vec4 sky_top : source_color = vec4(0.04, 0.07, 0.13, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.08, 0.11, 0.18, 1.0);
uniform vec4 frame : source_color = vec4(0.33, 0.37, 0.42, 1.0);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(sky_top.rgb, sky_bottom.rgb, uv.y);
	col += vec3(0.3, 0.36, 0.48) * 0.4 * exp(-length((uv - vec2(0.3, 0.5)) * vec2(1.0, 1.3)) * 5.0);
	// City lights far below.
	float row = step(0.86, uv.y) * step(hash(floor(uv.x * 40.0) + floor(uv.y * 30.0) * 7.0), 0.18);
	col += vec3(0.9, 0.75, 0.45) * row * 0.35;
	// Rain: streaks in 46 columns, each its own speed and phase.
	float cols = 46.0;
	float cx = floor(uv.x * cols);
	float h = hash(cx);
	float y = fract(uv.y * 1.4 - TIME * (0.22 + 0.18 * h) + h * 7.0);
	float streak = smoothstep(0.0, 0.03, y) * (1.0 - smoothstep(0.03, 0.12, y));
	streak *= 1.0 - smoothstep(0.05, 0.14, abs(fract(uv.x * cols) - 0.5));
	col += vec3(0.6, 0.7, 0.85) * streak * 0.4 * step(0.3, h);
	// The blinds, drawn up to a third of the way down.
	float slat = 0.55 + 0.35 * smoothstep(0.3, 0.6, fract(uv.y * 34.0));
	col = mix(col, vec3(0.52, 0.55, 0.58) * slat, step(uv.y, 0.33) * 0.95);
	col = mix(col, frame.rgb, 1.0 - smoothstep(0.012, 0.02, abs(uv.x - 0.5)));
	COLOR = vec4(col, 1.0);
}
