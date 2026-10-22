// The tunnel's surfaces (Cadence Karaoke, #42): a dark panel with glowing lines that scroll toward
// the rider and flare on the beat. The long lines are the theme's neon, the cross lines (the ones
// that scroll) its secondary. Unshaded, hazed and graded by hand (cadence_look.gdshaderinc).
// Each surface is a small wrapper that defines its extras before including this file:
//   GRID_FLOOR  the rings' and the beat line's reflections
//   GRID_WALL   the equaliser columns
// so no surface pays for another's (these planes cover the whole screen).
//
// Lines are antialiased in screen space: a line's distance is measured in pixels (fwidth), its
// core never drawn thinner than about 1.2 px (dimmed instead, so its coverage holds), and the
// contrast fades to the lines' average toward the far end, so they melt into the haze instead
// of shimmering into moiré. (An include can't declare the shader type: the wrappers do, with
// `render_mode unshaded, fog_disabled, cull_disabled`.)

#include "res://games/cadence_karaoke/shaders/cadence_look.gdshaderinc"

uniform vec3 line_color : source_color = vec3(0.2, 0.8, 1.0);
uniform vec3 line2_color : source_color = vec3(1.0, 0.3, 0.85);  // the secondary: cross lines
uniform vec3 base_color : source_color = vec3(0.05, 0.065, 0.085);
uniform vec3 across_axis = vec3(1.0, 0.0, 0.0);  // which way the long lines are spaced on this surface
uniform float scroll = 0.0;
uniform float beat = 0.0;  // 0-1, a flare that decays after each beat
uniform float energy = 1.0;  // the theme's brightness (cool-down is dimmer)
uniform float spacing = 2.5;

#ifdef GRID_FLOOR
uniform float ring_phase = 0.0;  // CadenceWorld's beat_phase: where the rings are
uniform float ring_spacing = 7.0;
uniform float line_z = -18.0;  // the beat line
#endif
#ifdef GRID_WALL
uniform float beat_clock = 0.0;  // beats since the start: the equaliser moves on the beat's clock
uniform float floor_y = -3.4;
uniform float wall_height = 7.6;
#endif

varying vec3 world_pos;

// A line every whole `x`: x.core (antialiased, at least ~1.2 px) and x.halo (a soft glow in
// world units, averaged out once it is smaller than a pixel or two). `half_w` is the core's
// half-width and 1/`halo_k` the halo's, both in cells; `fw` is fwidth(x), taken once for both
// axes by the caller.
vec2 grid_line(float x, float fw, float half_w, float halo_k) {
	float d = abs(fract(x + 0.5) - 0.5);
	float w_px = half_w / fw;
	float wc = max(w_px, 0.6);
	float core = (1.0 - smoothstep(wc - 0.5, wc + 0.5, d / fw)) * min(w_px / 0.6, 1.0);
	float halo = mix(exp(-d * halo_k), 2.0 / halo_k, smoothstep(0.15, 0.6, fw * halo_k));
	return vec2(core, halo);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = length(VERTEX);
	float along = (world_pos.z - scroll) / spacing;
	float across = dot(world_pos, across_axis) / spacing;
	vec2 fw = max(fwidth(vec2(across, along)), vec2(1e-5));
	vec2 l_long = grid_line(across, fw.x, 0.012, 9.0);
	vec2 l_cross = grid_line(along, fw.y, 0.01, 11.0);
	// Far away, every line fades to its average: the glow without the moiré.
	float far = smoothstep(60.0, 140.0, dist);
	l_long = mix(l_long, vec2(0.024, 2.0 / 9.0), far);
	l_cross = mix(l_cross, vec2(0.02, 2.0 / 11.0), far);
	float flare = (0.55 + beat * 1.6) * energy;
	vec3 col = base_color;
	col += line_color * (l_long.x * 1.1 + l_long.y * 0.35) * flare;
	col += line2_color * (l_cross.x * 0.8 + l_cross.y * 0.28) * flare;
#ifdef GRID_FLOOR
	// The floor is a little glossy. Each ring leaves a streak on it toward the rider (its
	// mirror image), brighter by the walls where the ring's sides stand, and brightest as it
	// lands on the line. Rings sit at z = line_z - (k - 1 - ring_phase) * ring_spacing.
	float k = (line_z - world_pos.z) / ring_spacing + 1.0 + ring_phase;
	float fk = fract(k);
	float ring_z = line_z - (ceil(k) - 1.0 - ring_phase) * ring_spacing;
	float landing = exp(-abs(ring_z - line_z) * 0.12);
	float side = 0.35 + 0.65 * smoothstep(4.0, 7.4, abs(world_pos.x));
	float streak = exp(-(1.0 - fk) * ring_spacing * 0.8) * (1.0 - smoothstep(0.985, 1.0, fk));
	col += line_color * streak * side * (0.18 + 0.5 * landing * (0.5 + beat)) * energy * (1.0 - far);
	// The beat line's gleam, across the lane.
	float lane = 1.0 - smoothstep(3.0, 5.0, abs(world_pos.x));
	col += vec3(1.0) * exp(-abs(world_pos.z - line_z) * 1.1) * lane * (0.1 + beat * 0.25);
#endif
#ifdef GRID_WALL
	// Equaliser columns 0.6 m wide between the long lines: each column's lit height follows the
	// beat and a slow noise on the beat's clock. Low, so the rings stay the brightest thing.
	float cz = (world_pos.z - scroll) / 0.6;
	float column = floor(cz);
	float h = (0.12 + 0.5 * vnoise(vec2(column + 0.5, beat_clock * 1.5))) * (0.75 + 0.35 * beat);
	float y = (world_pos.y - floor_y) / wall_height;
	float fy = max(fwidth(y), 1e-5);
	float lit = 1.0 - smoothstep(h - fy, h + fy, y);
	float gap = smoothstep(0.08, 0.16, fract(cz)) * (1.0 - smoothstep(0.84, 0.92, fract(cz)));
	float cell = smoothstep(0.25, 0.35, fract(y * 18.0));  // LED segments
	vec3 bar = mix(line_color, line2_color, smoothstep(0.1, 0.55, y));
	col += bar * lit * gap * cell * 0.13 * energy * (1.0 - far);
#endif
	ALBEDO = grade(haze(col, dist), SCREEN_UV);
}
