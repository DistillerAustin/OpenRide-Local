// A racer's round portrait (#43): the rendered head over a radial backdrop in the kart's
// colour, clipped to a circle with a ring (gold for the rider).
shader_type canvas_item;

uniform vec4 backdrop : source_color = vec4(0.9, 0.4, 0.2, 1.0);
uniform vec4 ring : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float ring_width = 0.09;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = fwidth(r) * 1.5;
	vec4 head = texture(TEXTURE, UV);
	vec3 bg = mix(backdrop.rgb * 1.25, backdrop.rgb * 0.55, smoothstep(0.0, 1.0, r + p.y * 0.3));
	vec3 col = mix(bg, head.rgb, head.a);
	float inner = 1.0 - ring_width;
	col = mix(col, ring.rgb, smoothstep(inner - aa, inner, r));
	col = mix(col, vec3(0.12, 0.06, 0.24), smoothstep(1.0 - aa * 2.0 - 0.03, 1.0 - 0.03, r));
	COLOR = vec4(col, (1.0 - smoothstep(1.0 - aa, 1.0, r)) * COLOR.a);
}
