# Dodge Ball: graphics polish punch list

From the graphics review of 2026-10-19 against `ART_BIBLE.md` (this folder) and Kart Race's
polish. UI is out of scope (`UI_POLISH.md`), and so are gameplay and tuning.

**Before captures** (desktop, 1280×720 window, no HUD), in the review's scratchpad
`gfx/before/`: `dodge_{dawn,day,dusk,night}.png`, `catch/dodge_{day,dawn,night}.png` (a ball
closing in), `bonus/dodge_dusk.png` (the power bonus edge glow), and with the HUD
`ui_states/dodge_ball_{1..6}_*.png` (101-113 draw calls in play). Retake after each item:

```sh
$GODOT_BIN --path games -s res://tests/capture_dodge.gd -- --out=DIR --nohud
$GODOT_BIN --path games -s res://tests/capture_ui_states.gd -- --game=dodge_ball --out=DIR
```

**Status (2026-10-20, gfx-dodge):** P0 and P1 done, P2 9 and 11 done, 10 open (tablet).
After captures: `gfx/after/dodge/`. Desktop, no HUD: 54-57 draw calls (49-57 before), about
19k triangles (15-16k before), frame time within noise; with the HUD in play 101-113 (as before).

Costs are estimates for the tablet with the tracker on; ±3 fps is run-to-run noise, so anything
marked "measure" needs a `DEV_TUNING` run on the bike before it ships (docs/GAMES.md, Dodge Ball
→ On the tablet). Keep `dodge_ball_scene_test` and the full suite green.

## What works (keep)

- The road reads at once, the lane warnings are clear, and the balls are the hottest colour.
- Night is the best preset: lamp pools and the headlight on the road, halos, stars.
- The chunk leapfrog and MultiMesh scenery cost almost nothing per frame.

## P0: the look's foundation

