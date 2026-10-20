# Safe Cracker: art bible

> **Status:** v1, 2026-10-19, from the graphics review of `games-polish` at 6ef6fab (code and
> the before captures). **Owner:** whoever changes the look. Change this file in the same commit
> as any change to the places, the safe, the dial's drawing or the effects. **Sources of truth:**
> `SafePlaces.gd` (rooms and palettes), `SafeBody.gd` (the body and the vault), `SafeDial.gd`
> (door and dial), `SafeCracker._vignette`, `SafeCracker.look` (UI). **Target** marks what the
> code doesn't do yet; `GFX_POLISH.md` tracks the work.

Everything is drawn in code. The six places are plain descriptions; no film, game or brand is
referenced, and nothing on the safe carries a maker's name.

## 1. Identity

**The one rule:** *one heavy steel safe in a pool of light, in a room that tells you where you
broke in.* When something is ambiguous, pick what makes the dial and the safe's weight read.

| Pillar | Design test |
| --- | --- |
| **The dial is the hero** | Highest contrast and sharpest edges on screen. Nothing in the room competes with its brightness or its brass. |
| **Weight and craft** | The safe is thick riveted steel with bevels, hinges, a handle and bolts. Every shape has an edge highlight and a shadow; nothing is a flat panel. |
| **Noir light** | One key light per room (lamp, window, spotlight) and deep shadow elsewhere. Warm brass against cool dark. Calm: a recovery ride, so motion is slow and small. |

The 2D flat-vector style stays: clean shapes, no outlines on the room, soft gradients, a few
crisp highlights. Not painterly, not photographic.

## 2. Mood by state

| State | Look |
| --- | --- |
| Turning | The room still and dim; the lamp's pool on the safe; dust in the light (Target). |
| On target | The reading turns green; **Target:** the dial's glass catches a glint. |
| Tumbler clicks | The newest brass light pops; **Target:** a bolt on the door's edge slides back. |
| Alarm | The safe glows red at its edge (`SafeDial` alarm rect) and the door pulses. **Target:** a red wash over the room from one side, as if a light came on. |
| Cracked | The door swings open on the gold. **Target:** a real swing with the door's thickness, a warm spill of light out of the vault and a few sparkles. |
| Next safe | The safe slides in on a new room. |

## 3. Palette per place (`SafePlaces.PLACES`)

| Place | Wall / lower wall | Floor | Safe | Accent | Key light (Target) |
| --- | --- | --- | --- | --- | --- |
| Night office | `#1A2B38` / `#0F1A24` | `#1A1412` | `#575E66` | `#F2BF59` | Desk lamp right, warm; blind stripes from a moonlit window left |
| Bank vault | `#5C6169` / `#3D424A` | `#29292E` | `#80858C` | `#D9A640` | Cold overhead strip, top |
| Museum hall | `#9E8F75` / `#80705C` | `#544033` | `#404D5C` | `#E6CC80` | Two picture spotlights, warm |
| Ship's cabin | `#614026` / `#472E1C` | `#332117` | `#384D47` | `#E6B34D` | Swinging lantern right; sea light through the porthole |
| Laboratory | `#9EBDB3` / `#809E94` | `#4D5C5C` | `#B3B8BD` | `#66E699` | Cool fluorescent top; flask glow |
| Old library | `#4D3024` / `#331F17` | `#241712` | `#473D4D` | `#E6B84D` | A reading lamp, warm, low |

Rules:
- The safe is always a mid value against its wall: lighter on dark rooms, darker on the light
  ones (museum, lab). Its body never matches the wall's value within 15%.
- The accent (brass) appears on the dial's target plate, the tumbler lights and the room's key
  prop only.
- Shadow colour is the room's lower wall darkened, never neutral black; the vignette uses the
  UI's soot `#14110D`.

**UI harmony.** The HUD is brass `#E8B04A` on soot `#14110D` (`SafeCracker.look`). Each place's
accent is a brass or a lab green; the lab's green accent must not read as the reading's
"on target" green (`GameTheme.GOOD`): **Target:** shift the lab accent to a brass-teal or keep
it off the dial.

