shader_type canvas_item;

// Safe Cracker's lab flasks (#41): the liquids' brightness ripples slowly across the shelf, as
// if something bubbles in them (TIME only; the shapes are drawn once).

void fragment() {
	vec4 c = COLOR * texture(TEXTURE, UV);
	float w = sin(TIME * 1.1 + FRAGCOORD.x * 0.035 + FRAGCOORD.y * 0.06);
	float bub = smoothstep(0.92, 1.0, sin(FRAGCOORD.y * 0.4 + TIME * 3.0 + FRAGCOORD.x * 0.7));
	c.rgb *= 0.9 + 0.14 * w;
	c.rgb += vec3(0.25) * bub * 0.5;
	COLOR = c;
}
