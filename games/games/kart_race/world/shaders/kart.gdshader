// Karts and drivers (#43): glossy toon paint, lit by hand like the rest of the world.
// - A two-tone toon ramp with a soft terminator; fur (low gloss) wraps the light further round
//   for a velvety look, and the shade side is tinted by the sky.
// - Paint (COLOR.a = gloss) gets a crisp toon highlight, a broad lacquer sheen and a clear-coat
//   reflection of the sky; rubber and fur stay matte.
// - A rim light: warm on the sun side, cool on the shade side, so karts lift off the road.
// - UV.y = self-lit (eye glints, lamps); vertex colours carry the paint and painted AO.
// Small on screen, so per pixel is cheap enough.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"
#include "res://games/kart_race/world/shaders/rig.gdshaderinc"

uniform vec3 rim_color : source_color = vec3(1.0, 0.9, 0.72);
uniform vec3 rim_cool : source_color = vec3(0.62, 0.74, 1.0);
uniform float rim = 0.5;
uniform float gloss = 1.0;
uniform float flash = 0.0;  // a white hit / boost flash

varying vec3 v_wn;
varying vec3 v_wp;
varying float v_glow;

void vertex() {
	rig(VERTEX, NORMAL, UV2);
	v_wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_glow = UV.y;
}

void fragment() {
	vec3 n = normalize(v_wn);
	vec3 L = normalize(sun_dir);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wp);
	float g = COLOR.a;
	float ndl = dot(n, L);
	float wrap = 0.3 * (1.0 - g);
	float ramp = smoothstep(-0.06 - wrap, 0.14 - wrap * 0.5, ndl);
	vec3 base = COLOR.rgb;
	// Shade: sky-tinted ambient with a touch of saturation in the core shadow; light: the sun.
	vec3 shade = hemi(n) * 0.78 * mix(vec3(0.92, 0.88, 1.06), vec3(1.0), ramp);
	vec3 col = base * (shade + sun_color * (0.18 + 0.92 * ramp));
	float nv = max(dot(n, V), 0.0);
	float fres = 1.0 - nv;
	// Gloss: a crisp toon highlight and a broad sheen, and the sky in the clear coat.
	vec3 H = normalize(L + V);
	float spec = pow(max(dot(n, H), 0.0), 32.0);
	col += sun_color * smoothstep(0.3, 0.6, spec) * 0.8 * gloss * g * ramp;
	col += sun_color * spec * 0.15 * gloss * g;
	col += mix(ground_color, sky_color, smoothstep(-0.5, 0.7, reflect(-V, n).y)) * fres * fres * 0.22 * g;
	// The rim: warm where the sun reaches, cool in the shade.
	float r = smoothstep(0.55, 0.95, fres) * rim;
	col += mix(rim_cool * 0.55, rim_color, ramp) * r * (0.5 + 0.5 * max(dot(-V, L) + 0.4, 0.0));
	col = mix(col, base * 1.08, v_glow);
	col = mix(col, vec3(1.0), flash);
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
}
