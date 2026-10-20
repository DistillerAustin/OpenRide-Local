class_name Toast
extends CanvasLayer
## A one-line message over the hub ("Ride saved", why a plan couldn't start): a badge at the
## top centre that pops in and fades out after `seconds`. It takes no touch.

const LAYER := 36
const TOP := 170.0

var badge: PanelContainer
var text_label: Label
var _hide_tween: Tween


func _init() -> void:
	layer = LAYER
	visible = false
	badge = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	text_label = HubTheme.label("", HudTheme.BODY, GameTheme.INK, true)
	badge.add_child(text_label)


## Shows `text` for `seconds` in `fill` (the house accent by default; a meaning colour when it
## means something: GOOD for "Ride saved").
func show_text(text: String, seconds := 2.5, fill = null) -> void:
	text_label.text = text
	badge.add_theme_stylebox_override("panel", HubTheme.look().badge_style(fill))
	visible = true
	badge.modulate.a = 1.0
	badge.reset_size()
	badge.position = Vector2((HubTheme.W - badge.get_combined_minimum_size().x) / 2.0, TOP)
	GameTheme.pop(badge, 1.15)
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = badge.create_tween()
	_hide_tween.tween_interval(seconds)
	_hide_tween.tween_property(badge, "modulate:a", 0.0, 0.3)
	_hide_tween.tween_callback(func(): visible = false)


func is_showing() -> bool:
	return visible