1. [x] **One hand light for the scenery.** `DodgeWorld._recolor` and `_cheap` give the Kenney
   meshes `StandardMaterial3D` lit per vertex by the engine and fogged by the engine, while the
   road and verges light and fog themselves: far trees haze differently from the road under
   them, and nothing shares a grade.
   - Add `shaders/scenery.gdshader`: `#include "res://framework/shaders/world_look.gdshaderinc"`
     with Dodge's `LOOK_*` defines (ART_BIBLE §4), `sun_light(n)` in `vertex()`, a `uniform vec3
     albedo`, painted AO by height (`mix(0.7, 1.0, smoothstep(0.0, 1.5, VERTEX.y * scale))`),
     `haze(…, length(VERTEX))` and `grade(…, SCREEN_UV)` in `fragment()`. Foliage sway: `uniform
     float sway` × the vertex's height above the trunk, phase from `MODEL_MATRIX[3]`.
   - `_recolor` / `_cheap` build one `ShaderMaterial` per surface colour (cache them by colour,
     so chunks share them: no new draw calls).
   - `set_time_of_day` builds one look dictionary (`sun_dir` from `WorldLook.sun_dir`, sun,
     ambient as sky/ground, fog as haze) and calls `WorldLook.apply` on the road, verge,
     scenery and sky materials. Move `road.gdshader` and `verge.gdshader` onto the include
     (their `light_color` becomes `sun_light(vec3(0, 1, 0))`; keep their fog maths identical so
     the day capture doesn't shift).
   - Cost: none on the CPU (the same draws), about +4 ALU per pixel for the grade. Verify:
     captures, far trees now haze into the same colour as the far road.
   - **Done (058407b): `shaders/scenery.gdshader` via `DodgeWorld._hand_lit` (one material per surface look, shared by chunks); Dodge's `LOOK_*` defines live once in `shaders/look.gdshaderinc`. `_recolor`/`_cheap` were left as they were: Tug of War calls them and builds its own look. Energies scale in linear light (`look_for`), so the night keeps its tone.**

2. [x] **A horizon.** The verge planes end 80 m out; past them is a flat seam between grass and sky
   (`dodge_day.png`, centre). `_build_road`: add one ring mesh of low rolling hills (a
   procedural strip of quads with a vertex-colour gradient, 150-160 m out, 6-14 m high, behind
   the camera's far plane of 170) and, in front of it, a tree-line band (a strip of chunky
   bumps). Both use the scenery shader, haze nearly to `haze_max`, and move with the rider's x
   only (not with `scroll`, so they read as far away). Cost: 2 draw calls, about 2k triangles.
   Verify: no visible seam in any preset; the night silhouette is a slightly lighter navy.
   - **Done: one mesh (hills at 155 m and a tree line at 125 m, about 630 triangles, one draw call), hazed with `haze_scale` 2.5.**

3. [x] **Sky fixes** (`shaders/sky.gdshader`, `tod/make_presets.py`).
   - The sun disc term is far too big (about 25° across at dawn and dusk). Use
     `smoothstep(cos(radians(2.0)), cos(radians(1.6)), s)` for the disc and move the warmth
     into the halo (`pow(s, 8)` and a wider horizon glow toward the sun's azimuth).
   - Stars only at night: set dawn 0.15 and dusk 0.3 to 0 in `make_presets.py` and regenerate.
   - Clouds: the three noise reads band into flat smears. Shape them as cumulus: one read for
     the shape, a second offset toward the sun for a lit top and darker base
     (`mix(cloud_shade, cloud_color, lit)`), fade by `h`. Same read count.
   - Add the grade (the include's `grade` with `SCREEN_UV = vec2(0.5)`, so no vignette).
   - Cost: the sky radiance only rebuilds on a preset change (no `TIME`); per pixel the same 3
     reads. Verify: the dawn and dusk captures show a small bright sun, warm horizon, no stars.
   - **Done: disc radius = `sun_size` in radians (3-4° across), horizon glow toward the sun's azimuth, cumulus lit from the sun's side (still 3 reads), stars only at night, the grade without vignette. The sky's own colours were renamed (`below_color`, `disc_color`) to sit beside the include's uniforms.**

4. [x] **The road surface** (`shaders/road.gdshader`). The near metres are soft blotches (the grain
   at `* 3.0` is magnified under the camera).
   - Grain at two scales: fine `vnoise(p * 9.0)` fading in with distance, so the near field has
     aggregate texture and the far field doesn't shimmer.
   - The rubbered line: a darker band down each lane's wheel track (today it is lighter: invert
     to −15%), and a grime band 0.4 m inside each edge line.
   - A sun glare: `pow(max(dot(reflect(-view, up), sun_dir), 0), 8) × 0.2`, broken by the grain
     (the road's shine toward the sun at dawn and dusk).
   - Repair patches every 45 m (a darker rectangle from one noise read at low frequency).
   - Cost: +1 noise read (3 total), about +10 ALU per pixel on the largest surface: measure.
     Verify: `dodge_day.png` near field has fine grit, no blotches; the dusk road glows toward
     the sun.
   - **Done: fine grit fading out by 22 m, wheel tracks −15%, edge grime, repair patches (cell wraps with the scroll), glare 0.15. Three reads. Tablet cost still to measure.**

## P1: life and readability

5. [x] **Scenery dressing for rhythm** (`_build_scenery`). Add, per chunk, into the same chunk node
   as MultiMeshes: a low rail or hedge line at 4.5 m from the kerb (one procedural box-strip
   mesh, vertex-coloured), and a painted contact disc under every tree and rock (a quad in a
   MultiMesh with the blob shader: one draw per chunk for all of them). Rocks get a lighter top
   and darker base from the scenery shader's height AO. Cost: +2 draw calls a chunk (+6),
   about 1.5k triangles. Verify: the right-hand rock in `dodge_day.png` no longer reads as a
   grey slab; something passes the edge of view every 2 s at 60 rpm.
   - **Done: a post-and-rail fence 4.5 m off the kerb (one scrolling mesh for the whole road, not one a chunk: 1 draw call; scenery is pushed 1.2 m clear of it) and contact discs (one MultiMesh a chunk, fading with the haze). Net +4 draw calls.**

6. [x] **Lamp heads glow** (`_build_scenery`, the lamp's surfaces). At dusk and night the lamp head
   surface takes `emission = lamp_glow` in the scenery shader (pick the head's surface by its
   material colour, as `_recolor` does), so the halo has a source. Cost: none. Verify: night
   capture, each halo sits on a bright lamp head.
   - **Done: the lamp's tip is marked in vertex alpha (`_glow_tip`) and self-lit by `lamp_glow`.**

7. [x] **Bursts as streaks, not cubes** (`_build_fx`, `hit_fx`, `dodge_fx`, `catch_fx`,
   `shield_fx`). Replace the six burst/spark `CPUParticles3D` (they simulate on the main
   thread) with one pooled `MultiMesh` of quads whose motion is computed in the vertex shader
   from per-instance data (origin, velocity, birth time in `INSTANCE_CUSTOM`, colour in
   `COLOR`): `pos = origin + v·t + ½·g·t²`, stretched along `v` for a streak (write our own
   shader; Kart's `spark.gdshader` is the reference for the look, not code to copy). A burst
   writes 12-24 instances once; nothing runs per frame after. Keep the shards for the shield.
   Cost: −5 emitters' CPU simulation, one draw call instead of up to six. Verify: `prewarm`
   still compiles it before play; a hit reads as hot streaks and chunks breaking up.
   - **Done: `shaders/fx.gdshader`, a 64-slot pool (`burst`, `fx_instance`), premultiplied alpha so chunks and additive streaks share one draw; hidden while idle. Debris is capped at 17° toward the rider. Shards and speed streaks kept.**

8. [x] **Hand-lit handlebars** (`_build_rig`). The bars use engine-lit metallic and rubber
   `StandardMaterial3D` and are on screen all ride. Merge bar, grips, drops, stem and head into
   one vertex-coloured mesh (four `_part` meshes today: 7 draw calls) with a small unshaded
   shader: a fixed top-light gradient, a cool rim, the accent stem `#F26626`. Cost: −6 draw
   calls. Verify: the bars look the same or better in all four presets, darker at night.
   - **Done: `handlebar_mesh` + `shaders/bars.gdshader` (view-space top light, sheen band, cool rim, tinted by the look). 7 draw calls to 1.**

