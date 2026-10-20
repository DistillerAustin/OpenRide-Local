# Dodge Ball: art bible

> **Status:** v1, 2026-10-19, from the graphics review of `games-polish` at 6ef6fab (code and
> the before captures). **Owner:** whoever changes the look. Change this file in the same commit
> as any change to the palette, the light, the scenery or the effects. **Sources of truth:**
> `DodgeWorld.gd` (world, FX), `shaders/*.gdshader`, `tod/*.tres` (written by
> `tod/make_presets.py`: edit the script, not the .tres), `DodgeStatus.look` (UI). Where this
> file says **Target**, the code doesn't do it yet; `GFX_POLISH.md` tracks the work.

Everything is original or CC0 (the Kenney nature and road kits, recoloured). No franchise's
names, characters, courts or logos.

## 1. Identity

**The one rule:** *an open road through parkland at speed, and the balls are the only hot
colour in it.* When anything is ambiguous, pick what makes an incoming ball read sooner.

| Pillar | Design test |
| --- | --- |
| **The ball reads first** | Red (Dodge) and gold (Catch) belong to the balls and their warnings. No scenery, sky or effect may be as saturated or as warm. |
| **Speed you feel from a still bike** | Movement cues (dashes, kerbs, lamp posts, roadside rhythm, streaks) beat static detail. The world never rolls or bobs beyond the rider's own lean. |
| **Sports-day bright** | Clean, cool, sunny greens and blues; chunky low-poly shapes; one hand light for everything. Not gritty, not realistic. |

Distinct from Kart Race: no toy kart, no violet grade, no warm late-afternoon bias. Dodge is
cooler and crisper: a morning-fresh park road.

## 2. Mood per time of day (`tod/*.tres`)

| Preset | Target mood | Sun (elev, azim) | Sky top / horizon | Haze | Notes |
| --- | --- | --- | --- | --- | --- |
| day (hero) | Fresh, high clarity | 52°, 150° (behind) | `#3375EB` / `#B8D6F5` | `#BDD6F2`, 0.0055 | The look every other preset is judged against |
| dawn | Soft, pastel, quiet | 9°, -35° | lilac / peach | warm, 0.012 | **Target:** no stars, a sun disc 1/3 of today's |
| dusk | Warm, glowing | 5°, 30° | rose / orange | warm, 0.012 | **Target:** stars off (0.3 today reads as noise on a pink sky), smaller disc |
| night | Cool, safe, lamp-lit | moon 38°, 25° | `#03040D` / `#0F142B` | `#0A0D1A`, 0.013 | Lamps and the headlight carry the road; balls self-light (`ball_glow`) |

The sun's disc today is about 25° across at dawn and dusk (`sky.gdshader` fills
`dot(dir, sun) > 1 - sun_size * 0.6`, a 13° radius at 0.045), so it covers a third of the sky
behind the trees. **Target:** a 3-4° disc, with the glow carried by the halo.

## 3. Palette

| Role | Day | Rule |
| --- | --- | --- |
| Asphalt | `#292930` ±15% grain | Always the darkest large value. Never blotchy at the near edge. |
| Lines, kerb | `#F2EDD9`; kerb `#D93330` / `#EBEBEB` | The kerb's red is darker and less saturated than any ball. |
| Verge grass a / b | `#3D732E` / `#4D8533` | Mown stripes 9 m, a dirt shoulder `#6B5C42`. |
| Foliage | `#528F33`, `#427A2B`, `#295C33`, `#61993B` | Cool greens. Trunks `#6B4A30`. |
| Rock | `#80807A` | **Target:** lighter top, darker base (painted AO), never a flat slab. |
| Lamp posts | city-kit colours, matte | **Target:** the lamp head self-lit at dusk and night. |
| Dodge balls | `#FA3829` plain, `#D92673` curve, `#FF6B1A` double | The warmest, most saturated things on screen. |
| Catch balls | `#FFCC2E`, `#FF9E1A`, `#F2E659` | Shimmer; never used by scenery. |
| Shield, dodge sparks | cyan `#4DBFFF` | Matches the UI accent. |

**UI harmony.** The HUD's accent is sky cyan `#38B6FF` on navy ink `#0E1B3D`
(`DodgeStatus.look`). The world's cyan (the shield, dodge sparks, the night sky's moonlight)
must stay that hue. Red and gold are never chrome.

## 4. Lighting, materials and shading

- **One hand light** (Target): every world surface uses `framework/shaders/world_look.gdshaderinc`
  (`sun_light`, `haze`, `grade`), `unshaded, fog_disabled`. Today the road and verges light
  themselves but the trees, rocks, lamps and cones use the engine's per-vertex light and engine
  fog, so their haze doesn't match the road's (see the far trees in `dodge_day.png`).
