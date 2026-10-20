# Tug of War: art bible

> **Status:** v1, 2026-10-19, from the graphics review of `games-polish` at 6ef6fab (code and
> the before captures). **Owner:** whoever changes the look. Change this file in the same commit
> as any change to the palette, the light, the bot, the crowd or the effects. **Sources of
> truth:** `TugWorld.gd`, `shaders/water.gdshader`, Dodge Ball's `tod/*.tres` and
> `shaders/sky.gdshader` (shared), `TugStatus` / `TugOfWar.look` (UI). **Target** marks what the
> code doesn't do yet; `GFX_POLISH.md` tracks the work.

All of it is procedural except the Kenney nature-kit trees, bushes and rocks (CC0, loaded from
`games/dodge_ball/models/`). The bots are plain material-and-animal names, nobody's character.

## 1. Identity

**The one rule:** *a summer fairground contest across a lazy river: you against a wind-up tin
robot, and the rope between you is the story.* When something is ambiguous, pick what makes the
rope, the flag and the bot's pose read faster.

| Pillar | Design test |
| --- | --- |
| **The rope is the stage** | Nothing crosses the line from the rider's fists to the bot. The flag's place on the rope reads from 1 m at a glance. |
| **A hand-made fairground** | Timber, rope, bunting, painted tin. Warm wood and saturated toy colours against cool water. Rounded, chunky, slightly toy-scaled. |
| **Effort shows in the world** | The bot braces, the crowd cheers, the rope tightens and sags with tension. Every state change shows in pose and light before any text. |

Distinct from Kart (no karts, no violet grade) and from Dodge (no road; warm and woody where
Dodge is cool and asphalt). Tug shares Dodge's sky and time-of-day presets, so the two must
diverge in the grade and the materials, not the sky.

## 2. Mood by state

| State | Look |
| --- | --- |
| Even | Calm river, the crowd bobbing, torches flickering. Flag mid-rope. |
| Winning | The bot leans forward and slides; the near crowd hops higher (`excitement`). |
| Telegraph | The bot's eyes flash amber, it braces (-10°); **Target:** its wind-up key spins fast, a puff of steam from its chimney. |
| Surge | Red eyes, -16° lean, a small rumble shake. **Target:** steam jets from the chimney. |
| Win | The bot topples into the river: splash, ripple ring, crowd jumps. |
| Lose | The camera is pulled in and dips toward the water: the water fills the view. |

## 3. Palette

| Role | Colour | Rule |
| --- | --- | --- |
| Deck timber | `#8C6138` planks, gaps `#2E1F14` | Warm, the brightest wood near the camera. **Target:** plank geometry or a procedural plank shader, never a magnified blurry texture. |
| Pilings, posts | `#4D331F` | Dark, so the pier ends frame the river. |
| Water deep / shallow | `#12405C` / `#29758C` | Cool: the river is the one big cool area. Sky shows at grazing angles. |
| Banks | `#4D8033` | **Target:** a sloped earth bank `#6B5233` with reeds, never a box edge. |
| Rope | `#C7A86B` / `#8C6B42` stripes | The lightest warm line on screen. |
| Flag | `#FF401F` | The only red; the bot's eyes may flash red in a surge. |
| Bot bodies | `BOT_COLORS` (rust, copper, tin, brass, iron, steel, zinc, chrome) | Metallic hues, matte painted tin (no real specular). |
| Crowd shirts | `CROWD_COLORS` | Saturated, but darker than the flag. |
| Torch flame | `#FF9933` | Warm emissive, brighter at dusk and night. |

**UI harmony.** The HUD is rope orange `#FF9F1C` on bark `#2A160B` (`TugOfWar.look`), YOU in the
gloves' blue `#5980D9` and BOT in the bot's body colour. Keep the rider's sleeves that blue, the
flag the only red, and the rope orange-tan so the meter and the world agree.

## 4. Lighting, materials and shading

- **Target: one hand light**, `framework/shaders/world_look.gdshaderinc`, as in Dodge Ball: every
  surface `unshaded, fog_disabled`, lit by `sun_light` per vertex and graded per pixel. Today the
  piers, banks, bot, crowd and hands are engine-lit per vertex with engine fog, and the water is
  lit by hand.
