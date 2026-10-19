# Safe Cracker: UI polish punch list

From the UI and art-direction review of 2026-10-19, against `framework/ui/UI_STYLE.md` and Kart
Race's polish. "Before" captures:
`tests/capture_ui_states.gd -- --game=safe_cracker --role=recovery --logic='{"power_cap":120}' --tension=115:60`
(the tension shot trips the alarm). Desktop: 95 draw calls in play, 120 fps.

**Identity: a noir heist.** Quiet, precise, brass and soot, the opposite of Dodge's arcade.
Accent brass `#E8B04A`, ink soot `#14110D`, **no lean** (skew 0, upright face: a mechanism,
not a race). In this game the target is brass too: that's allowed, because the target *is*
the brass dial band. Keep `GameTheme.TARGET` gold off the HUD chrome so the two don't compete.

**Hero: the dial**, with the reading against the target.

**Framework pieces to adopt:** `GameTheme` (`ui_theme()`, `hud_skin()`, `display_font(true)`
for the dial's `draw_string`, `badge_style`, `slam` / `pulse`), and the themed intro and pause
screens.

## What works

- The big drawn dial is a strong hero and reads well from 1 m.
- `SafeDial.refresh()` redraws only on a change.
- The door swing and the safe sliding in are good motion.

## P0: blocking

1. **The HUD message covers the dial.** `hud.show_message` centres on the screen, which is the
   dial's centre. "Easy on the pedals!" (the alarm) and "Safe cracked! +1150" are drawn across
   the reading and the 0 and 90 numerals, exactly when the rider must read them
   (`safe_cracker_4_tension.png`). Stop calling `hud.show_message` from `SafeCracker`. Add a
   game-owned banner instead: a `PanelContainer` with `look.badge_style()` on a `CanvasLayer`
   under the HUD (layer 6). Centre it horizontally just under the HUD's top bar, above the door
   (door top y = 325). Size it with a container, not a hand position: an anchored
   `MarginContainer` with a top margin. `GameTheme.slam` it in and `fade` it out.
   *Verify:* tension capture. The dial's numbers and needle are fully visible while the alarm
   message shows.

## P1: high impact

1. **Adopt the theme.** In `SafeCracker.gd`, add
   `static var look := GameTheme.new(Color("e8b04a"), Color("14110d"))`, override
   `ui_theme()`, call `hud.set_skin(look.hud_skin())` in `_on_prepare`, and restyle
   `SafeStatus` (`look.panel_style()`, `look.style_label()`).
2. **The dial's type** (`SafeDial._draw`).
   - The numerals are drawn at 30 px in the engine's fallback font: raise them to 36 (the
     34 px floor) in `GameTheme.display_font(true)`.
   - Draw the ink outline first (`draw_string_outline`, size 8).
   - The reading (64 px) is smaller than the target (78 px), but the reading is what the rider
     steers. Make the reading 96 (`BIG`), in GOOD when within tolerance, and the target 56.
   - Use `ThemeDB.fallback_font` nowhere.

   *Verify:* play capture at 50%. The reading is the biggest number on the dial.
3. **The needle crosses the target number.** The target is drawn at (-80, -110), inside the
   needle's sweep: at readings of about 40-60, the needle runs through it (`safe_cracker_2_play.png`).
   Move the target to a brass chip on the door, above the bezel (y ≈ -R - 70). Drawn there, or
   as a `Label` in a badge on the door node so it batches with text. *Verify:* sweep the knob
   through 0-100 in the capture; nothing crosses the target.
4. **Alarm as a state.** Today a 12 px red outline flickers round the door, and "ALARM" is a
   34 px word in the status. While `alarm_left > 0`:
   - A BAD badge "ALARM: EASE OFF" in the banner (P0.1), with `GameTheme.pulse` until it
     clears.
   - The door tinted by a red `modulate` pulse on `_body_root`, not a per-frame redraw.
   - The outline thickened to 20 px.

   *Verify:* tension capture.
5. **Tumbler and crack juice.**
   - Per `tumbler` event, pop the lit light. `SafeDial` is one `_draw`: add a `light_pop`
     property (0-1) and draw the newest light scaled by `1 + 0.35 * light_pop`. Tween it 1 → 0
     over 0.35 s from `SafeCracker._handle`, redrawing only while the tween runs.
   - On `vault_open`, slam a gold hero ("CRACKED! +1150", `look.hero(…, GOLD_GRADIENT)`) in
     the banner.
   - The tumbler lights are 17 px in radius at the door's bottom edge. Make them 22 px and move
     them inside the door (y 300, not 343), so they don't sit on the door's edge.
6. **The status widget repeats the dial.** "Target 22" is also on the dial (P1.3), and "Easy
   on the pedals: under 120 W" is a sentence. Make it "VAULT 3" as a brass badge, cracked safes
   as small brass pips, and "MAX 120 W" in muted text that turns WARN when over the cap. It's
   shorter, and the sentence moves to the intro card's target line (already there).

## P2: nice

1. "KEEP PEDALLING" (drawn on the dial when unpowered) is 44 px in the fallback face. Put it in
   the display face with an ink outline, as a WARN badge drawn across the dial's lower half.
2. Backdrops (`SafePlaces`) are flat. A soft vignette (one `TextureRect` with a radial
   `GradientTexture2D`, drawn once) would focus the eye on the safe and add noir. Check the
   draw-call cost (+1).
3. Intro `target_text`: "Pedal gently: easy spinning" reads oddly. Use "Spin easy: keep it
   light".

## Out of scope

The combination rules, tolerances, the power cap and alarm tuning.
