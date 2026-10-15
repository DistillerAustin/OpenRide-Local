// The road, kerbs and verges (#43), one unshaded mesh lit by hand, coloured per theme. UV is track space:
// x = d (metres across, + right), y = s (metres along from the start line). UV2.x is the road's
// half-width there. COLOR.r is the racing line (d, mapped from -10..10 m), COLOR.g how hard the
// corner is (0-1): tyre marks gather there. Everything painted is procedural: asphalt grain,
// edge lines, the chequered line, the grid boxes, kerbs, tyre marks, and verges (mown stripes,
// sand, cobbles or snow).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://games/kart_race/world/shaders/light.gdshaderinc"

uniform float track_length = 1150.0;
uniform float grid_first = 6.0;
uniform float grid_gap = 4.5;
uniform float grid_d = 2.5;
uniform int grid_slots = 8;
uniform vec3 asphalt : source_color = vec3(0.30, 0.31, 0.35);
uniform vec3 asphalt_dark : source_color = vec3(0.20, 0.21, 0.24);
uniform vec3 line_color : source_color = vec3(0.96, 0.95, 0.9);
uniform vec3 kerb_a : source_color = vec3(0.86, 0.13, 0.12);
uniform vec3 kerb_b : source_color = vec3(0.97, 0.97, 0.95);
uniform vec3 grass_a : source_color = vec3(0.36, 0.62, 0.20);
uniform vec3 grass_b : source_color = vec3(0.44, 0.70, 0.24);
uniform float verge_stripes = 0.4;  // mown stripes' contrast (0: none)
uniform vec3 verge_dust : source_color = vec3(0.42, 0.38, 0.3);
uniform float cobbles = 0.0;  // 1: the verge is a cobbled quay
uniform float kerb_width = 0.8;
uniform float light_gain = 1.0;

varying float v_hw;
varying float v_line;
varying float v_corner;

void vertex() {
	v_hw = UV2.x;
	v_line = COLOR.r * 20.0 - 10.0;
	v_corner = COLOR.g;
}

float band(float x, float c, float w) {
	float fw = fwidth(x) * 0.75 + 0.002;
	return smoothstep(w + fw, w - fw, abs(x - c));
}

void fragment() {
	float d = UV.x;
	float s = UV.y;
	float ad = abs(d);
	float hw = v_hw;
	// Signed s around the start line (the grid sits just behind it, at the end of the loop).
	float ss = s > track_length * 0.5 ? s - track_length : s;
	vec3 col;
	if (ad < hw) {
		// Asphalt: two scales of grain plus patchy repairs.
		// Three texture reads in all (the tablet is fill-rate bound): grain, patches, streaks.
		float g = vnoise(vec2(d, s) * 9.0);
		float big = vnoise(vec2(d * 0.35, s * 0.08) + 13.0);
		col = mix(asphalt, asphalt_dark, 0.35 * smoothstep(0.62, 0.7, big)) * (0.84 + 0.2 * g + 0.1 * big);
		// Rubbered-in racing line: darker where the karts run.
		float lane = smoothstep(2.4, 0.4, abs(d - v_line));
		col *= 1.0 - 0.12 * lane;
		// Tyre marks: pairs of dark streaks off the line, thicker in corners and off the grid.
		float streak = vnoise(vec2(d * 3.0, s * 0.11)) * (0.4 + big);
		float tyre = max(band(d, v_line - 0.62, 0.11), band(d, v_line + 0.62, 0.11));
		float marks = tyre * smoothstep(0.28, 0.5, streak) * (0.15 + 0.85 * v_corner);
		// Launch marks behind every grid box.
		if (ss < 0.0 && ss > -(grid_first + grid_gap * float(grid_slots)) - 3.0) {
			float launch = max(max(band(d, -grid_d - 0.55, 0.1), band(d, -grid_d + 0.55, 0.1)),
				max(band(d, grid_d - 0.55, 0.1), band(d, grid_d + 0.55, 0.1)));
			marks = max(marks, launch * smoothstep(0.15, 0.5, g) * 0.8);
		}
		col = mix(col, vec3(0.08, 0.08, 0.09), marks * 0.42);
		// Edge lines.
		col = mix(col, line_color, band(ad, hw - 0.35, 0.09));
		// The start/finish line: a chequered band 1.6 m deep.
		if (ss >= 0.0 && ss < 1.6) {
			vec2 c = floor(vec2((d + hw) / (2.0 * hw / 10.0), ss / 0.8));
			float chk = mod(c.x + c.y, 2.0);
			col = mix(vec3(0.06), vec3(0.97), chk);
		}
		// Grid boxes: a white bracket in front of each slot.
		if (ss < -grid_first + 2.0 && ss > -(grid_first + grid_gap * float(grid_slots))) {
			float slot = floor((-ss - grid_first + 2.0) / grid_gap + 0.0);
			float s0 = -(grid_first + grid_gap * slot) + 1.6;  // the box's front line
			float side = mod(slot, 2.0) < 0.5 ? -grid_d : grid_d;
			float front = band(ss, s0, 0.08) * step(abs(d - side), 1.1);
			float legs = (band(d, side - 1.1, 0.08) + band(d, side + 1.1, 0.08)) * step(ss, s0 + 0.08) * step(s0 - 2.4, ss);
			col = mix(col, line_color, clamp(front + legs, 0.0, 1.0) * 0.92);
		}
	} else if (ad < hw + kerb_width) {
		// Kerbs: 1 m red/white blocks with a rounded-looking shade across.
		float k = mod(floor(s / 1.0), 2.0);
		float across = (ad - hw) / kerb_width;
		col = mix(kerb_a, kerb_b, k) * (0.92 + 0.12 * sin(across * 3.14159));

	} else {
		// Verge: mown stripes along the track, with clover noise.
		float stripe = step(0.5, fract(s / 8.0));
		float n = vnoise(vec2(d, s) * 3.0);
		col = mix(grass_a, grass_b, 0.35 + verge_stripes * stripe) * (0.85 + 0.3 * n);
		if (cobbles > 0.0) {
			// Cobbles: offset rows of rounded setts, dark joints between.
			vec2 c = vec2(ad * 3.2, s * 2.4);
			c.x += step(1.0, mod(floor(c.y), 2.0)) * 0.5;
			vec2 f = abs(fract(c) - 0.5);
			float joint = smoothstep(0.38, 0.47, max(f.x, f.y));
			col = mix(col * (0.9 + 0.2 * vnoise(floor(c) * 7.0)), col * 0.55, joint * cobbles);
		}
		// Rubber and dust thrown onto the verge just off the kerb.
		col = mix(col, verge_dust, 0.25 * smoothstep(hw + kerb_width + 0.9, hw + kerb_width, ad));
	}
	vec3 lit = col * (hemi(vec3(0.0, 1.0, 0.0)) * 0.55 + sun_color * normalize(sun_dir).y * 1.25) * light_gain;
	ALBEDO = grade(haze(lit, length(VERTEX)), SCREEN_UV);
}
