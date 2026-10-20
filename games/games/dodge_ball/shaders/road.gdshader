// Dodge Ball's road: asphalt grain, lane lines and kerbs, scrolled by `scroll` (metres
// travelled, wrapped at 450 m, a multiple of every pattern period) so one static plane reads
// as an endless road. At night the bike's headlight and the street lamps light pools on it
// as added light, so no real lights are needed (each one is an extra pass in Compatibility).
shader_type spatial;
render_mode unshaded, fog_disabled;

// Lit and hazed by hand with the shared light (look.gdshaderinc): these planes cover most of the
// screen, and the engine's per-pixel light and fog cost the tablet about a third of its frame.
#include "res://games/dodge_ball/shaders/look.gdshaderinc"

uniform float scroll = 0.0;
uniform float road_half = 6.0;
uniform vec3 asphalt : source_color = vec3(0.16, 0.16, 0.18);
uniform vec3 line_color : source_color = vec3(0.95, 0.93, 0.85);
uniform vec3 kerb_a : source_color = vec3(0.85, 0.2, 0.18);
uniform vec3 kerb_b : source_color = vec3(0.92, 0.92, 0.92);
uniform float rider_x = 0.0;
uniform float headlight = 0.0;  // 0 by day, 1 at night
uniform float lamp_glow = 0.0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.78, 0.45);
uniform float lamp_side_x = 7.0;
uniform float lamp_spacing = 25.0;
uniform float lamp_phase = 0.0;  // where the left lamps sit along the period
uniform float pulse = 0.0;  // streak pulse on the lines, 0-1
uniform float glare = 0.15;  // the asphalt's shine towards a low sun

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 flat_light() {
	return hemi(vec3(0.0, 1.0, 0.0)) + sun_color * max(normalize(sun_dir).y, 0.12);
}

void fragment() {
	float x = world_pos.x;
	// Road-space z: fixed to the road surface as it moves past.
	float z = world_pos.z - scroll;
	float ax = abs(x);
	float fw = 0.03;
	float dist = length(VERTEX);
	// Grain at three scales (the only three noise reads): a fine grit that fades out with
	// distance (so the near metres have texture and the far road doesn't shimmer), the coarse
	// aggregate, and broad wear.
	float fine = vnoise(vec2(x, z) * 9.0);
	float mid = vnoise(vec2(x, z) * 3.0);
	float broad = vnoise(vec2(x * 0.3, z * 0.05));
	float near = 1.0 - smoothstep(4.0, 22.0, dist);
	vec3 col = asphalt * (0.9 + 0.2 * mid + (fine - 0.5) * 0.22 * near) * (0.92 + 0.16 * broad);
	// The rubbered line: a darker band down each wheel track (two a lane, lanes at ±3 m).
	float lane = abs(ax - 3.0);
	col *= 1.0 - 0.15 * smoothstep(0.42, 0.12, abs(lane - 0.8));
	// Grime 0.4 m inside each edge line.
	col *= 1.0 - 0.12 * smoothstep(0.35, 0.05, abs(ax - (road_half - 0.85)));
	// Repair patches, one every 45 m in a lane picked per cell (the cell wraps with the scroll).
	float cell = mod(floor(z / 45.0), 10.0);
	float pick = fract(cell * 0.618);
	float zc = mod(z, 45.0) - 12.0 - pick * 18.0;
	float px = abs(x - (pick < 0.5 ? -3.0 : 3.0) - (pick - 0.5) * 1.2);
	float plen = 0.9 + pick * 1.6;
	float patch = smoothstep(0.04, 0.0, abs(zc) - plen) * smoothstep(0.04, 0.0, px - 0.75);
	col = mix(col, asphalt * vec3(0.84, 0.86, 0.9) * (0.96 + 0.08 * fine), patch * step(0.25, pick));
	// Centre dashes: 3 m on, 6 m off. Edge lines: solid.
	float dash = step(fract(z / 9.0), 0.333);
	float centre = smoothstep(0.08 + fw, 0.08, ax) * dash;
	float edge = smoothstep(0.07 + fw, 0.07, abs(ax - (road_half - 0.45)));
	vec3 lines = line_color * (0.92 + 0.08 * mid) * (1.0 + pulse * 0.8);
	col = mix(col, lines, max(centre, edge));
	// Kerbs: alternating 1 m blocks.
	float kerb = step(road_half - 0.25, ax);
	vec3 kc = mix(kerb_a, kerb_b, step(0.5, fract(z / 2.0)));
	col = mix(col, kc, kerb);

	vec3 lit = col * flat_light();
	// The sun's glare on the asphalt (toward a low sun at dawn and dusk), broken by the grain.
	vec3 view = normalize(CAMERA_POSITION_WORLD - world_pos);
	float shine = pow(max(dot(reflect(-view, vec3(0.0, 1.0, 0.0)), normalize(sun_dir)), 0.0), 8.0);
	lit += sun_color * shine * glare * (0.55 + 0.6 * mid + 0.25 * fine * near) * (1.0 - kerb);

	// Night lighting, added on top.
	vec3 glow = vec3(0.0);
	if (headlight > 0.0) {
		float d = length(vec2((x - rider_x) * 1.6, (world_pos.z + 9.0) * 0.18));
		float beam = headlight * exp(-d * d * 0.9);
		glow += vec3(0.95, 0.95, 0.85) * 0.5 * beam * col * 1.8;
		// Cat's eyes on the centre line, midway between the dashes: bright where the beam
		// reaches them, a faint glint further out.
		float ce = smoothstep(1.0, 0.5, length(vec2(x / 0.07, (fract(z / 9.0 - 0.1667) - 0.5) * 9.0 / 0.11)));
		glow += vec3(1.0, 0.92, 0.7) * ce * headlight * (0.25 + 2.5 * exp(-d * d * 0.25));
	}
	if (lamp_glow > 0.0) {
		float zl = mod(z - lamp_phase, lamp_spacing);
		float zr = mod(z - lamp_phase - lamp_spacing * 0.5, lamp_spacing);
		zl = min(zl, lamp_spacing - zl);
		zr = min(zr, lamp_spacing - zr);
		float l = exp(-(pow(x + lamp_side_x - 2.2, 2.0) * 0.12 + zl * zl * 0.035));
		float r = exp(-(pow(x - lamp_side_x + 2.2, 2.0) * 0.12 + zr * zr * 0.035));
		glow += lamp_color * lamp_glow * (l + r) * (col * 2.5 + 0.04);
	}
	ALBEDO = grade(haze(lit + glow, dist), SCREEN_UV);
}
