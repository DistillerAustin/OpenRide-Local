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

var _places: Array[Label] = []
var _target := PackedFloat32Array()
var _shown := []
var _tweens := {}


func _init() -> void:
	name = "RacerList"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, ROW_H * 8)


## racers: KartRoster entries in kart id order (0 is the rider); `portrait(racer_id, size, you)`
## returns a portrait control.
func setup(racers: Array, portrait: Callable) -> void:
	for r in rows:
		r.queue_free()
	rows.clear()
	_places.clear()
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
		var place := KartTheme.label(str(i + 1), 40 if you else 36, KartTheme.CHIP if you else KartTheme.INK, true)
		place.size = Vector2(40, ROW_H)
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(place)
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
		_places.append(place)
		_target[i] = row.position.y


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
			_places[id].text = str(p + 1)
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
