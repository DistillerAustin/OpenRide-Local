// The results board's backdrop (#43): rotating rays from a point over a violet night gradient,
// fading out at the edges. On the 3D podium, `hole` clears a soft window over the stage (the
// karts on their blocks show through, lightly tinted).
shader_type canvas_item;

uniform vec2 centre = vec2(0.5, 0.3);
uniform vec4 inner : source_color = vec4(0.55, 0.35, 1.0, 1.0);
uniform vec4 outer : source_color = vec4(0.08, 0.04, 0.22, 1.0);
uniform float rays = 18.0;
uniform float alpha = 0.92;
uniform vec2 hole = vec2(0.5, 0.5);
uniform float hole_radius = 0.0; // a share of the width; 0 = no window
uniform float hole_alpha = 0.14;

void fragment() {
	vec2 p = (UV - centre) * vec2(1.78, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float ray = smoothstep(0.0, 0.08, sin(a * rays + TIME * 0.35) * 0.5 + 0.1);
	vec3 col = mix(inner.rgb, outer.rgb, smoothstep(0.0, 0.95, r));
	col += vec3(0.12, 0.08, 0.2) * ray * smoothstep(1.1, 0.1, r);
	float k = alpha;
	if (hole_radius > 0.0) {
		// An ellipse on screen (wider than tall), soft edged.
		vec2 q = (UV - hole) * vec2(1.0, 0.75);
		k = mix(hole_alpha, alpha, smoothstep(hole_radius * 0.55, hole_radius, length(q)));
	}
	COLOR = vec4(col, k);
}
