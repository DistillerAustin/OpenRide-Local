# Tug of War: UI polish punch list

From the UI and art-direction review of 2026-10-19, against `framework/ui/UI_STYLE.md` and Kart
Race's polish. "Before" captures: `tests/capture_ui_states.gd -- --game=tug_of_war`. Desktop:
95-97 draw calls in play, about 120 fps.

**Identity: a rustic riverside fairground.** Heavy, physical and a bit comic. Accent rope
orange `#FF9F1C`, ink bark brown `#2A160B`, badges leaning 0.12, display face upright (it's a
strength game: solid, not swooshy). The two teams have their own colours, not good and bad:
**YOU** in the rider's glove blue (`TugWorld`'s hands, about `#5B8CFF`) and **BOT** in the
current bot's body colour.

**Hero: who's winning the rope**, and by how much.

**Framework pieces to adopt:** `GameTheme` (`ui_theme()`, `hud_skin()`, `style_label`,
`badge_style`, `pop` / `slam` / `pulse`), the themed intro and pause screens, and the message
pop (round won, pulled in, surge).

## What works

- The 3D scene tells the story: the bot leans, the rope moves, and the crowd and the river set
  the place.
- Labels round to 5 W and change only on a change.
- The surge is telegraphed by sound and a message.

## P0: blocking

1. **The status widget is at the layout's limit.** With the longest texts ("YOU 1885 W",
   "Round 5 · 2-2 · Copper Badger", "Recover 12s") `TugStatus` is 848 px wide. The top bar
   leaves 850 px between the ride panel and the clock panel at a five-digit score, which a
   long ride reaches (about 2250 points a minute). Any growth, including the theme's face,
   overlaps the clock.
   - Add a Tug case to `tests/unit/hud_layout_test.gd`: `TugStatus` with those texts and a
     score of 99999. It must pass before and after the restyle.
   - Then free width: replace the text round line with pips (P1.3), and shorten the alert to
     one word.

   *Verify:* the new test passes. Widget width ≤ 800 px with the longest texts.

## P1: high impact

1. **Adopt the theme.** In `TugOfWar.gd`, add
   `static var look := GameTheme.new(Color("ff9f1c"), Color("2a160b"), 0.12)`, override
   `ui_theme()`, and call `hud.set_skin(look.hud_skin())` in `_on_prepare`. In `TugStatus`,
   use `look.panel_style()` and `look.style_label()`. Use `GameTheme.GOOD` and `BAD` for the
   message colours. *Verify:* captures. The intro, pause and HUD are rope orange with bark
   outlines.
2. **A hero tug meter** (`TugStatus`). Today a 380x26 bar and two 34 px labels carry the whole
   game (`tug_of_war_2_play.png`).
   - Watts at `HudTheme.MEDIUM` (56) in the display face either side, with "YOU" and the bot's
     name as 34 px captions under them, so the layout is two rows, not three.
   - The bar 420x40, filled from the centre towards the leader in that team's colour, not
     green and red. The marker is a rope knot: a circle with an ink ring.
   - The leader's watts `pop` (1.2) when the lead changes hands.

   Keep it within 800 px (P0.1). *Why:* red against green is the classic colour-blind failure
   and reads as right against wrong. Teams read as us against them, and the side of the bar
   carries the meaning too. *Verify:* play capture at 50%. Who's ahead is obvious in half a
   second.
3. **Round pips instead of "Round 2 · 1-0 · Rust Mule"**. Draw best-of-N circles: won rounds
   filled in the rider's blue, lost ones in the bot's colour, the current one with an accent
   outline. Then the bot's name. In ladder mode, show "RUNG 3" as a badge instead. *Verify:*
   mid capture after a round won (the pip fills and pops).
4. **Surge as a state, not a caption.** During `telegraph` and `surge`:
   - Show a BAD badge "SURGE!" in row 2, with `GameTheme.pulse(badge, true)`. Stop it at
     `surge_end`, and slam "HELD IT!" in GOOD if answered.
   - The marker's pulse is `TugStatus._process` calling `queue_redraw()` every frame. Replace
     it with a modulate tween on a separate marker node, or redraw at most 10 times a second
     (budget rule).

   *Verify:* the `--play=60` capture shows a surge. The badge breathes and stops.
5. **Round results with weight.** "Round won!" and "Pulled in!" are plain messages. With the
   skin they pop already. Also `GameTheme.pop(hud.score, 1.2)` on the +1000, and slam a gold
   "+1000" chip next to the score. `_flash_rect` (blue) already covers the loss: keep it.

## P2: nice

1. Copy: "Keep pedaling" → "Keep pedalling" (British, matching Safe Cracker). Endless how-to:
   "Pull harder than the bot. Win round after round until time is up" wraps to an orphan "is
   up" on the intro card. Use "Out-pull the bot, round after round".
2. Recovery: "Recover 12s" is a 34 px caption. Show a calm ink badge "REST 12" with the next
   bot's name under it. The 4 s message already names the next bot and its watts.
3. Ladder: when a rung is won, slam "NEXT: <bot> <W> W" in the bot's colour.
4. The intro card could show the bot's portrait (`intro_visual()`): a small drawn head in the
   bot's colour, like Dodge's mode badge.

## Out of scope

Bot watts, surge tuning and the 3D world.
