class_name KartRacerList
extends Control
## The racer list (#43), down the left edge: a round portrait per racer in race order, with the
## place beside it. The rider's row has a bigger, gold-ringed portrait and their name on a
## slanted chip. Rows slide to their new places on an overtake (a tween per row, killed and
## restarted when the order changes again), and the rider's row pulses when they gain a place.

const ROW_H := 64.0
const PORTRAIT := 52.0
const RIDER_PORTRAIT := 64.0
const WIDTH := 330.0

var rows: Array[Control] = []

var _place_text: Array[String] = []  ## per kart id
var _numbers: Control  ## every place number, drawn in one pass (outlines, then fills)
var _redraw_left := 0.0
var _target := PackedFloat32Array()
var _shown := []
var _tweens := {}


func _init() -> void:
	name = "RacerList"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, ROW_H * 8)
	_numbers = Control.new()
	_numbers.name = "Places"
	_numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_numbers.size = Vector2(46, ROW_H * 8)
	_numbers.draw.connect(_draw_numbers)
	add_child(_numbers)


## racers: KartRoster entries in kart id order (0 is the rider); `portrait(racer_id, size, you)`
## returns a portrait control.
func setup(racers: Array, portrait: Callable) -> void:
	for r in rows:
		r.queue_free()
	rows.clear()
	_place_text.clear()
	_shown = []
	size = Vector2(WIDTH, ROW_H * racers.size())
	_target.resize(racers.size())
	for i in racers.size():
		var racer: Dictionary = racers[i]
		var you := i == KartRaceLogic.RIDER
		var row := Control.new()
		row.name = "Row_%s" % racer.id
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size = Vector2(WIDTH, ROW_H)
		row.position = Vector2(0, i * ROW_H)
		add_child(row)
		var d := RIDER_PORTRAIT if you else PORTRAIT
		if you:
			var chip := Panel.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := KartTheme.badge(Color(1.0, 0.62, 0.15, 0.95), 0.22, 12, Color(1, 0.92, 0.6))
			chip.add_theme_stylebox_override("panel", style)
			chip.position = Vector2(84, (ROW_H - 46) * 0.5)
			chip.size = Vector2(200, 46)
			row.add_child(chip)
			var name_label := KartTheme.label(str(racer.name), 36, KartTheme.INK)
			name_label.position = Vector2(38, -3)
			name_label.size = Vector2(160, 50)
			name_label.clip_text = true
			name_label.add_theme_constant_override("outline_size", 9)
			chip.add_child(name_label)
		if portrait.is_valid():
			var pic: Control = portrait.call(str(racer.id), d, you)
			pic.position = Vector2(48 + (RIDER_PORTRAIT - d) * 0.5, (ROW_H - d) * 0.5)
			row.add_child(pic)
		rows.append(row)
		_place_text.append(str(i + 1))
		_target[i] = row.position.y
	_numbers.move_to_front()
	_numbers.queue_redraw()


## The race order (kart ids, first to last). Rows slide only when it changes.
func set_order(order: Array) -> void:
	if order == _shown:
		return
	var rider_was := _shown.find(KartRaceLogic.RIDER)
	_shown = order.duplicate()
	for p in order.size():
		var id: int = order[p]
		if id < rows.size():
			_target[id] = p * ROW_H
			_place_text[id] = str(p + 1)
	_redraw_left = 0.5
	_numbers.queue_redraw()
	for id in rows.size():
		_slide(id)
	var rider_now := order.find(KartRaceLogic.RIDER)
	if rider_was >= 0 and rider_now >= 0 and rider_now < rider_was and KartRaceLogic.RIDER < rows.size():
		var row := rows[KartRaceLogic.RIDER]
		row.pivot_offset = Vector2(80, ROW_H * 0.5)
		row.scale = Vector2(1.15, 1.15)
		var tw := row.create_tween()
		tw.tween_property(row, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _slide(id: int) -> void:
	var row := rows[id]
	if absf(row.position.y - _target[id]) < 0.5:
		return
	var old: Tween = _tweens.get(id)
	if old and old.is_valid():
		old.kill()
	var tw := row.create_tween()
	_tweens[id] = tw
	tw.tween_property(row, "position:y", _target[id], 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _redraw_left > 0.0:
		_redraw_left -= delta
		_numbers.queue_redraw()


func _draw_numbers() -> void:
	var font := KartTheme.display(true)
	for pass_i in 2:
		for id in rows.size():
			var you := id == KartRaceLogic.RIDER
			var font_size := 40 if you else 36
			var text := _place_text[id]
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var at := Vector2(40.0 - w, rows[id].position.y + ROW_H * 0.5 + font_size * 0.36)
			if pass_i == 0:
				_outline_text(font, at, text, font_size)
			else:
				_numbers.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, KartTheme.CHIP if you else KartTheme.INK)


func _outline_text(font: Font, at: Vector2, text: String, font_size: int) -> void:
	_numbers.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, KartTheme.OUTLINE)
