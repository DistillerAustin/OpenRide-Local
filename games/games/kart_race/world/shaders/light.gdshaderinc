// Kart Race's hand-made light (#43): a warm low sun, a sky/ground hemisphere ambient and a
// distance haze, shared by every shader in the world. Everything is `unshaded`: the engine's
// per-pixel lights and fog cost the tablet about a third of its frame (docs/GAMES.md, Dodge
// Ball), and a stylised look wants the control anyway. KartWorld sets these per material.
uniform vec3 sun_dir = vec3(0.55, 0.42, 0.72);  // towards the sun, world space
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.66);
uniform vec3 sky_color : source_color = vec3(0.56, 0.66, 0.86);
uniform vec3 ground_color : source_color = vec3(0.42, 0.40, 0.30);
uniform vec3 haze_color : source_color = vec3(0.93, 0.83, 0.72);
uniform float haze_density = 0.0028;
uniform float haze_max = 0.85;

// Value noise from a 64x64 random texture, filtered by the GPU: far cheaper on the tablet's
// PowerVR than hashing with sin() per pixel. One unit of `p` is one texel.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

float vnoise(vec2 p) {
	return texture(noise_tex, p / 64.0).r;
}

vec3 hemi(vec3 n) {
	return mix(ground_color, sky_color, n.y * 0.5 + 0.5);
}

vec3 haze(vec3 col, float dist) {
	return mix(col, haze_color, min(1.0 - exp(-haze_density * dist), haze_max));
}

// The colour grade, folded into every material (a separate full-screen pass at the tablet's
// 1080p cost about 5 fps): warm gain, lifted violet shadows, a little more saturation and
// contrast, and a soft vignette from the screen position.
const float GRADE_SAT = 1.12;
const float GRADE_CONTRAST = 1.06;
const vec3 GRADE_GAIN = vec3(1.04, 1.0, 0.95);
const vec3 GRADE_LIFT = vec3(0.02, 0.0, 0.05);
const float GRADE_VIGNETTE = 0.38;

vec3 grade(vec3 c, vec2 suv) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, GRADE_SAT);
	c = (c - 0.5) * GRADE_CONTRAST + 0.5;
	c = c * GRADE_GAIN + GRADE_LIFT * (1.0 - c);
	vec2 p = suv * 2.0 - 1.0;
	p.x *= 1.35;
	float v = smoothstep(0.7, 1.75, length(p));
	c *= 1.0 - v * GRADE_VIGNETTE;
	return mix(c, c * vec3(0.92, 0.85, 1.05), v * 0.5);
}
