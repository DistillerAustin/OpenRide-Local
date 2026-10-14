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
