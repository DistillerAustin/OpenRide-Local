extends GdUnitTestSuite
## The centred stage (#57): on the bike's window (about 2057x1080 of canvas with stretch aspect
## `keep_height`), the 1920x1080 layouts sit in the middle, and only backdrops, shades and 3D views
## cover the whole window. `Stage.fit` stands in for the window: headless, the root shows 1920x1080.

const BIKE := Vector2(2057, 1080)  ## 1920x1008 at the 1080-high canvas's scale
const PAD := 68.0  ## (2057 - 1920) / 2, whole pixels

var _nodes: Array[Node] = []


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Stage.fit(Vector2(HudTheme.W, HudTheme.H))


func _add(n: Node) -> Node:
	_nodes.append(n)
	get_tree().root.add_child(n)
	return n


## A Control's rect on the window (the canvas the player sees), layer offset included.
static func _on_window(c: Control) -> Rect2:
	return c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)


func test_the_pad_is_half_the_extra_canvas_in_whole_pixels() -> void:
	assert_vector(Stage.pad_for(Vector2(HudTheme.W, HudTheme.H))).is_equal(Vector2.ZERO)
	assert_vector(Stage.pad_for(Vector2(2057.14, 1080))).is_equal(Vector2(PAD, 0))
	assert_vector(Stage.pad_for(Vector2(1920, 1200))).is_equal(Vector2(0, 60))
	assert_vector(Stage.pad_for(Vector2(1800, 1000))).is_equal(Vector2.ZERO)


func test_a_16_by_9_window_moves_nothing() -> void:
	assert_vector(Stage.pad).is_equal(Vector2.ZERO)
	assert_vector(get_tree().root.canvas_transform.origin).is_equal(Vector2.ZERO)
	assert_vector(Vector2(Stage.view_size(0.5))).is_equal(Vector2(960, 540))


func test_the_default_canvas_and_every_layer_shift_to_the_stage() -> void:
	var before: CanvasLayer = _add(CanvasLayer.new())
	Stage.fit(BIKE)
	var after: CanvasLayer = _add(CanvasLayer.new())
	assert_vector(get_tree().root.canvas_transform.origin).is_equal(Vector2(PAD, 0))
	assert_vector(before.offset).is_equal(Vector2(PAD, 0))
	assert_vector(after.offset).is_equal(Vector2(PAD, 0))
	Stage.fit(Vector2(HudTheme.W, HudTheme.H))
	assert_vector(before.offset).is_equal(Vector2.ZERO)


func test_a_layer_inside_a_sub_viewport_stays_put() -> void:
	Stage.fit(BIKE)
	var view: SubViewport = _add(SubViewport.new())
	var layer := CanvasLayer.new()
	view.add_child(layer)
	assert_vector(layer.offset).is_equal(Vector2.ZERO)


func test_a_bleed_covers_the_whole_window_and_follows_it() -> void:
	var layer: CanvasLayer = _add(CanvasLayer.new())
	var shade := ColorRect.new()
	layer.add_child(shade)
	Stage.bleed(shade)
	assert_object(_on_window(shade)).is_equal(Rect2(0, 0, HudTheme.W, HudTheme.H))
	Stage.fit(BIKE)
	assert_object(_on_window(shade)).is_equal(Rect2(Vector2.ZERO, BIKE))
	# Built away from the tree, then added: placed as it enters.
	var late := ColorRect.new()
	Stage.bleed(late)
	Stage.fit(Vector2(HudTheme.W, HudTheme.H))
	Stage.fit(BIKE)
	layer.add_child(late)
	assert_object(_on_window(late)).is_equal(Rect2(Vector2.ZERO, BIKE))


func test_a_3d_view_spans_the_window_and_maps_back_to_the_stage() -> void:
	Stage.fit(BIKE)
	assert_vector(Vector2(Stage.view_size(0.5))).is_equal((BIKE * 0.5).round())
	var px := Vector2(Stage.view_size(0.5))
	assert_vector(Stage.from_view(px / 2.0, px)).is_equal_approx(Vector2(HudTheme.W, HudTheme.H) / 2.0, Vector2.ONE)
	assert_vector(Stage.from_view(Vector2.ZERO, px)).is_equal(Vector2(-PAD, 0))


func test_the_hud_sits_centred_on_the_bike_window() -> void:
	Stage.fit(BIKE)
	var hud: Hud = _add(Hud.new())
	assert_object(_on_window(hud.frame)).is_equal(Rect2(Vector2(PAD, 0), Vector2(HudTheme.W, HudTheme.H)))


func test_the_pause_shade_covers_the_window_and_its_card_is_centred() -> void:
	Stage.fit(BIKE)
	var pause: PauseOverlay = _add(PauseOverlay.new())
	pause.visible = true
	await get_tree().process_frame
	var shades := pause.get_children().filter(func(n): return n is ColorRect)
	assert_object(_on_window(shades[0])).is_equal(Rect2(Vector2.ZERO, BIKE))
	var cards := pause.find_children("*", "PanelContainer", true, false)
	assert_bool(cards.is_empty()).is_false()
	var card := _on_window(cards[0])
	assert_float(card.get_center().x).is_equal_approx(BIKE.x / 2.0, 1.0)


func test_the_calibration_card_stays_centred_when_the_window_changes() -> void:
	var cal: CalibrationOverlay = _add(CalibrationOverlay.new())
	Stage.fit(BIKE)
	var full: Control = cal.get_child(0)
	assert_object(_on_window(full)).is_equal(Rect2(Vector2.ZERO, BIKE))
	var card: Control = full.get_child(0)
	assert_float(_on_window(card).get_center().x).is_equal_approx(BIKE.x / 2.0, 1.0)
