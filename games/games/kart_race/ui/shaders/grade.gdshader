// The one full-screen pass (#43): the 3D view, scaled up from the SubViewport, gets a colour
// grade (warm gain, lifted shadows, a little more saturation and contrast), a soft vignette and,
// at speed, radial speed lines. It replaces the plain blit, so it costs only its ALU.
shader_type canvas_item;

uniform float saturation = 1.12;
uniform float contrast = 1.06;
uniform vec3 gain = vec3(1.04, 1.0, 0.95);
uniform vec3 lift = vec3(0.02, 0.0, 0.05);
uniform float vignette = 0.38;
uniform float speed_lines = 0.0;  // 0-1
uniform float flash = 0.0;  // boost flash at the edges
uniform sampler2D noise_tex : repeat_enable, filter_linear;

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c = c * gain + lift * (1.0 - c);
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.35;
	float r = length(p);
	float v = smoothstep(0.7, 1.75, r);
	c *= 1.0 - v * vignette;
	c = mix(c, c * vec3(0.92, 0.85, 1.05), v * 0.5);
	if (speed_lines > 0.0) {
		float ang = atan(p.y, p.x) / 6.2831;
		float n = texture(noise_tex, vec2(ang * 9.0, TIME * 1.7)).r;
		float n2 = texture(noise_tex, vec2(ang * 23.0 + 0.5, TIME * 2.3)).r;
		float streak = smoothstep(0.72, 0.9, n * 0.6 + n2 * 0.4) * smoothstep(0.62, 1.25, r);
		c = mix(c, vec3(1.0, 0.98, 0.92), streak * speed_lines * 0.6);
	}
	c += vec3(1.0, 0.7, 0.3) * flash * smoothstep(0.8, 1.6, r) * 0.6;
	COLOR = vec4(c, 1.0);
}