## 4. Light, materials and drawing

- **One key light per room**, drawn, not computed: a large soft radial gradient (a
  `GradientTexture2D`, drawn once per place) added over the wall and the safe from the light's
  side, and a soft shadow of the safe cast away from it on the wall and floor. No `Light2D`
  (each lit item would draw again). Today the lamp glows are concentric circles that band.
- **Steel** (Target): the body and door get a top-to-bottom value gradient (light from above), a
  1-2 px bright bevel on the lit edges and a dark bevel on the far edges, brushed streaks at low
  contrast, rivets with a highlight dot. Drawn shapes or one `canvas_item` shader on the door
  and body polygons; either way redrawn only on a place change.
- **Glass** (Target): a soft diagonal highlight over the dial face (one arc band, 10-15%
  white), never over the numbers' centres.
- **Gold:** bars with a top face and a front face (two values), a soft warm glow over the stack
  once the door opens.
- Today: flat fills with a single lighter border, which reads as a gauge panel.

## 5. Shapes and proportions

- **The safe** (Target): body 980 × 740 (today), a door inset 50 px with a visible 24-30 px
  thickness on its hinge side when it opens, two hinges on the left, a compact four-spoke
  handle wheel under the tumbler lights, a column of bolt ends along the door's right edge (they slide
  back as tumblers click), short feet. Rounded corners 22-34 px. The dial stays centred where it
  is (`SafeDial.R` 262), so the layout tests hold.
- **The rooms:** the floor line at y 905; props stay outside the safe's footprint (x 470-1450)
  except where they pass behind it. Perspective is a gentle one-point floor (boards or tiles
  converging toward the safe), never a tilted wall.

## 6. Environment per place (Target)

- **Office:** venetian blind stripes of moonlight across the wall from the window; rain
  streaking down the window (a scrolling shader on that rect); a desk lamp's warm pool.
- **Bank:** a round vault door edge on the wall behind, steel panel seams, bars.
- **Museum:** the two framed pictures under spotlights, a rope barrier on brass posts.
- **Cabin:** timber planks, the porthole with a moving sea line, the lantern swaying slowly
  (a rotation tween), a very slow tilt of the whole room (≤ 1°, off if it reads as motion).
- **Lab:** shelves of flasks with a slow bubble shimmer, tiled floor, a fume-hood outline.
- **Library:** shelves with spines, a rolling ladder, a reading lamp, dust motes in its beam.

## 7. VFX language

| Effect | Look |
| --- | --- |
| Tumbler click | The newest light pops (today); a bolt slides (Target) |
| Alarm | A red edge glow on the safe, breathing; a red side wash (Target) |
| Crack | The swing, the warm spill, 12-20 gold sparkles rising (Target: one `CPUParticles2D` burst) |
| Ambient | Dust motes in the key light, 12-20 slow particles (Target), rain on the office window |

All slow and soft: this is a recovery game. Nothing flashes faster than twice a second.

## 8. Camera

None: a fixed 1920 × 1080 canvas, the safe centred at `BODY_HOME`. The only motion is the safe
sliding in and its door. Never shake the view.

## 9. Tablet budget (Gen 2, PowerVR GX6250, Compatibility, tracker OFF)

| Item | Budget | Today (desktop) |
| --- | --- | --- |
| fps | 60 | not measured on the bike for the graphics |
| Draw calls in play | ≤ 100 with the HUD | 86-90 |
| Redraws | the room and body only on a place change; the dial only on a shown change (`SafeDial.refresh`) | as is |
| Animated parts | shaders (`TIME`) or tweens on a node's transform or modulate, never a `queue_redraw` per frame | the next light's pulse redraws the dial at 6 Hz |
| Full-screen layers | the room, one light texture, the vignette: at most 3 full-screen blended layers | 2 (room, vignette) |
| Particles | ≤ 40 alive (`CPUParticles2D`) | none |

It runs at full 1080p (no SubViewport), so full-screen alpha layers are the main GPU cost: merge
the key light and the vignette into one texture per place if a third layer costs frames.
