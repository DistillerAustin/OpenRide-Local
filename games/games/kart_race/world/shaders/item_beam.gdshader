// The Draft Magnet's beam (#43): a tube from the puller to the kart ahead, with bright rings
// rushing along it toward the puller and a soft core. UV.y runs along the beam (0 at the
// puller); `length` is the beam's length in metres so the rings keep their spacing. Additive.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_add, depth_draw_never;

uniform vec3 color : source_color = vec3(0.35, 1.0, 0.75);
uniform float beam_length = 10.0;
uniform float strength = 1.0;

varying vec3 v_wn;
varying vec3 v_wp;

void vertex() {
	v_wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(v_wn);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wp);
	float core = pow(abs(dot(n, V)), 1.8);
	float along = UV.y * beam_length;
	float rings = smoothstep(0.75, 1.0, sin(along * 1.6 + TIME * 18.0));
	float wave = 0.5 + 0.5 * sin(along * 0.5 - TIME * 4.0 + UV.x * 6.2831 * 2.0);
	// Fade in at both ends.
	float ends = smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.85, UV.y);
	vec3 col = color * core * (0.45 + rings * 1.3 + wave * 0.35) + vec3(1.0) * rings * core * 0.6;
	ALBEDO = col * ends * strength * 1.8;
}
