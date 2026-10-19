extends GdUnitTestSuite
## Tug of War's status widget (`TugStatus`) in the HUD's top-centre slot, with the longest texts
## it can show and a five-digit score (UI_POLISH.md P0.1): no two HUD leaves overlap, the widget
## stays within 800 x 120 (the style guide's budget is 850 x 120, between the ride panel and the
## clock), every text is at least 34 px, and the state badges come and go without a redraw loop.
## Kept apart from hud_layout_test (Dodge Ball's) so each game's layout case lives with the game.

const SCREEN := Rect2(0, 0, 1920, 1080)
const MAX_SIZE := Vector2(800, 120)

var hud: Hud
var status: TugStatus
var look := GameTheme.new(Color("ff9f1c"), Color("2a160b"), 0.12)


func before_test() -> void:
	hud = auto_free(Hud.new())
	add_child(hud)
	var info := GameInfo.new()
	info.title = "Tug of War"
	info.id = "tug_of_war"
	info.tracker_mode = "off"
	hud.setup(info, {"role": "work", "index": 3, "count": 9})
	hud.set_skin(look.hud_skin())
	status = TugStatus.new(look)
	hud.add_widget(status)
	hud.metrics.set_power_band(210.0)
	hud.metrics.refresh(118, 1888, 100)
	hud.score.set_value("99999")
	Effort.begin_segment(true)  # the effort badge shows
	status.set_bot(longest_bot_name(), Color(0.38, 0.42, 0.5))


func after_test() -> void:
	hud.clear_skin()


## The widest bot name the world can make (a material and an animal), in the widget's face.
static func longest_bot_name() -> String:
	var font := GameTheme.display_font()
	var best := ""
	var best_w := 0.0
	for m in TugWorld.MATERIALS:
		for a in TugWorld.ANIMALS:
			var name := "%s %s" % [m, a]
			var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, HudTheme.SMALL).x
			if w > best_w:
				best_w = w
				best = name
	return best


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


func _leaves(root: Node, out: Array[Control]) -> void:
	for child in root.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Control:
			var c := child as Control
			var is_leaf := c is Label or c is Button or (c.get_child_count() == 0 and c.size.x > 0.0 and c.size.y > 0.0)
			if is_leaf and c is Label and (c as Label).text.is_empty():
				is_leaf = false
			if is_leaf:
				out.append(c)
				continue
		_leaves(child, out)


func _assert_layout(state: String) -> void:
	await _settle()
	# A pop (a pip filling, the lead changing) is a brief scale on top of the layout: wait it out.
	await get_tree().create_timer(GameTheme.POP_SEC + 0.05).timeout
	var leaves: Array[Control] = []
	_leaves(hud, leaves)
	assert_int(leaves.size()).is_greater_equal(10)
	for i in leaves.size():
		var a := leaves[i].get_global_rect().grow(-0.5)
		assert_bool(SCREEN.encloses(a)).override_failure_message("%s: %s %s is off screen" % [
			state, leaves[i].name, a]).is_true()
		for j in range(i + 1, leaves.size()):
			var b := leaves[j].get_global_rect().grow(-0.5)
			assert_bool(a.intersects(b)).override_failure_message("%s: %s '%s' %s overlaps %s '%s' %s" % [
				state, leaves[i].name, _text(leaves[i]), a, leaves[j].name, _text(leaves[j]), b]).is_false()
	assert_float(status.size.x).override_failure_message("%s: %d px wide" % [state, status.size.x]).is_less_equal(MAX_SIZE.x)
	assert_float(status.size.y).override_failure_message("%s: %d px tall" % [state, status.size.y]).is_less_equal(MAX_SIZE.y)
	var labels: Array[Control] = []
	_leaves(status, labels)
	for c in labels:
		if c is Label:
			assert_int(c.get_theme_font_size("font_size")).is_greater_equal(HudTheme.SMALL)


func _text(c: Control) -> String:
	return c.text if c is Label or c is Button else ""


func _results(text: String) -> Array[bool]:
	var out: Array[bool] = []
	for ch in text:
		out.append(ch == "W")
	return out


func test_match_best_of_five_with_the_longest_texts() -> void:
	status.set_rounds("match", 5, _results("WLWL"), 1)
	status.set_state(1888, 1888, 0.0, "")
	await _assert_layout("match")
	assert_bool(status.pips.visible).is_true()
	assert_bool(status.badge.visible).is_false()


func test_surge_badge_with_the_longest_texts() -> void:
	status.set_rounds("match", 5, _results("WLWL"), 1)
	status.set_state(1888, 1888, -1.0, "surge")
	await _assert_layout("surge")
	assert_bool(status.badge.visible).is_true()
	assert_str(status.badge_label.text).is_equal("SURGE!")


func test_pedal_and_rest_badges() -> void:
	status.set_rounds("ladder", 3, _results("WWWWWWWWWWW"), 12)
	status.set_state(1888, 1888, 1.0, "", "pedal")
	await _assert_layout("pedal")
	assert_str(status.badge_label.text).is_equal("PEDAL!")
	status.set_state(0, 1888, 0.0, "", "rest", 60)
	await _assert_layout("rest")
	assert_str(status.badge_label.text).is_equal("REST 60")


func test_ladder_endless_and_long_matches_show_a_badge() -> void:
	status.set_rounds("ladder", 3, _results("WWWWWWWWWWW"), 12)
	status.set_state(1888, 1888, 0.5, "")
	await _assert_layout("ladder")
	assert_str(status.badge_label.text).is_equal("RUNG 12")
	status.set_rounds("endless", 3, _results("WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"), 1)
	status.set_state(1888, 1888, 0.5, "")
	await _assert_layout("endless")
	assert_str(status.badge_label.text).is_equal("WON 99")
	status.set_rounds("match", 11, _results("WLWLWLWLWL"), 1)
	await _assert_layout("best of 11")
	assert_str(status.badge_label.text).is_equal("5-5")


func test_the_knot_stays_inside_the_bar() -> void:
	for rope in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		status.set_state(200, 200, rope, "")
		await _settle()
		var bar := status.bar.get_global_rect()
		assert_bool(bar.grow(0.5).encloses(status.knot.get_global_rect())).override_failure_message(
			"knot at p=%s leaves the bar" % rope).is_true()


func test_the_surge_pulse_stops_when_the_surge_ends() -> void:
	status.set_rounds("match", 3, _results(""), 1)
	status.set_state(200, 260, 0.0, "surge")
	await _settle()
	assert_bool(status.badge.has_meta(&"_ui_pulse")).is_true()
	status.set_state(200, 200, 0.0, "")
	await _settle()
	assert_bool(status.badge.has_meta(&"_ui_pulse")).is_false()
	assert_bool(status.pips.visible).is_true()
	assert_object(status.knot.modulate).is_equal(Color.WHITE)


func test_no_per_frame_redraw() -> void:
	# The budget rule: the widget draws only on a change; nothing runs every frame.
	var methods: Array = status.get_script().get_script_method_list().map(func(m): return m.name)
	assert_bool(methods.has("_process")).is_false()


func test_bot_colours_are_lifted_to_read_over_the_panel() -> void:
	for c in TugWorld.BOT_COLORS:
		assert_float(TugStatus.ui_color(c).get_luminance()).is_greater_equal(0.5)