- **Dodge's grade** (Target, the `LOOK_*` defines, in every world shader):

  | Define | Value |
  | --- | --- |
  | `LOOK_SAT` | 1.08 |
  | `LOOK_CONTRAST` | 1.05 |
  | `LOOK_GAIN` | `vec3(0.99, 1.0, 1.03)` (slightly cool) |
  | `LOOK_LIFT` | `vec3(0.0, 0.01, 0.03)` (navy shadows, the UI's ink) |
  | `LOOK_VIGNETTE` | 0.25, tint `vec3(0.85, 0.9, 1.05)` |

  The sky repeats it without the vignette. Don't fork it per material.
- **Surfaces.** Road and verges: procedural in road space (`scroll`), max 3 noise reads. Scenery:
  per-vertex light, matte, painted AO by height (darker at the foot), sway on foliage by vertex
  height. Balls: per-pixel toon (`ball.gdshader`) with a rim, two seams and the near-glow; they
  are the only per-pixel-lit objects. Handlebars: hand-lit matte metal with a fixed rim, never
  engine specular.
- **Shadows.** Blob shadows only (the balls). Trees and lamps get a painted dark disc at their
  foot (one quad in the scenery MultiMesh), never shadow maps.
- **Night.** No engine lights: lamp pools and the headlight are added light in `road.gdshader`;
  lamp heads and their halos glow.

## 5. Shapes and proportions

- Scenery: the Kenney low-poly kit, faceted and chunky. Trees 5-9 m (pines ×1.3), bushes 1.2-2.2 m,
  rocks 0.8-1.8 m. Rounded masses for nature; posts and cones for the road.
- Balls: radius `DodgeBallLogic.BALL_RADIUS`, 16×8 segments, two seams. Silhouette is a perfect
  disc: never add detail that breaks it.
- The road: 12 m wide (`ROAD_HALF` 6), lane dashes 3 m on, 6 m off; kerbs 1 m blocks.

## 6. Environment

- **Construction:** one road plane, two verge planes and three 50 m scenery chunks that leapfrog
  (`CHUNK_LEN`, `CHUNKS`), each a few MultiMeshes. Nothing moves per instance.
- **Bands:** 0-4 m off the road: kerb, shoulder, cones, lamp posts every 25 m (staggered). 4-32 m:
  trees and bushes. **Target** 32 m to the horizon: a band of low rolling hills and a distant
  tree line (one hazed mesh), so the verge planes' far edge never shows as a flat line.
- **Rhythm:** something passes at the edge of vision at least every 2 s at 60 rpm (9 m/s): lamps
  at 25 m, plus **Target** fence posts or hedges at 4-6 m spacing.

## 7. VFX language

| Effect | Look |
| --- | --- |
| Hit | Ball-coloured chunks burst ahead of the bars, a sideways nudge, the red edge flash (`screen_fx`) |
| Clean dodge | Cyan sparks where the ball passed, `+n` popup |
| Catch | Gold sparks at the bars, gold popup |
| Shield hit | Cyan shards off the shield, a flash |
| Speed | White streaks round the edge of view from about 90 rpm, FOV 62→72 |
| Warning | Additive chevron strip in the arrival lane, brightening with urgency |

Rules: additive only in cyan, gold or the ball's colour; debris never flies at the rider's face;
nothing crosses the centre of the road. **Target:** sparks as velocity streaks (Kart's
`spark.gdshader` idea, not its code) instead of round blobs and cubes.

## 8. Camera

First person at 1.45 m, pitched -7°, FOV 62→72 with speed, near 0.08, far 170. Sideways only
with the rider's lean, roll at most 3° (off with the option), hit shake a sideways nudge. Never
add bob, pitch or rotation for effect.

## 9. Tablet budget (Gen 2, PowerVR GX6250, Compatibility, tracker ON: `lean_x`)

| Item | Budget | Today (desktop) |
| --- | --- | --- |
| fps | 60 with the tracker on | 55-60 measured at 0.67 before the HUD fix |
| Render scale | 0.62 (`DodgeBall.RENDER_SCALE`); 0.66 only after a tablet measurement | 0.62 |
| Draw calls in play | ≤ 110 with the HUD (world ≤ 85) | 101-113 |
| Visible triangles | ≤ 120k | well under |
| Per pixel on road/verge/sky | ≤ 3 noise reads, no `sin()` hashing, no loops | 2-3 |
| Full-screen passes | only `screen_fx`, hidden while idle | as is |
| Per-frame GDScript | ball MultiMesh writes and the chunk leapfrog only; motion in shaders or tweens | as is |
| Particles | ≤ 120 alive; prefer one pooled MultiMesh to more `CPUParticles3D` (they simulate on the main thread) | 7 emitters, ≤ 140 |
| MSAA | off (2× halved the frame rate; black on Kart's SubViewport) | off |

The tablet with the tracker is CPU-bound on the main thread (Kart Race, docs/GAMES.md): new
materials and mesh instances cost driver time, so merge into existing MultiMeshes, and put
detail in shaders before geometry.
