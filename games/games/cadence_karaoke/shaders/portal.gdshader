// The portal at the tunnel's end (Cadence Karaoke): a glowing disc in the theme's secondary with
// horizontal bands, on the haze's colour, so the tunnel has a destination. It breathes faintly on
// the beat. Opaque: it closes the tunnel at its far end, where the grid has hazed out.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://games/cadence_karaoke/shaders/cadence_look.gdshaderinc"

uniform vec3 disc_color : source_color = vec3(1.0, 0.3, 0.85);  // the secondary
uniform vec3 neon_color : source_color = vec3(0.2, 0.8, 1.0);  // the theme's neon, at the disc's foot
uniform vec2 size = vec2(15.0, 7.6);  // the quad's size, metres
uniform float radius = 2.6;
uniform float beat = 0.0;
uniform float energy = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * size;
	p.y = -p.y;  // up is +y
	p.y -= 0.4;
	float r = length(p);
	float fr = max(fwidth(r), 1e-4);
	float disc = 1.0 - smoothstep(radius - fr, radius + fr, r);
	// Bands: gaps across the disc's lower half that widen toward its foot.
	float v = clamp(-p.y / radius, 0.0, 1.0);
	float band = fract(p.y * 1.1);
	float gapw = v * 0.55;
	float fb = max(fwidth(p.y * 1.1), 1e-4);
	float bands = mix(1.0, smoothstep(gapw - fb, gapw + fb, band), step(0.02, v));
	vec3 col = mix(disc_color * 1.25, mix(disc_color, neon_color, 0.6), v);
	float pulse = 1.0 + 0.12 * beat;
	vec3 c = haze_color;
	c += col * disc * bands * pulse * energy;
	c += disc_color * exp(-max(r - radius, 0.0) * 0.55) * (1.0 - disc) * 0.45 * pulse * energy;
	ALBEDO = grade(c, SCREEN_UV);
}
