// Late-afternoon sky (#43): a deep blue zenith over a warm peach horizon and a low sun with a
// soft halo. The background runs this per pixel every frame, so it stays texture-free (the
// clouds are cards, KartWorld._build_clouds): cheap on the tablet's fill-rate-bound GPU.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.24, 0.45, 0.85);
uniform vec3 mid_color : source_color = vec3(0.55, 0.72, 0.95);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.84, 0.66);
uniform vec3 ground_color : source_color = vec3(0.55, 0.62, 0.42);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 sun_dir = vec3(0.55, 0.42, 0.72);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.74, 0.86);
uniform float clouds = 0.6;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

float vnoise(vec2 p) {
	return texture(noise_tex, p / 64.0).r;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 L = normalize(sun_dir);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.25, h));
	col = mix(col, top_color, smoothstep(0.2, 0.85, h));
	float s = max(dot(dir, L), 0.0);
	// Warmer towards the sun, along the horizon.
	col = mix(col, horizon_color * 1.05, pow(s, 3.0) * smoothstep(0.5, 0.0, h) * 0.6);
	col += sun_color * pow(s, 24.0) * 0.55 + sun_color * pow(s, 6.0) * 0.18;
	col = mix(col, vec3(1.0, 0.98, 0.9), smoothstep(0.9985, 0.9993, s));
	if (h > 0.0 && clouds > 1.0) {
		vec2 uv = dir.xz / (h + 0.12) * 1.1;
		float n = vnoise(uv * 1.4) * 0.55 + vnoise(uv * 3.3 + 9.0) * 0.3 + vnoise(uv * 8.0) * 0.15;
		float c = smoothstep(0.52, 0.72, n) * smoothstep(0.0, 0.12, h) * smoothstep(0.75, 0.3, h) * clouds;
		float lit = smoothstep(0.5, 0.8, n + dot(dir.xz, L.xz) * 0.15);
		vec3 cc = mix(cloud_shade, cloud_lit, lit);
		cc += sun_color * pow(s, 8.0) * 0.4;
		col = mix(col, cc, c);
	}
	col = mix(col, ground_color, smoothstep(0.0, -0.06, h));
	// The world's colour grade (light.gdshaderinc), minus the vignette.
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 1.12);
	col = (col - 0.5) * 1.06 + 0.5;
	COLOR = col * vec3(1.04, 1.0, 0.95) + vec3(0.02, 0.0, 0.05) * (1.0 - col);
}
