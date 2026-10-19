# Dodge Ball: UI polish punch list

From the UI and art-direction review of 2026-10-19, against `framework/ui/UI_STYLE.md` and Kart
Race's polish. "Before" captures: `tests/capture_ui_states.gd -- --game=dodge_ball` (intro,
play, mid, tension with the ride stalled at 45 rpm, pause, summary). Desktop: 94-107 draw calls
in play, about 117 fps.

**Identity: a sports-day arcade.** Quick, bright and sunny. Accent sky cyan `#38B6FF` (the
shield's colour), ink navy `#0E1B3D`, badges leaning 0.18, display face italic for badges. Red
and gold stay the balls' meanings (Dodge and Catch) and are never chrome.

**Hero: the shield.** The rider must see at a glance whether they're pedalling hard enough to
be protected.

**Framework pieces to adopt:** `GameTheme` (`ui_theme()`, `hud_skin()`, `style_label`,
`badge_style`, `pop` / `flash` / `pulse`), the themed intro card and pause screen (free with
`ui_theme()`), and the message pop (free with the skin).

## What works

- The HUD keeps the road clear, and `hud_layout_test` holds it to that with `DodgeStatus` at its
  worst case.
- The status widget changes labels only when their values change.
- The fx overlay hides itself when idle.
- The intro card's mode animation (`ModeBadge`) explains the mode without words.

## P0: blocking

None found. There are no game touch targets, and nothing covers the road.

## P1: high impact

1. [x] **Adopt the theme.** In `DodgeBall.gd`, add
   `static var look := GameTheme.new(Color("38b6ff"), Color("0e1b3d"), 0.18, true)`, override
   `ui_theme()` to return it, and in `_on_prepare` call `hud.set_skin(look.hud_skin())` before
   `hud.add_widget(_status)`. In `DodgeStatus._init`, use `look.panel_style()` for the panel and
   `look.style_label()` on every label.
   *Why:* the intro, pause, HUD chrome and status all read as one game, the same standard as
   Kart. *Verify:* `capture_ui_states.gd`. The intro title is cyan-gradient in Lilita One, and
   the pause pills are green, red and dark. Then run `hud_layout_test`, which builds
   `DodgeStatus` with the longest texts: it must still pass the road keep-clear check.
2. [x] **Make an empty shield unmissable** (`DodgeStatus`). Today a 300x22 bar turns red and a 34 px
   "pedal up!" caption appears (see `dodge_ball_4_tension.png`). Riders get hit without knowing
   why.
   - Make the bar 320x30, with a dark ink track and a 3 px edge.
   - Below the floor, turn the caption into a WARN badge (`look.badge_style(GameTheme.WARN)`)
     reading "PEDAL UP!".
   - When the shield hits 0, the badge turns BAD and `GameTheme.pulse(badge, true)` starts.
     Stop it on `shield_ready` and `GameTheme.pop` the bar.
   - Replace `_process`'s per-frame `queue_redraw` on an empty shield with a modulate pulse
     (budget rule).

   *Verify:* tension capture. The badge reads from across the room at 50%. With the remote
   profiler on the desktop, `DodgeStatus` doesn't redraw every frame.
3. [x] **Targeted juice instead of whole-widget flashes** (`DodgeBall._handle`). `_pop(_status)`
   brightens the whole widget for a miss, a streak and a hit alike. Pop the element that
   changed instead:
   - `streak`: `GameTheme.pop(_status.streak_label, 1.35)`.
   - `hit`: `GameTheme.pop(lives, 0.8)` and `flash`.
   - `catch` and `dodge` at a streak milestone: pop the streak.
   - A new score: `GameTheme.pop(hud.score, 1.12)`. `hud.score` is a compact `BigNumber`
     with no panel, so scaling it never moves its neighbours.

   Expose the streak and lives nodes from `DodgeStatus` as `streak_label` and `lives_box`.
   *Verify:* play 30 s with the arrow keys; each event moves only its own element.
4. [x] **Point popups in the display face** (`DodgeWorld._init` popups, about line 668). Set
   `label.font = GameTheme.display_font()` and `label.outline_modulate = Color("0e1b3d")`. Show
   bonus points ("+20") in `GameTheme.TARGET` and plain ones in white.
   *Why:* the floating "+10"s are the most frequent feedback, and they're in a different face
   from everything else. *Verify:* mid capture shows the popups in Lilita One with a navy
   outline.
5. [x] **`ModeBadge` in the shared face** (`ModeBadge._draw`). It draws "DODGE" with
   `get_theme_default_font()`, beside a title now in Lilita One. Use
   `GameTheme.display_font(false)`, and draw the ink outline first with `draw_string_outline`
   (size 10). Line the lane up with the word's baseline: today the lane sits 22 px below it.
   *Verify:* intro capture.
6. [x] **The power bonus as a reward, not a caption.** "×1" sits in muted text at 34 px all the
   time. Show nothing at ×1. At ×2, show a gold badge "×2 POINTS"
   (`look.badge_style(GameTheme.TARGET)`, ink text) that `slam`s in when the bonus starts and
   `fade`s out when it ends. *Verify:* `capture_dodge.gd --bonus`.

## P2: nice

1. [x] One case style for words: "streak", "wave", "shield" and "pedal up!" are lowercase in the
   status, but "Wave 2" is title case in the message. Use upper case in badges ("WAVE 2",
   "STREAK 12") and sentence case in messages.
2. [x] Game over: `hud.show_message("Game over! Next run in %d", WARN)` runs every frame. With the
   skin it pops each second, which is fine. Make the text BAD and add "Best run: N" so the
   rider knows what the next run is for.
3. [x] Lives as balls: draw them a little larger (radius 14) and pop the lost one down (0.8)
   before it empties.
4. [x] The summary is the framework's and is neutral. Add `stats` keys the summary could show later
   (longest streak is already there). No UI work needed now.

## Done (2026-10-19, branch games-polish-dodge)

- **P1.1** The look lives on `DodgeStatus.look` (a class_name both scripts already share, so
  `DodgeBall.ui_theme()` returns it without a preload cycle) rather than on `DodgeBall.gd`.
- **P1.2** The caption is a fixed-width slot: a plain "SHIELD", a WARN "PEDAL UP!" badge below
  the floor, and a BAD badge that breathes from the moment the shield empties until
  `shield_ready` ("PEDAL UP!" while still under the floor, "NO SHIELD" while it refills). The
  bar throbs with a looping modulate tween and pops when it's full again; `_process` is gone.
- **P1.3** Score pops on every scoring dodge or catch; the streak pops up at a milestone and
  down when it breaks (miss, fumble, hit); a hit pops and flashes the lives (the bar in a
  circuit, which has no lives).
- **P1.6** The ×2 POINTS badge sits in a slot that keeps its width, so the widget never
  re-centres when the bonus comes and goes.
- **P2.2** "Game over! Best run: N" over "Next run in N", in BAD.
- **P2.3** Lives are radius 14 with an ink rim; the lost one shrinks to 0.8 and fades (a 0.3 s
  redraw tween, only on the loss).
- **P2.4** Nothing to add: `longest_streak` and `runs` are already in `stats`.
- Tests: `tests/unit/dodge_ball_status_test.gd`. Draw calls (desktop, `capture_ui_states`):
  play 96 → 98, mid 105 → 109, tension 101 → 104, pause 113 → 121 (the themed pause card; not
  in play). All in-play states stay under 120.

## Out of scope

Watt and cadence thresholds, ball tuning, the 3D world's look, and `RENDER_SCALE`.
