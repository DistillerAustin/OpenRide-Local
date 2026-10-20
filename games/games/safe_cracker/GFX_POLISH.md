# Safe Cracker: graphics polish punch list

> **Status:** every item done on branch `gfx-safe` (2026-10-20) except the cabin's tilt (item 6);
> the notes under each say how. In play: 51 draw calls with the HUD (86 before).

From the graphics review of 2026-10-19 against `ART_BIBLE.md` (this folder) and Kart Race's
polish. UI is out of scope (`UI_POLISH.md`: the dial's type, the target plate, the banner), and
so are gameplay and tuning.

**Before captures** (desktop, 1280×720, with the HUD: the capture has no `--nohud`, and the HUD
sits clear of the safe), in the review's scratchpad `gfx/before/`:
`safe_{office,bank,museum,cabin,lab,library}.png` (every place), `safe_{hidden,unpowered,alarm,
door_half,on_target,tumbler_pop,cracked}.png` (every state), and
`ui_states/safe_cracker_{1..6}_*.png` (86-90 draw calls in play). Retake after each item:

```sh
$GODOT_BIN --path games -s res://tests/capture_safe.gd -- --out=DIR
$GODOT_BIN --path games -s res://tests/capture_ui_states.gd -- --game=safe_cracker --out=DIR
```

`safe_scene_test` checks the layout (no overlaps, the needle's sweep, the status budget): keep it
and the full suite green, and keep the dial's geometry (`SafeDial.R`, `TARGET_PLATE`,
`light_at`) where it is. The canvas is full 1080p with no SubViewport, so the GPU cost is
full-screen blended layers; the CPU cost is redrawing big `_draw()` lists.

## What works (keep)

- The dial reads instantly; the brass plate, the lights and the reading are well placed.
- Six distinct rooms from palettes and a few shapes; the vignette pulls the eye to the safe.
- Static layers redraw only on a change.

## P0: a safe with weight

1. **Split the static door from the live dial** (`SafeDial._draw`, `_draw_door`). Today every
   needle step redraws the whole door (face, rivets, bezel, 21 ticks, the plate) with the
   needle. Move the door's static art into a new `SafeDoor` Node2D under `SafeRoot`, drawn only
   on a place change or a door-swing step, and leave `SafeDial` with the needle, target band,
   hold ring, lights and text. Cost: fewer canvas commands rebuilt per reading change (CPU),
   +1 draw at most. Verify: `safe_scene_test` passes unchanged; the captures are identical.
   This makes room for item 2's detail without a per-step cost.
   **Done** (2026-10-20), further than asked: `SafeDoor` holds the static door; `SafeDial` keeps
   only the bands, ring, lights and the target's number; the reading's number is its own
   text-only layer; the numerals are a static layer; the needle is a static drawing turned by
   `rotation`, so a needle step redraws nothing. Every shape is batched by `SafeMesh`.
2. **Steel, bevels and hardware** (`SafeBody._draw`, the new `SafeDoor._draw`). Flat fills read as
   a gauge panel. Draw:
   - a top-lit value gradient on the body and the door (a vertical `draw_polygon` with per-vertex
     colours: no texture), a 3 px light bevel on the top and left edges and a dark one on the
     bottom and right;
   - two hinges on the door's left (hinge) edge; a compact four-spoke handle wheel (radius
     about 45) under the tumbler lights' column at about (371, 245), clear of `light_at` for six
     tumblers (y ±145) and of the bezel (R + 40); a column of five bolt ends along the door's
     right edge; short feet under the body;
   - brushed streaks: 30-40 thin horizontal lines at 4-6% white, seeded per place;
   - the drop shadow as a soft `StyleBoxFlat` shadow (`shadow_size` 40, `shadow_offset`) cast
     away from the room's key light (item 3), instead of today's hard offset rect.
   Cost: a few hundred vertices, redrawn only on a place change. Verify: every place capture
   reads as a heavy safe; the layout test still passes.
   **Done:** all of it, plus a machined groove, recessed light sockets, bolt keepers and the
   door's dark seam; the shadow is a soft mesh band (not a StyleBox), so it batches with the body.
3. **One key light per room** (`SafePlaces.draw_room`, `_office`, `_cabin`, `SafeCracker._vignette`).
   The lamp glows are concentric circles that band. Give each place a key light (ART_BIBLE §3:
   position, colour, radius) drawn as one additive `TextureRect` with a smooth radial
   `GradientTexture2D` (256 px, linear filtering), behind the safe, plus a soft bright rim on
   the safe's lit side (in item 2's drawing). Fold the vignette into the same texture's alpha if
   a third full-screen layer costs frames on the bike. Cost: +1 draw, one full-screen additive
   layer: measure. Verify: no banding; each room has a light direction that the safe's shading
   agrees with.
   **Done, differently:** the pool is a many-ring vertex-colour glow in the room's own batch
   (`SafeMesh.glow`), not a TextureRect: no extra draw call, no texture, and it fills only the
   light's area, not the screen. The vignette stays (its curve smoothed, no visible edge).
