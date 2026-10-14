// A vertical gradient fill for display text (#43): the glyphs' fill (white in the font colour)
// becomes top → bottom over the label's height; the dark outline and shadow stay as they are.
shader_type canvas_item;

uniform vec4 top : source_color = vec4(1.0, 0.97, 0.6, 1.0);
uniform vec4 bottom : source_color = vec4(1.0, 0.55, 0.1, 1.0);
uniform float height = 0.0;  // 0: use the label's local y over `span`
uniform vec2 span = vec2(0.0, 200.0);  // local y of the top and bottom

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.333));
	float t = clamp((local.y - span.x) / max(span.y - span.x, 1.0), 0.0, 1.0);
	vec3 g = mix(top.rgb, bottom.rgb, t);
	// A thin glossy highlight band near the top.
	g += vec3(0.25) * smoothstep(0.12, 0.0, abs(t - 0.22)) ;
	COLOR = vec4(mix(c.rgb, g, smoothstep(0.55, 0.9, lum)), c.a);
}
