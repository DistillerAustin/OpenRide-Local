# Cadence Karaoke: graphics polish punch list

**Status (2026-10-20, branch gfx-cadence):** P0 and P1 done except 8 (render scale, a tablet
measurement); P2 done. After captures in the scratchpad's `gfx/after/cadence/`. Measured on the
desktop (`capture_cadence.gd --measure` / `--overdraw`): 3D view draws 11 → 13-14, primitives
382 → about 1k, overdraw mean 0.340 → 0.099, frame time about 0.86 → 1.05 ms (the planes' new
ALU; the fill saving shows on the tablet, not here). HUD-on play: 64 → 66 draw calls.

From the graphics review of 2026-10-19 against `ART_BIBLE.md` (this folder) and Kart Race's
polish. UI is out of scope (`UI_POLISH.md`), and so are gameplay and tuning.

**Before captures** (desktop, 1280×720, no HUD), in the review's scratchpad `gfx/before/`:
`cad_look_{cyan,green,violet,pink}.png` (every theme, 3 s into a ride) and `cad_{a..e}.png` (a
scripted 42 s ride: on the target, drifting off, a pace change), and with the HUD
`ui_states/cadence_karaoke_{1..6}_*.png` (64 draw calls in play). Retake after each item
(`--nohud` and `--looks` were added to the capture script in this review):

```sh
$GODOT_BIN --path games -s res://tests/capture_cadence.gd -- --out=DIR --nohud --looks=cyan,green,violet,pink
$GODOT_BIN --path games -s res://tests/capture_cadence.gd -- --out=DIR --nohud --play=42
```

Costs are estimates for the tablet with the tracker off; ±3 fps is noise. This view is
full-screen and additive, so per-pixel cost is what to watch. Keep `cadence_logic_test`,
`cadence_scene_test` and the full suite green.

## What works (keep)

- The read: the white line, the box and the orb in the lower centre; rings landing on the beat.
- The theme follows the workout part and the HUD follows the theme.
- Cheap: about 25 world draw calls, a dozen transforms a frame.

## P0: the look's foundation

