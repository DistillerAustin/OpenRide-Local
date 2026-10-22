// The orb (Cadence Karaoke, #42), the singer: a white-hot core, its state colour (in band, near,
// out, frozen: CadenceWorld._orb_color) as a fresnel rim, and a thin dark outline in the UI's ink
// so it pops on every tunnel colour, the green of recovery included. Opaque and unshaded; the
// halo (orb_halo.gdshader) and the floor pool (orb_pool.gdshader) carry the glow.
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec3 state_color : source_color = vec3(0.6, 1.0, 0.5);
uniform float glow = 1.0;  // brighter on the beat and with the streak
uniform vec3 ink : source_color = vec3(0.071, 0.02, 0.165);  // #12052A

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 core = vec3(1.0, 0.98, 0.93) * (0.85 + 0.15 * glow);
	vec3 c = mix(core, state_color * (0.9 + 0.35 * glow), smoothstep(0.0, 0.32, rim));
	c = mix(c, ink, smoothstep(0.84, 0.93, rim));
	ALBEDO = c;
}
