shader_type canvas_item;

// Safe Cracker's porthole (#41): sky over a slowly swelling sea with a foam line and a glint on
// the glass, masked to a circle with a soft edge. On one square ColorRect; TIME only.

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float line = 0.02 + 0.05 * sin(p.x * 2.6 + TIME * 0.5) + 0.025 * sin(p.x * 6.0 - TIME * 0.8) + 0.08 * sin(TIME * 0.22);
	vec3 sky = mix(vec3(0.62, 0.74, 0.82), vec3(0.36, 0.55, 0.72), clamp(p.y + 1.0, 0.0, 1.0));
	vec3 sea = mix(vec3(0.14, 0.38, 0.52), vec3(0.04, 0.16, 0.28), clamp(p.y - line, 0.0, 1.0));
	vec3 col = mix(sky, sea, smoothstep(line - 0.012, line + 0.012, p.y));
	col += vec3(0.5) * (1.0 - smoothstep(0.0, 0.035, abs(p.y - line))) * 0.35;
	col += vec3(0.3) * (1.0 - smoothstep(0.0, 0.55, length(p - vec2(-0.4, -0.45)))) * 0.45;
	col *= 1.0 - 0.35 * smoothstep(0.6, 1.0, r);
	COLOR = vec4(col, 1.0 - smoothstep(0.96, 1.0, r));
}