## P2: if there is time

9. [x] **Ball polish** (`shaders/ball.gdshader`). A contact shadow that tightens as a bouncing ball
   lands (`_draw_balls` already writes the darkness), a faint squash on landing (scale in the
   instance transform at the bounce, no new data), and the seams' rotation following the spin.
   Cost: negligible. Verify: a bouncing ball reads its height at a glance.
   - **Done: shadow tightens as a bouncing ball lands (`shadow_scale`), a 14% squash in its last 8 cm (`squash_for`). The seams already followed the spin (they're in the ball's own space).**

10. [ ] **Render scale 0.66** (`DodgeBall.RENDER_SCALE`). Kart measured 0.66 against 0.62 at under
    2 fps on the tablet. Measure Dodge with the tracker on at 0.62 and 0.66 for 60 s each; adopt
    only if it holds 58+. Sharper kerbs and lane dashes.
   - **Skipped: needs a 60 s tablet measurement with the tracker on; this pass was desktop only.**

11. [x] **Night street furniture.** Reflective cat's eyes on the centre dashes at night (in
    `road.gdshader`, lit by `headlight`, no geometry).
   - **Done: cat's eyes midway between the centre dashes, lit by the headlight.**

## Out of scope / rejected

- Engine glow, SSAO, shadows, real lights: full-screen passes and extra light passes measured
  too costly on the tablet (Kart: about 5 fps for one pass).
- MSAA 2× on the SubViewport: renders black on this PowerVR driver.
- New imported models: the Kenney kit plus procedural meshes cover it, and the APK is tight.
