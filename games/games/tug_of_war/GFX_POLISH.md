# Tug of War: graphics polish punch list

From the graphics review of 2026-10-19 against `ART_BIBLE.md` (this folder) and Kart Race's
polish. UI is out of scope (`UI_POLISH.md`), and so are gameplay and tuning.

**Before captures** (desktop, 1280×720, no HUD), in the review's scratchpad `gfx/before/`:
`tug_{day_even,day_winning,dusk_losing_telegraph,night_surge,dawn_even}.png`, the bot's fall
`tug_fall_{18,42,60}.png`, the rider's `tug_lose_{40,60,78}.png`, and with the HUD
`ui_states/tug_of_war_{1..6}_*.png` (99 draw calls in play). Retake after each item:

```sh
$GODOT_BIN --path games -s res://tests/capture_tug.gd -- --out=DIR --nohud
$GODOT_BIN --path games -s res://tests/capture_ui_states.gd -- --game=tug_of_war --out=DIR
```

Costs are estimates for the tablet; ±3 fps is noise, so "measure" items need a run on the bike
with Brace lean on (the tracker runs only then). Keep `tug_logic_test`, `tug_status_layout_test` and
the full suite green.

**Order matters:** item 1 frees the draw calls the dressing spends. Dodge Ball's P0.1 adds
`dodge_ball/shaders/scenery.gdshader`; Tug may reuse it (it already shares Dodge's sky, models and
presets) or own a copy. Either way both include `framework/shaders/world_look.gdshaderinc`.

## What works (keep)

- The composition: the rope from the fists to the bot down the centre, the flag readable.
- The fall and the pull-in tell the result without text.
- The river's colour and the far hills' haze.

## P0: the look's foundation

1. **Bake the statics, one hand light** (`TugWorld._build_river_and_banks`, `_build_piers`,
   `_mat`, `_box`). About 40 `MeshInstance3D`, each its own draw and engine-lit. Build the banks,
   hills, pilings, torch posts and both pier decks' frames into one or two vertex-coloured
   `ArrayMesh`es (painted AO: darker at the waterline and under the deck) with a scenery shader
   on the shared include (Tug's `LOOK_*`, ART_BIBLE §4). `KartMeshKit` (`add`, `commit`, `box`,
   `blob`, `lathe`, `tube`) can be called as-is; don't edit it from here (Kart is in flight on
   another branch). Light everything through one look dictionary in `set_time_of_day` with
   `WorldLook.apply` (the water and sky too). Cost: about −25 draw calls. Verify: the before and
   after day captures match in layout; draw calls in play drop to about 75.
2. **The deck** (`_build_piers`, `_plank_texture`). The 64×64 plank texture is magnified across
   the bottom third of the screen into blurry stripes. Replace it with `shaders/deck.gdshader`
   in world space: planks 0.18 m wide along z, dark gaps, grain from one `vnoise` read stretched
   along the plank, a per-plank tone from a second read at the plank index, nail dots at the
   joists, darker and wetter in the last 0.6 m before the water. Cost: 2 noise reads over about
   a third of the screen, about +12 ALU a pixel: measure. Verify: crisp planks in the near
   field of `tug_day_even.png`; nothing shimmers.
3. **The water** (`shaders/water.gdshader`). The sparkle is white confetti everywhere, and the
   bank meets the water in a ruler-straight box edge.
   - Glitter only along the sun's path: weight the sparkle by
     `pow(max(dot(reflect(-view, n), sun_dir), 0), 24)` with `n` perturbed by the two ripple
     reads, so it lies in a band toward the sun (and the moon at night), and fades elsewhere.
   - Fresnel to a two-colour sky (`sky_top` overhead, `sky_horizon` at grazing) instead of one
     tint.
   - Foam and shade: a soft white band where the water meets the banks (by |z| from the bank
     lines, broken by noise) and around each piling; darker under each pier's deck.
   - The banks: replace the box edges with a sloped earth strip and a row of reeds (one
     MultiMesh of crossed cards, swaying in the vertex shader) and a few shore rocks.
   - Cost: the same 2 reads, about +10 ALU; reeds +1 draw. Verify: the river in every preset
     glitters toward the sun, the shoreline is soft.
