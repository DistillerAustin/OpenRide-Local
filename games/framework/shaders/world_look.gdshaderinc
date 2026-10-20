// The 3D games' shared hand-made light, haze and grade (Dodge Ball, Tug of War, Cadence Karaoke;
// generalised from Kart Race's light.gdshaderinc, which stays Kart's own). Every world surface is
// `unshaded, fog_disabled` and lights itself with these: the engine's per-pixel light and fog cost
// the tablet about a third of its frame, and a full-screen grade pass about 5 fps, so the grade is
// folded into each material instead (docs/GAMES.md, Dodge Ball and Kart Race → On the tablet).
// `WorldLook.apply` sets the uniforms on a game's materials in one call.
//
// Each game keeps its own grade: define any of these BEFORE the #include (defaults: no grade).
//   LOOK_SAT            saturation multiplier, e.g. 1.1
//   LOOK_CONTRAST       contrast about mid-grey, e.g. 1.05
//   LOOK_GAIN           vec3 colour gain, e.g. vec3(1.03, 1.0, 0.96)
//   LOOK_LIFT           vec3 lift of the shadows, e.g. vec3(0.01, 0.0, 0.03)
//   LOOK_VIGNETTE       0-1 darkening at the corners (off unless defined)
//   LOOK_VIGNETTE_TINT  vec3 colour the corners lean to, e.g. vec3(0.9, 0.85, 1.05)
// The sky shader repeats the same grade without the vignette (pass SCREEN_UV = vec2(0.5)).

#ifndef LOOK_SAT
#define LOOK_SAT 1.0
#endif
#ifndef LOOK_CONTRAST
#define LOOK_CONTRAST 1.0
#endif
#ifndef LOOK_GAIN
#define LOOK_GAIN vec3(1.0)
#endif
#ifndef LOOK_LIFT
#define LOOK_LIFT vec3(0.0)
#endif
#ifndef LOOK_VIGNETTE_TINT
#define LOOK_VIGNETTE_TINT vec3(1.0)
#endif

uniform vec3 sun_dir = vec3(0.0, 0.77, -0.64);  // towards the sun, world space (WorldLook.sun_dir)
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.88);
uniform vec3 sky_color : source_color = vec3(0.6, 0.7, 0.85);  // ambient from above
uniform vec3 ground_color : source_color = vec3(0.35, 0.33, 0.28);  // ambient from below
uniform vec3 haze_color : source_color = vec3(0.75, 0.85, 0.95);
uniform float haze_density = 0.006;
uniform float haze_max = 0.9;

// Value noise from a 64x64 random texture (WorldLook.noise_texture), filtered by the GPU: far
// cheaper on the tablet's PowerVR than hashing with sin() per pixel. One unit of `p` is one
// texel. Keep to three reads a pixel on surfaces that fill the screen.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

float vnoise(vec2 p) {
	return texture(noise_tex, p / 64.0).r;
}

// Hemisphere ambient: ground → sky by the normal's height.
vec3 hemi(vec3 n) {
	return mix(ground_color, sky_color, n.y * 0.5 + 0.5);
}

// Ambient plus a Lambert sun. Call it in vertex() for scenery (per-vertex light) and pass it on
// in a varying; per pixel only on the few surfaces that need it.
vec3 sun_light(vec3 n) {
	return hemi(n) + sun_color * max(dot(n, normalize(sun_dir)), 0.0);
}

// Exponential distance haze towards `haze_color`, capped so far shapes keep a silhouette.
vec3 haze(vec3 col, float dist) {
	return mix(col, haze_color, min(1.0 - exp(-haze_density * dist), haze_max));
}

// The game's grade (the LOOK_* defines) and its vignette from the screen position.
vec3 grade(vec3 c, vec2 suv) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, LOOK_SAT);
	c = (c - 0.5) * LOOK_CONTRAST + 0.5;
	c = c * LOOK_GAIN + LOOK_LIFT * (1.0 - c);
#ifdef LOOK_VIGNETTE
	vec2 p = suv * 2.0 - 1.0;
	p.x *= 1.35;
	float v = smoothstep(0.7, 1.75, length(p));
	c *= 1.0 - v * LOOK_VIGNETTE;
	c = mix(c, c * LOOK_VIGNETTE_TINT, v * 0.5);
#endif
	return max(c, vec3(0.0));
}