- **Tug's grade** (the `LOOK_*` defines, Target):

  | Define | Value |
  | --- | --- |
  | `LOOK_SAT` | 1.1 |
  | `LOOK_CONTRAST` | 1.04 |
  | `LOOK_GAIN` | `vec3(1.04, 1.0, 0.94)` (warm, sunlit timber) |
  | `LOOK_LIFT` | `vec3(0.03, 0.01, 0.0)` (bark-brown shadows, the UI's ink) |
  | `LOOK_VIGNETTE` | 0.3, tint `vec3(1.0, 0.9, 0.8)` |

- **Materials.** Wood: procedural planks (gaps, grain from one noise read, nail dots, darker and
  wetter toward the water). Tin (the bot): flat paint with a soft fake highlight band from the
  view (`pow(1 - N·V, 2)`), rivet dots, painted AO in vertex colours. Water: hand-lit, two
  scrolling noise reads, fresnel to the sky gradient, glitter only along the sun's path, foam
  where it meets pilings and banks. Cloth (flag, bunting): unshaded both sides, a vertex-shader
  flutter.
- **Shadows.** Blob shadows under the bot and the crowd (in their MultiMeshes), a darker water
  band under each pier. No shadow maps.

## 5. Shapes and proportions

- **The bot** (Target): a wind-up tin robot about 2.6 m tall on the deck (scale 1.3 today), a
  rounded barrel body, a dome head with a visor slot for the glowing eyes, mitten hands on the
  rope, a big wind-up key on its back and a chimney. Ears or horns alternate by rung. Today it is
  stacked boxes.
- **The crowd** (Target): toy-like fans, 1.6-1.9 m, a round head and a rounded body with arms
  that wave, as sprites or one mesh each, never faceless capsules.
- **The rider's hands** (Target): chunky work gloves in the UI blue, knuckles readable, the rope
  wrapped over them. Today they are 8-segment spheres.
- Proportions: the near pier 5 m wide, the river 8.4 m between pier ends, the far pier 7 m deep.

## 6. Environment

- **Layout:** the near pier (rider), the river across the whole view, the far pier with the bot
  and two torches, crowds either side of both piers, trees, then hills.
- **Dressing** (Target): bunting strung across the river above the rope's height (never across
  the rope's line), a striped tent and hay bales on the far bank, a scoreboard post, reeds and
  rocks along the waterline, lily pads drifting, string lights that glow at dusk and night.
- **Depth:** near (deck, hands) warm and detailed, mid (river, far pier, crowd) the story, far
  (trees, hills) hazed toward the sky. Keep the far pier's backdrop simpler than the bot.

## 7. VFX language

| Effect | Look |
| --- | --- |
| Splash | White droplets up and out, a ripple ring spreading; **Target:** droplets as short streaks, a foam disc that fades |
| Torches | **Target:** a flame card that flickers in the shader (today a sphere scaled per frame in GDScript) |
| Surge | **Target:** steam puffs from the bot's chimney (alpha, never additive) |
| Crowd cheer | Hops scale with `excitement` |

Additive only for flames, eyes and string lights. Water and steam are alpha blended.

## 8. Camera

First person at 1.6 m, pitched -9°, FOV 66. Pulled toward the far pier as the rider loses, with
a dip toward the water at the end, and a tiny shake in a surge or splash. No roll, no bob beyond
the pull rhythm on the fists.

## 9. Tablet budget (Gen 2, PowerVR GX6250, Compatibility; tracker only with Brace lean on)

| Item | Budget | Today (desktop) |
| --- | --- | --- |
| fps | 60 with the tracker on (`lean_2d`) | 59-62 measured (tracker off, 2026-10-03) |
| Render scale | 0.62 (`TugOfWar.RENDER_SCALE`) | 0.62 |
| Draw calls in play | ≤ 100 with the HUD (world ≤ 70) | 99 |
| Visible triangles | ≤ 100k | well under |
| Water per pixel | ≤ 3 noise reads | 2 |
| Per-frame GDScript | the rope's 22 segments and the bot's pose only; crowd, torches, flags and bunting move in shaders | the crowd re-places 120 instances at 20 Hz, torches scale every frame |
| Particles | the splash (48) only | as is |

Today the world is about 40 separate `MeshInstance3D` (hills, posts, the bot's parts, the hands),
each its own draw. Merge static ones into vertex-coloured meshes before adding dressing: each
draw costs main-thread driver time on the tablet.
