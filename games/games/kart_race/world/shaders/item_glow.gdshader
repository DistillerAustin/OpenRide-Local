// Glowing item parts (#43): pod cores, the puck's rim, the drone's lights, shield sparks. A hot
// centre fading to a saturated edge (fresnel), pulsing. Colour from the material, or per
// instance from INSTANCE_CUSTOM (r = hue, g = pop, b = brightness) when `per_instance` is set.
// Additive: glows read on the tablet without a bloom pass.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, blend_add, depth_draw_never;

uniform vec3 color : source_color = vec3(1.0, 0.6, 0.2);
uniform float strength = 1.0;
uniform float pulse = 0.25;
uniform float pulse_hz = 2.0;
uniform bool per_instance = false;

varying vec3 v_wn;
varying vec3 v_wp;
varying vec4 v_custom;

vec3 hue_rgb(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void vertex() {
	v_wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_custom = per_instance ? INSTANCE_CUSTOM : vec4(0.0, 0.0, 1.0, 0.0);
}

void fragment() {
	vec3 n = normalize(v_wn);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wp);
	float facing = abs(dot(n, V));
	vec3 base = per_instance ? mix(hue_rgb(v_custom.r), vec3(1.0), 0.15) : color;
	float p = 1.0 + pulse * sin(TIME * 6.2831 * pulse_hz + v_wp.x * 0.7 + v_wp.z * 0.5);
	vec3 col = mix(base, vec3(1.0, 0.98, 0.92), pow(facing, 3.0) * 0.85) * strength * p;
	col *= mix(0.55, 1.0, facing) * v_custom.b;
	col += vec3(v_custom.g);
	ALBEDO = col;
}
