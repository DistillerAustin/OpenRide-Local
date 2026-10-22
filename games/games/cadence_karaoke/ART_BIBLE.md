# Cadence Karaoke: art bible

> **Status:** v1, 2026-10-19, from the graphics review of `games-polish` at 6ef6fab (code and
> the before captures). **Owner:** whoever changes the look. Change this file in the same commit
> as any change to the themes, the tunnel, the orb or the effects. **Sources of truth:**
> `CadenceWorld.gd` (`THEMES`, `SECONDARY`, `ENERGY`, the meshes), `shaders/` (the grid include
> and its floor, wall and ceiling wrappers, `cadence_look.gdshaderinc`, ring, orb, halo, pool,
> portal, spark), `CadenceKaraoke._make_look` (UI). The graphics pass of 2026-10-20
> (`GFX_POLISH.md`) built every **Target** below except the render scale (a tablet measurement)
> and the beat FOV push (off by choice); "Target" now marks only those.

Everything is procedural: shaders and primitive meshes. Neon tunnels and grids are a generic
synthwave motif; take the mood, never another game's track, logo or layout.

## 1. Identity

**The one rule:** *a neon tunnel that breathes with the beat, and the orb is the singer.* When
something is ambiguous, pick what makes the beat and the orb's place against the box clearer.

| Pillar | Design test |
| --- | --- |
| **The beat is visible** | Every beat lands as a ring on the white line and a flare through the tunnel. Anything that pulses must pulse on the beat, never on its own clock. |
| **Light is the material** | Surfaces are near-black; everything readable is emitted light: lines, rings, the orb. No lit solids. |
| **Calm at the centre** | The orb and the box sit in the lower centre; the tunnel's motion stays at the edges and far away. Recovery-ride calm, not a strobe. |

Distinct from Kart (sunlit, toy, violet grade) and from Dodge and Tug (daylight worlds): Cadence
is the night-time, music-video game.

## 2. Mood per theme (`CadenceWorld.THEMES`, by workout part or the Colour option)

| Theme | Neon | Mood | Target secondary |
| --- | --- | --- | --- |
| warm-up (cyan) | `#40CCFF` | Fresh, waking up | magenta `#FF4FD8` on the floor's cross lines |
| recovery (green) | `#4DFFA6` | Easy, breathing | teal-blue `#3DA5FF` |
| cool-down (violet) | `#B880FF` | Winding down, dim | warm rose `#FF8FB3` |
| free (pink) | `#FF73CC` | Party | sunset orange `#FFA347` |

The theme colour is on the long lines and the rings; the secondary (`CadenceWorld.SECONDARY`)
on the cross lines, the equaliser tops and the far portal, mixed into the horizon glow (the
haze colour is the background plus 5% of it). Cool-down runs 20% dimmer (`ENERGY`).

## 3. Palette

| Role | Colour | Rule |
| --- | --- | --- |
| Void, panels | `#030308` background, `#050810` panels | Near-black with a blue cast; never pure black panels next to lines. |
| Long lines, rings | theme neon | Bright cores, soft halos. |
| Beat line | white `#FFFFFF` | Always white, so it is never taken for a ring. |
| Box gates, lane | theme neon, lane at 16-26% additive | The box is the scoring zone: its edges must read on every theme. |
| Orb: bonus / band / near / out / frozen | `#73FFA6` / `#99FF80` / `#FFD94D` / `#FF6659` / `#FFB333` | Semantic, not themed. |

**Clash to fix:** the orb's "in band" greens sit on the recovery theme's green tunnel, so the
orb loses its edge exactly when the rider is doing well. Fixed: the orb keeps its state
colour as a fresnel rim and halo, around a white-hot core with a dark ink outline
(`orb.gdshader`), so it pops on every theme.

**UI harmony.** The HUD is rebuilt per theme from `world.theme_color` (`_make_look`, ink
`#12052A`), so the UI accent always equals the tunnel's neon. Any secondary colour stays out of
the HUD; the target number's gradient and the ±5 rpm buttons follow the neon only.

## 4. Lighting, materials and shading

- **No lit surfaces.** Everything is `unshaded`, emitted, additive where it overlaps. The shared
  include (`framework/shaders/world_look.gdshaderinc`) is used only for `vnoise`, `haze` (the
  depth fade to the void, `haze_color` = background) and `grade`.
