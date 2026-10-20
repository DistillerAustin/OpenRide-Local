# Cadence Karaoke: art bible

> **Status:** v1, 2026-10-19, from the graphics review of `games-polish` at 6ef6fab (code and
> the before captures). **Owner:** whoever changes the look. Change this file in the same commit
> as any change to the themes, the tunnel, the orb or the effects. **Sources of truth:**
> `CadenceWorld.gd` (`THEMES`, the meshes), `shaders/grid.gdshader`, `shaders/ring.gdshader`,
> `CadenceKaraoke._make_look` (UI). **Target** marks what the code doesn't do yet;
> `GFX_POLISH.md` tracks the work.

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

Today each theme is one colour on every surface, so the tunnel reads monochrome. **Target:**
the theme colour on the long lines and the rings, the secondary on the cross lines and the
far portal, mixed in the horizon glow. Cool-down runs about 20% dimmer than the others.

## 3. Palette

| Role | Colour | Rule |
| --- | --- | --- |
| Void, panels | `#030308` background, `#050810` panels | Near-black with a blue cast; never pure black panels next to lines. |
| Long lines, rings | theme neon | Bright cores, soft halos. |
| Beat line | white `#FFFFFF` | Always white, so it is never taken for a ring. |
| Box gates, lane | theme neon, lane at 16-26% additive | The box is the scoring zone: its edges must read on every theme. |
| Orb: bonus / band / near / out / frozen | `#73FFA6` / `#99FF80` / `#FFD94D` / `#FF6659` / `#FFB333` | Semantic, not themed. |

**Clash to fix:** the orb's "in band" greens sit on the recovery theme's green tunnel, so the
orb loses its edge exactly when the rider is doing well. **Target:** the orb keeps its state
colour as a ring and halo, around a white-hot core with a dark outline ring, so it pops on
every theme.

**UI harmony.** The HUD is rebuilt per theme from `world.theme_color` (`_make_look`, ink
`#12052A`), so the UI accent always equals the tunnel's neon. Any secondary colour stays out of
the HUD; the target number's gradient and the ±5 rpm buttons follow the neon only.

## 4. Lighting, materials and shading

- **No lit surfaces.** Everything is `unshaded`, emitted, additive where it overlaps. The shared
  include (`framework/shaders/world_look.gdshaderinc`) is used only for `vnoise`, `haze` (the
  depth fade to the void, `haze_color` = background) and `grade`.
- **Cadence's grade** (the `LOOK_*` defines, Target):

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
- **Lines are antialiased in the shader** (Target): widths in screen pixels via `fwidth()`, and
  contrast fading with distance so far lines don't moiré. Today they are fixed widths in world
  units, which shimmer into moiré down the tunnel at 0.62 scale.

## 5. Shapes and proportions

- The tunnel: 15 m wide, 7.6 m tall (`HALF_W`, `FLOOR_Y`, `CEIL_Y`), lines every 2.5 m.
- Rings: a 15 × 7.4 m rectangle outline, 7 m apart, one per beat. **Target:** a frame mesh
  (four thin quads), rounded corner glints.
- The box: a lane 6.4 m wide on the floor, two gates, the white beat line (`_build_line`).
- The orb: 0.6 m radius on the floor, growing a little with the beat and the streak.
  **Target:** a reflection pool on the floor under it and a short light trail behind it.

## 6. Environment

- **Depth cues:** the converging grid, the rings shrinking with distance, and (Target) a portal
  at the far end: a glowing horizon disc in the theme's secondary with horizontal bands, so the
  tunnel has a destination instead of a black square.
- **Walls** (Target): equaliser bars on the side walls rising with the beat and the music's
  energy (per-column height from `vnoise` and `beat` in the wall shader, no geometry).
- **Floor** (Target): a faint glossy reflection of the rings and the orb, analytic in the floor
  shader (the rings are periodic in z, so no extra pass).

## 7. VFX language

| Effect | Look |
| --- | --- |
| Beat | A ring reaches the white line; lines flare (`beat`); the orb swells |
| Streak | The orb grows and brightens; **Target:** the tunnel's scroll lines brighten and the trail lengthens |
| Streak break | The orb flashes red (`orb_flash`) |
| In bonus | **Target:** sparks off the beat line as a ring lands (a tiny pooled MultiMesh, additive) |
| Ease off (frozen) | The orb turns amber; **Target:** the tunnel desaturates 40% until it clears |

Additive everywhere except the floor's reflection and the vignette. Effects stay in the theme,
its secondary, white or the orb's state colours.

## 8. Camera

Fixed: 2.2 m up, pitched -12°, FOV 64, looking down the tunnel's axis. No roll, no shake: the
motion is the tunnel's, never the camera's. A beat may push the FOV by at most 1° (Target, off
by default if it reads as a lurch).

## 9. Tablet budget (Gen 2, PowerVR GX6250, Compatibility, tracker OFF)

| Item | Budget | Today (desktop) |
| --- | --- | --- |
| fps | 60 | not measured on the bike for the graphics |
| Render scale | 0.62 (`CadenceKaraoke.RENDER_SCALE`); the tracker is off, so 0.72 is affordable if measured (Kart: 0.72 cost about 4 fps with the tracker) | 0.62 |
| Draw calls in play | ≤ 70 with the HUD (world ≤ 30) | 64 |
| Visible triangles | ≤ 20k | a few thousand |
| Per pixel on the tunnel | ≤ 2 noise reads, ≤ 40 ALU; the four planes cover the whole screen | about 15 ALU |
| Overdraw | ≤ 3 additive layers over most of the screen; no full-screen `discard` quads | 18 ring quads of 15 × 7.4 m with `discard` in the middle |
| Per-frame GDScript | ring transforms (18) and a few uniforms | as is |

This game is GPU (fill) bound if anything: the tunnel is full-screen and additive. Spend ALU
on the planes carefully and keep overdraw down; the CPU has headroom with the camera off.