1. **Rings as frames, not discarded quads** (`_build_rings`, `shaders/ring.gdshader`). Each ring
   is a 15 × 7.4 m quad that `discard`s everything but its border: 18 of them stack over the
   middle of the screen, and `discard` disables the PowerVR's hidden-surface removal for all of
   it. Build one frame mesh (four thin quads, 8 triangles, UV.y across the strip for a soft
   edge) and draw it in the MultiMesh instead; the shader drops `discard`, draws a bright core
   and a soft halo across the strip, and a glint at the corners. Cost: a large fill saving
   (most of the screen loses up to 18 layers of fragment work). Verify: the rings look the same
   or better; `cad_look_*.png` match at 50%.
   **Done** (2026-10-20): `CadenceWorld.frame_mesh` (mitred strips, 16 triangles; UV.x is metres from the corner, for the glints), `ring.gdshader` without `discard`; a ring brightens as it nears the line. Overdraw (the capture's `--overdraw`, mean green) 0.340 → 0.099.
2. **Antialiased, distance-faded grid lines** (`shaders/grid.gdshader`). Fixed world-unit widths
   alias into moiré down the tunnel. Compute each line's distance in screen pixels
   (`abs(fract(x) - 0.5) / fwidth(x)`), draw a 1.2 px core plus a soft halo, and fade the line
   contrast toward the far end (`smoothstep(60, 140, length(VERTEX))`) so lines melt into the
   glow instead of shimmering. Cost: about +8 ALU a pixel on full-screen planes. Verify: the far
   tunnel in `cad_look_cyan.png` is smooth, no moiré, and lines near the camera stay crisp.
   **Done**: `grid.gdshaderinc` `grid_line()` (one `fwidth` for both axes, core ≥ 1.2 px dimmed to keep its coverage, halo averaged once sub-pixel), contrast fading to the lines' average over 60-140 m.
3. **The orb as a singer** (`_build_orb`, `update_view`). A flat unshaded sphere today, lost on
   the green theme in band. Give it a small shader: a white-hot core, the state colour as a
   fresnel rim and halo, a thin dark outline ring (ink `#12052A`) so it pops on every theme,
   and a floor reflection pool (a flat additive quad under it in the state colour). Keep
   `_orb_color`'s semantics. Cost: +1 draw (the pool), negligible ALU (small on screen).
   Verify: `cad_look_green.png` with the orb in band: the orb reads at once.
   **Done**: `orb.gdshader` (white-hot core, state-colour fresnel rim, ink outline), `orb_halo.gdshader` (starts outside the outline, no texture), `orb_pool.gdshader` on the floor. `_orb_color` unchanged. The sphere went to 24 × 12 segments so the rim doesn't show facets.
4. **A secondary colour and the grade** (`THEMES`, `set_theme_color`, both shaders). Add a
   secondary per theme (ART_BIBLE §2) for the cross lines, the floor and the portal; include the
   shared world look for `grade` with Cadence's defines and `haze` toward the background (the
   depth fade, replacing each shader's own `exp(-fade * …)`). Cost: about +4 ALU. Verify: the
   four look captures read as four distinct, two-colour moods, cool-down the dimmest.
   **Done**: `CadenceWorld.SECONDARY` and `ENERGY` (cool-down 0.8), `set_theme(name)`; `cadence_look.gdshaderinc` sets the grade's defines (additive layers get only the linear parts: saturation and the vignette); haze toward the background plus 5% of the secondary (the horizon glow), toward black on the additive layers.

## P1: the tunnel comes alive

5. **A portal at the end** (`_build_tunnel`). Replace the black square at the vanishing point
   with a far disc card (one quad at z ≈ -130, inside the camera's far plane of 140) in the secondary, with horizontal bands and a
   soft glow, pulsing faintly on the beat. Cost: +1 draw, small on screen. Verify: depth reads
   in every capture.
   **Done**: `portal.gdshader` on a 15 × 7.6 m card at z -130 (`PORTAL_Z`), on the haze colour so it closes the tunnel seamlessly. It is only about 30 px tall at 0.62, so it reads as a glowing point with two or three bands.
6. **Floor reflections** (`shaders/grid.gdshader`, floor only via a uniform). The rings sit at
   known z (`ORB_Z - (i - 1 - beat_phase) * RING_SPACING`), so the floor can add a faint
   streak under each ring from `beat_phase` and `fract`, plus the white line's reflection, with
   no extra pass. Cost: +6 ALU on the floor. Verify: the floor gleams under each ring as it
   lands.
   **Done** (`GRID_FLOOR` in `grid_floor.gdshader`): a streak toward the rider from each ring, stronger by the walls and as the ring lands, and the beat line's gleam. `CadenceWorld.ring_z` is the one placement both use (`cadence_world_test` pins them together).
7. **Equaliser walls** (`shaders/grid.gdshader`, walls only). Columns 0.6 m wide whose lit
   height follows `beat` and a slow `vnoise` per column, between the wall's long lines, at low
   intensity. Cost: one noise read, +8 ALU on the walls. Verify: the walls move with the music,
   never brighter than the rings.
   **Done** (`GRID_WALL`): 0.6 m LED columns, height from `vnoise` on `beat_clock` (whole beats + phase, counted in `update_view`) and `beat`, at 0.13 of the line colour, the secondary at the top.
8. **Render scale 0.72** (`CadenceKaraoke.RENDER_SCALE`). Thin neon lines suffer most from the
   0.62 upscale, and this game runs with the camera off. Measure 0.62 against 0.72 for 60 s each
   on the bike; adopt 0.72 if it holds 58+. Cost: about 35% more pixels: measure.
   **Not done: needs the bike.** The choice is a tablet measurement (60 s each at 0.62 and 0.72); this pass is desktop only. `RENDER_SCALE` stays 0.62 for the integration step to measure.

## P2: if there is time

9. **Beat-line sparks in the bonus band** (`update_view`). A pooled MultiMesh of 16 additive
   streaks whose motion is in the vertex shader (birth time per instance), fired when a ring
   lands while `state == "in_bonus"`. Cost: +1 draw, no per-frame GDScript.
   **Done**: `spark.gdshader`, 16 instances, motion in the vertex shader from `INSTANCE_CUSTOM` (birth, x, seeds) and `now`; custom data written once per burst. The node is hidden between bursts (no draw), and drawn, all dead, for the first 0.2 s so the shader compiles under the intro card instead of hitching at the first burst.
10. **Orb trail.** Five fading copies of the halo at the orb's last positions (a tiny MultiMesh
    written each frame), longer with the streak.
   **Done, differently**: the trail is a term in the pool's shader (a tail toward the rider, longer and brighter with `streak`), so no MultiMesh, no draw call and no per-frame transforms.
11. **Ease-off desaturation.** A `frozen` uniform that pulls the grade's saturation toward 0.6
    on every tunnel material while scoring is frozen.
   **Done**: `frozen` in `cadence_look.gdshaderinc` (`LOOK_SAT` × (1 − 0.4·frozen)), eased in and out over 0.4 s on the tunnel, rings and portal. The orb keeps its amber.

## Out of scope / rejected

- The engine's glow (Environment glow): a full-screen multi-pass blur. Kart measured a single
  full-screen pass at about 5 fps; the halos in the line shaders give the look for a fraction.
  Revisit only with a tablet measurement, since this game runs with the camera off.
- MSAA: black on this driver's SubViewport, and it would not fix shader-drawn lines anyway.