4. **A real bot** (`_build_bot`). Stacked boxes today. Build a wind-up tin robot (ART_BIBLE §5)
   as one vertex-coloured mesh from `lathe` and `blob` shapes (a barrel body, a dome head with a
   visor, mitten hands, a chimney, a wind-up key, rivets as paint), with its body colour from a
   shader uniform (`set_bot` sets it: no new material per rung). Keep the ears and horns as two
   small extra meshes toggled by visibility. The eyes stay a separate emissive material (their
   colour animates). A tin highlight band (`pow(1 - N·V, 2)`) and painted AO. The wind-up key
   spins in the vertex shader (a vertex-colour weight marks the key; its speed is a uniform set
   per state: slow, fast on a telegraph). Cost: about 13 draws down to 4, under 3k triangles.
   Verify: `tug_night_surge.png` and `tug_dusk_losing_telegraph.png` read the bot's state from
   its pose, eyes and key.

## P1: life

5. **The crowd on the GPU** (`_build_crowd`, `_place_crowd`, `_animate_crowd`). The crowd is
   faceless capsules, re-placed 120 instances at 20 Hz from GDScript. Make it one MultiMesh of
   upright quads cut from a generated two-frame sprite (body, head, waving arms), billboarded
   about the vertical axis and bobbing on per-instance phase in the vertex shader, with
   `excite` as a uniform set from `excitement` (Kart's crowd shows the technique; draw our own
   sprite in code). Cost: −1 draw, and the 20 Hz GDScript loop is gone: measure the CPU win
   with the tracker on. Verify: the cheering capture (`tug_day_winning.png`) shows arms waving.
6. **Gloved hands on the rope** (`_build_rig`). Two 8-segment spheres and cuffs: replace with one
   mesh (blob fingers, a thumb, the cuff in the UI blue `#5980D9`), the rope's end wrapped over
   the palms, hand-lit with a fixed key light so they never go flat at night. Cost: 4 draws
   down to 1. Verify: the bottom of every capture shows readable fists.
7. **Torches and string lights** (`update_view`'s torch loop, `_build_piers`). Swap the flame
   spheres for one additive flame card per torch, flickering from `TIME` in the shader, with a
   soft glow halo. Add a string of bulbs from the far torches out over the far bank (one mesh,
   emissive bulbs via vertex colour, brighter with `lamp_glow`). Cost: the per-frame torch
   loop goes; +1 draw for the string. Verify: dusk and night captures.
8. **Bunting and the flag** (`_build_rope`). A bunting line across the river above the rope
   (triangles in alternating crowd colours, one mesh, flutter in the vertex shader), and the
   pennant waving in its shader instead of its node rotation. The rope gets a twisted-strand
   stripe from its UV (no texture). Cost: +1 draw. Verify: the even capture has movement
   above the river, and the rope reads as rope.

## P2: if there is time

9. **Splash** (`_build_fx`, `splash_at`). Droplets as short velocity streaks and a foam disc
   that spreads and fades (a quad with a ring shader in place of the torus). Cost: the same.
10. **Fairground set dressing.** A striped tent and hay bales behind the far crowd, lily pads
    drifting on the river (a MultiMesh moved by `TIME` in the shader). Cost: +2 draws.
11. **Surge steam.** Three alpha puffs from the chimney in a surge, from a tiny pooled MultiMesh
    (no `CPUParticles3D`).

## Out of scope / rejected

- Real lights for the torches, engine fog or glow: extra passes the tablet can't pay for.
- Importing a robot or crowd model: everything here is procedural, original and small.
