// Waving flags and banners (#43): the cloth ripples along its length (UV.x, 0 at the pole) with
// a travelling wave; shading follows the wave's slope. Colour from the vertex colours (stripes
// and chequers are baked), times INSTANCE_CUSTOM.rgb for MultiMesh flags when `tint_custom`.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform float amplitude = 0.18;
uniform float wavelength = 1.6;
uniform float speed = 5.0;
uniform bool tint_custom = false;
uniform float hang = 0.0;  // 1 = hangs down (banners): ripple across instead of out

varying float v_shade;
varying vec3 v_tint;

void vertex() {
	float ph = dot(MODEL_MATRIX[3].xyz, vec3(0.37, 0.0, 0.29));
	float along = mix(UV.x, UV.y, hang);
	float w = sin(along * 6.2831 / wavelength * 1.0 - TIME * speed + ph);
	float a = amplitude * mix(along, 0.35 + 0.65 * along, hang);
	VERTEX.z += w * a;
	VERTEX.y += cos(along * 4.0 - TIME * speed * 0.7 + ph) * a * 0.25 * (1.0 - hang);
	v_shade = 0.82 + 0.22 * cos(along * 6.2831 / wavelength - TIME * speed + ph);
	v_tint = tint_custom ? INSTANCE_CUSTOM.rgb : vec3(1.0);
}

void fragment() {
	vec3 col = COLOR.rgb * v_tint * v_shade;
	ALBEDO = grade(haze(col * (sky_color * 0.5 + sun_color * 0.75), length(VERTEX)), SCREEN_UV);
}