4. **The door swings open** (`SafeDial._draw`'s squash transform, `SafeBody._draw`'s vault). Today
   the door squashes horizontally. Draw it as a perspective swing about the hinge: the far edge
   moves toward the hinge and grows taller as it turns toward the viewer, with a 24-30 px
   thickness band (darker steel) showing on its open side, the dial drawn with the same
   transform (a skewed `Transform2D`). The vault: two inner side walls as darker trapezoids, a
   shelf, gold bars with a lit top face and a front face, and a warm gradient spill out of the
   opening as `door_open` rises. Cost: the same redraw count as today's swing. Verify:
   `safe_door_half.png` and `safe_cracked.png` read as a heavy door opening onto a lit vault.
   **Done, cheaper than asked:** `safe_door.gdshader` turns every door layer about the hinge in
   perspective (to 72°, short of edge-on) from one uniform, so the swing redraws nothing; the
   thickness band is marked by UV depth. Plus a shelf of coin stacks; the capture adds
   `safe_open.png` (the door all the way open).

## P1: rooms with a story

5. **Place dressing** (the six `SafePlaces._<place>` functions). Per ART_BIBLE §6: blind stripes
   across the office wall (a few skewed translucent bands), a vault-door rim behind the bank
   safe, rope barriers in the museum, planks and a porthole sea line in the cabin, a tiled lab
   floor, a ladder in the library. Every floor gets gentle one-point perspective (boards or tile
   lines converging toward the safe). Props stay outside the safe's footprint. Cost: redrawn
   only on a place change. Verify: each place capture is recognisable with the safe covering the
   middle.
   **Done**, plus a certificate (office), deposit boxes and a strip light (bank), wainscot,
   spotlight cones and a pedestal vase (museum), ribs and a lantern bracket (cabin), wall tiles,
   a fume hood and fluorescent tubes (lab), a rug and a reading-lamp table (library). The bank
   fell from 258 draw calls to 50 and the lab from 125 to 51 (with the HUD).
6. **Slow ambient motion, not redraws.** Rain on the office window (a `canvas_item` shader on
   one `ColorRect`, scrolling streaks from `TIME`), a lantern sway in the cabin (a rotation tween
   on a small Node2D), dust motes in the key light (one `CPUParticles2D`, 16 particles, slow, 3-6
   px, alpha 0.25), a flask shimmer in the lab (a shader on the flasks' rects). Each lives in its
   place and is hidden in the others. Cost: +1-2 draws per place; no per-frame `queue_redraw`.
   Verify: a 10 s look at each place shows gentle life; fps unchanged on the desktop.
   **Done** (`SafeBackdrop`); the porthole's sea line moves too (a shader). Skipped: the cabin's
   whole-room tilt (the bible allows it off; a moving room is motion a recovery ride can do
   without).
7. **The next light's pulse off the redraw path** (`SafeDial.refresh`'s `pulse` key). The
   breathing outline forces a full dial redraw 6 times a second. Draw that one outline in a tiny
   child node and breathe it with a modulate tween. Cost: a CPU saving. Verify: the
   `safe_tumbler_pop.png` look is unchanged.
   **Done:** `NextLight`, a looping modulate tween, 1 s each way (never faster than the bible's
   twice a second).

## P2: if there is time

8. **Dial glass and bezel** (`SafeDoor`). A soft diagonal glass highlight across the dial face
   (one arc band at 10-15% white, clear of the numerals' centres) and a knurled bezel ring
   (short radial ticks on `R + 24`). Cost: negligible.
   **Done**, with a glint on the glass while on target (`Cover`).
9. **Tumbler bolts.** Each clicked tumbler slides one bolt end back on the door's edge (a tween
   on a small node per bolt), so progress shows on the safe itself.
   **Done:** five bolts in one `Bolts` layer, eased over 0.45 s (a small redraw only while one
   slides); they slide out again for the next safe.
10. **Crack sparkle and alarm wash.** 12-20 gold sparkles rising from the vault on a crack (one
    `CPUParticles2D` burst), and a red additive gradient from the room's side while the alarm is
    on (a modulate tween). Cost: +2 draws while active.
    **Done:** 18 additive sparkles 0.45 s into the swing; the wash breathes with the safe's red.
11. **Lab accent.** The lab's green accent is close to the reading's on-target green; shift it to
    a brass-teal (`#5CC7B0`) in `PLACES`, or keep it off the dial (the target plate's edge and
    the lights take the accent).
    **Done**, as `#4FB4C8`: `#5CC7B0` is only 0.18 from GOOD in RGB; `safe_gfx_test` holds the
    lab's accent more than 0.2 away.

## Out of scope / rejected

- `Light2D` and `LightOccluder2D`: every lit canvas item draws again per light; drawn gradients
  give the same noir pools for one draw.
- A 3D safe: the 2D picture is clear, cheap and redraws only on change; 3D would bring a
  SubViewport and a render scale for no readability gain.
- Bitmap textures for the steel or rooms: procedural drawing keeps the APK small and every
  place consistent.
