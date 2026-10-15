// The racers' round portraits from one atlas (#43): every portrait shares this material and the
// atlas texture, so the racer list draws in a single batch. The atlas is COLS x ROWS cells, one
// rendered head each; the cell (from UV) picks its racer's backdrop colour. Each portrait is a
// radial backdrop in the kart's colour under the head, clipped to a circle with a ring.
shader_type canvas_item;

const int COLS = 4;
const int ROWS = 2;
uniform vec4 backdrops[8] : source_color;
uniform vec4 ring : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float ring_width = 0.09;

void fragment() {
	vec2 grid = UV * vec2(float(COLS), float(ROWS));
	vec2 cell = min(floor(grid), vec2(float(COLS - 1), float(ROWS - 1)));
	vec2 uv = grid - cell;
	vec4 backdrop = backdrops[int(cell.y) * COLS + int(cell.x)];
	vec2 p = uv * 2.0 - 1.0;
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