- **Cadence's grade** (the `LOOK_*` defines in `shaders/cadence_look.gdshaderinc`). Opaque
  surfaces (tunnel, portal) take all of it; additive layers (rings, halo, pool, sparks) define
  `CADENCE_ADDITIVE` and take only its linear parts, saturation and the vignette, so stacked
  layers still add up. While scoring is frozen, `frozen` pulls the saturation down 40%:

  | Define | Value |
  | --- | --- |
  | `LOOK_SAT` | 1.15 |
  | `LOOK_CONTRAST` | 1.1 |
  | `LOOK_GAIN` | `vec3(1.0)` |
  | `LOOK_LIFT` | `vec3(0.01, 0.0, 0.03)` (ink-violet blacks, the UI's ink) |
  | `LOOK_VIGNETTE` | 0.35, tint `vec3(0.8, 0.7, 1.1)` |

- **Glow without a glow pass.** Each line is drawn as a core plus a soft exponential halo in its
  own shader (`core + halo * exp(-d * k)`), and the orb has a billboard halo. The engine's glow
  is a full-screen multi-pass blur: not on this tablet.
- **Lines are antialiased in the shader** (`grid_line()` in `grid.gdshaderinc`, the ring's
  strip): the core is measured in screen pixels via `fwidth()`, never thinner than about 1.2 px
  (dimmed instead, so its coverage holds), and the contrast fades to the lines' average over
  60-140 m so far lines don't moiré.

## 5. Shapes and proportions

- The tunnel: 15 m wide, 7.6 m tall (`HALF_W`, `FLOOR_Y`, `CEIL_Y`), lines every 2.5 m.
- Rings: a 15 × 7.4 m rectangle outline, 7 m apart, one per beat: a frame mesh
  (`CadenceWorld.frame_mesh`, four mitred strips 0.7 m wide with a ~0.1 m core), white corner
  glints, brightest as a ring nears the line.
- The box: a lane 6.4 m wide on the floor, two gates, the white beat line (`_build_line`).
- The orb: 0.6 m radius on the floor, growing a little with the beat and the streak.
  A reflection pool on the floor under it and a light trail toward the rider, longer with the
  streak (both `orb_pool.gdshader`, one quad).

## 6. Environment

- **Depth cues:** the converging grid, the rings shrinking with distance, and a portal
  at the far end: a glowing horizon disc in the theme's secondary with horizontal bands, so the
  tunnel has a destination instead of a black square.
- **Walls:** equaliser bars on the side walls rising with the beat and the music's
  energy (per-column height from `vnoise` and `beat` in the wall shader, no geometry).
- **Floor:** a faint glossy reflection of the rings and the orb, analytic in the floor
  shader (the rings are periodic in z, so no extra pass).

## 7. VFX language

| Effect | Look |
| --- | --- |
| Beat | A ring reaches the white line; lines flare (`beat`); the orb swells |
| Streak | The orb grows and brightens and its floor trail lengthens. (Target: the tunnel's scroll lines brighten) |
| Streak break | The orb flashes red (`orb_flash`) |
| In bonus | Sparks off the beat line as a ring lands (16 pooled streaks, `spark.gdshader`, motion in the vertex shader; hidden between bursts) |
| Ease off (frozen) | The orb turns amber; the tunnel desaturates 40% until it clears (eased over 0.4 s) |

Additive everywhere except the floor's reflection and the vignette. Effects stay in the theme,
its secondary, white or the orb's state colours.

## 8. Camera

Fixed: 2.2 m up, pitched -12°, FOV 64, looking down the tunnel's axis. No roll, no shake: the
motion is the tunnel's, never the camera's. A beat may push the FOV by at most 1° (Target, off
by default if it reads as a lurch).

## 9. Tablet budget (Gen 2, PowerVR GX6250, Compatibility, tracker OFF)

| Item | Budget | After the graphics pass (desktop, 2026-10-20) |
| --- | --- | --- |
| fps | 60 | not measured on the bike for the graphics |
| Render scale | 0.62 (`CadenceKaraoke.RENDER_SCALE`); the tracker is off, so 0.72 is affordable if measured (Kart: 0.72 cost about 4 fps with the tracker) | 0.62 (0.72 still to measure on the bike) |
| Draw calls in play | ≤ 70 with the HUD (world ≤ 30) | 66 (world 13-14: +portal, +pool, +sparks only during a burst; was 64 and 11) |
| Visible triangles | ≤ 20k | about 1k (was 382: the orb is 24 × 12 segments, the rings 16 triangles each) |
| Per pixel on the tunnel | ≤ 2 noise reads, ≤ 40 ALU; the four planes cover the whole screen | about 35 on the ceiling, 45 on the floor, 55 on the walls (an estimate, the walls over budget) with one noise read on the walls; desktop frame +0.2 ms (0.86 → about 1.05 ms) |
| Overdraw | ≤ 3 additive layers over most of the screen; no full-screen `discard` quads | about 1 layer on average (capture `--overdraw` mean green 0.099, was 0.340); no `discard` anywhere |
| Per-frame GDScript | ring transforms (18) and a few uniforms | as is, plus 16 custom-data writes per spark burst |

This game is GPU (fill) bound if anything: the tunnel is full-screen and additive. Spend ALU
on the planes carefully and keep overdraw down; the CPU has headroom with the camera off. The
graphics pass traded ALU on the planes (antialiased lines, the grade, reflections, the
equaliser) for the rings' fill (up to 18 layers with `discard` in the middle of the screen):
the tablet's measurement decides whether the walls' equaliser stays.
