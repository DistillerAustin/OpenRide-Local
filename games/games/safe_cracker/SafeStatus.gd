class_name SafeStatus
extends PanelContainer
## Safe Cracker's HUD widget, in the HUD's top-centre slot: two short rows.
##
##   [VAULT 3]  ● ● ○            (a brass badge, then one brass pip per safe cracked)
##   MAX 120 W                   (muted; "OVER 120 W" in amber while over the cap)
##
## The target is on the dial and the alarm in the game's banner, so neither repeats here.
## Labels only change with their values, so the HUD isn't re-laid out every frame.

const MAX_PIPS := 8  ## past this many safes the pips give way to a count ("×12")

var _look: GameTheme
var _vault_badge: PanelContainer
var _vault: Label
var _pips: SafePips
var _count: Label
var _power: Label
var _texts := ["", "", -1]


func _init(look: GameTheme) -> void:
	_look = look
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", look.panel_style())
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 18)
	box.add_child(top)
	_vault_badge = PanelContainer.new()
	_vault_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := look.badge_style()
	badge.content_margin_top = 0
	badge.content_margin_bottom = 2
	badge.shadow_size = 4
	_vault_badge.add_theme_stylebox_override("panel", badge)
	top.add_child(_vault_badge)
	_vault = look.label("", HudTheme.SMALL, GameTheme.INK, true)
	_vault.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vault.custom_minimum_size = Vector2(150, 0)  # "VAULT 99" without shifting the pips
	_vault_badge.add_child(_vault)
	_pips = SafePips.new(look.accent, look.ink, MAX_PIPS)
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_pips)
	_count = look.label("", HudTheme.SMALL, look.accent, true)
	_count.custom_minimum_size = Vector2(90, 0)
	_count.visible = false
	top.add_child(_count)
	_power = look.label("", HudTheme.SMALL, GameTheme.MUTED, true)
	box.add_child(_power)


## `power_warning` turns the power line amber (and its word to OVER) while over the cap.
## `hint` (e.g. "Follow the ticks") follows the power line when the target is hidden.
func set_state(vault: int, cracked: int, cap_watts: float, power_warning: bool, hint := "") -> void:
	var vault_text := "VAULT %d" % vault
	if vault_text != _texts[0]:
		_texts[0] = vault_text
		_vault.text = vault_text
		if vault > 1:
			GameTheme.pop(_vault_badge, 1.2)
	if cracked != _texts[2]:
		_texts[2] = cracked
		_pips.set_count(cracked)
		_count.visible = cracked > MAX_PIPS
		_count.text = "×%d" % cracked
	var power := ""
	if cap_watts > 0.0:
		power = "%s %d W" % ["OVER" if power_warning else "MAX", roundi(cap_watts)]
	else:
		power = "EASY PEDALLING"
	if not hint.is_empty():
		power += "  ·  " + hint
	var key := power + ("!" if power_warning else "")
	if key != _texts[1]:
		_texts[1] = key
		_power.text = power
		_power.add_theme_color_override("font_color", GameTheme.WARN if power_warning else GameTheme.MUTED)


## One brass pip per safe cracked (up to `max_pips`; past that a single pip, beside a count).
## Drawn shapes, not glyphs (UI_STYLE.md §3); redrawn only when the count changes.
class SafePips:
	extends Control

	const R := 13.0
	const GAP := 34.0

	var _fill: Color
	var _ink: Color
	var _max: int
	var _count := 0

	func _init(fill: Color, ink: Color, max_pips: int) -> void:
		_fill = fill
		_ink = ink
		_max = max_pips
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(GAP * max_pips, R * 2.0 + 8.0)

	func set_count(n: int) -> void:
		_count = n
		queue_redraw()

	func shown() -> int:
		return _count if _count <= _max else 1

	func _draw() -> void:
		var y := size.y / 2.0
		for i in shown():
			var at := Vector2(R + 4.0 + i * GAP, y)
			draw_circle(at, R + 3.0, _ink)
			draw_circle(at, R, _fill)
			draw_circle(at - Vector2(3, 3), R * 0.38, _fill.lightened(0.5))
