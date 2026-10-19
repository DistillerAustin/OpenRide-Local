# Cadence Karaoke: UI polish punch list

From the UI and art-direction review of 2026-10-19, against `framework/ui/UI_STYLE.md` and Kart
Race's polish. "Before" captures:
`tests/capture_ui_states.gd -- --game=cadence_karaoke --tension=120:30` (the tension shot rides
far over the target). Desktop: 50 draw calls in play, 120 fps, the lightest of the four.

**Identity: a synthwave stage.** Neon on black, everything on the beat. The accent is the
world's own neon, `CadenceWorld.theme_color`: cyan for warm-up, green for recovery, violet for
cool-down, pink for a Just Ride, or the rider's colour option. Ink deep violet `#12052A`,
badges leaning 0.25, display face italic. Build the `GameTheme` per segment in `_on_prepare`
from that colour, so the HUD matches the tunnel. When the accent is the recovery green (close
to `GOOD`), meaning stays on words ("IN THE BAND"), never on green alone.

**Hero: the target rpm.** The game's premise is "the one speed number is the target", but the
biggest number on screen today is the rider's own rpm (top left, 96 px). The target is a 34 px
caption.

**Framework pieces to adopt:** `GameTheme` (`ui_theme()`, `hud_skin()`, `hero`, `button`,
`badge_style`, `pop` / `slam` / `pulse`), and the themed intro and pause screens.

## What works

- The tunnel and the orb read the gap well: ahead, behind or on the line.
- The −5 / +5 buttons are a good size, at the bottom centre, far from End.
- It has the lowest draw-call count of the four.

## P0: blocking

1. **The target rpm must be the hero.** Replace `CadenceStatus`'s row 1 with a hero badge:
   - The target as `look.hero(str(rpm), HudTheme.BIG)` (accent gradient), with "rpm target" as
     a 34 px caption beside it.
   - The pending change ("→ 90 in 7 s") as a small accent chip after it.

   Row 2 keeps "In band 78%" and the streak. `GameTheme.pop` the target when it changes (a pace
   step or the circuit's profile). *Why:* a rider glancing up must find the number to match in
   half a second. Today they find their own rpm first and compare it with nothing. *Verify:*
   play capture at 50%. The target is the largest, brightest number in the top centre. The
   widget is within 850x120 px with "120" and "→ 125 in 12 s" (UI_STYLE §5; add a Cadence case
   to `hud_layout_test`).

## P1: high impact

1. **Adopt the theme, per segment.** In `_on_prepare`, after `_apply_look()`, set
   `_look = GameTheme.new(world.theme_color, Color("12052a"), 0.25, true)`. Return it from
   `ui_theme()`, call `hud.set_skin(_look.hud_skin())`, and restyle `CadenceStatus`. The
   rider's colour option changes `theme_color` mid-game (`_on_option_changed`): rebuild the
   look and re-skin then. A re-skin re-lays out every label (about 25 ms on the tablet), which
   is fine on the pause screen, where options change. *Verify:* captures in two roles
   (`--role=warmup`, `--role=cooldown`). The HUD edges match the tunnel.
2. **The −/+ buttons** (`CadenceKaraoke._ready`).
   - Build them with `look.button(…, GameTheme.PRIMARY)`, labelled "−5" and "+5", with a
     34 px "rpm" caption, or "SLOWER" and "FASTER". "− 5" alone doesn't say what moves.
   - Lay them out in an `HBoxContainer` anchored bottom centre
     (`PRESET_CENTER_BOTTOM`, 30 px margin) instead of hand-set `position`.
   - `GameTheme.pop(button, 1.15)` on press.
   - Disabled look when `request_pace` refuses (at `TARGET_MIN` / `TARGET_MAX`).

   Keep each 220x110 or larger and their hit rects at least 120 px from End: they're about
   500 px away now. Restyle them with `_look` in `_on_prepare` (they're built in `_ready`,
   before the look exists). *Verify:* `intro_touch_test`-style taps in a new
   `cadence_scene_test`: a tap on each changes `pending_adjust`, and a tap on the intro card
   over them does nothing.
3. **Directional alerts.** "SLOW DOWN", "SPEED UP" and "EASE OFF" are 34 px amber words at the
   end of row 2. Show them as a WARN badge with an arrow drawn as a shape (▲/▼ polygons, not
   glyphs), and "EASE OFF" as a BAD badge with `GameTheme.pulse` while `logic.frozen`. Pulse
   on the beat: `world.beat` is already computed. A `modulate` flash of the badge's edge on
   each beat costs nothing. *Verify:* tension capture.
4. **Streak juice.** On the `streak` event, `GameTheme.pop` the "×1.5" streak label (gold,
   `TARGET`), and slam "×2!" when the multiplier maxes out. The sound already plays.
   *Verify:* a `--play=45` run shows the pops.

## P2: nice

1. Copy: `GameInfo.how_to` says "keep the ball on the line", but `how_to_text` says "keep the
   ball in the box". Pick one ("keep the orb on the beat line"). `how_to_text`'s two branches
   are identical, so drop the `if`. The intro line wraps to an orphan "+ move the target 5
   rpm". Shorten it to "Match the target rpm. − and + change it".
2. The pace message "Target → 90 rpm at the next phase" is internal jargon ("phase"). Use
   "Next: 90 rpm, on the next bar". The chip (P0.1) already shows the countdown.
3. The −/+ buttons stay visible, dimmed, under the intro card's shade. That's harmless (the
   shade takes the touch), but hide them until `_on_start` for a cleaner card.
4. The HUD panels' navy fill clashes with the black tunnel. The theme's violet ink fixes this
   with P1.1.

## Out of scope

Bands, tolerances, streak timing, music tempo logic and the tunnel's look.
