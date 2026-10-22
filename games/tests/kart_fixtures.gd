extends RefCounted
## Shared fixtures for Kart Race's tests (#43): simple tracks with known geometry.
## preload("res://tests/kart_fixtures.gd").


## A flat closed circle of radius `r`, driven anticlockwise seen from above (every turn a left).
static func circle(r := 60.0, n := 24, half_width := 6.0, verge := 4.0) -> KartTrackDef:
	var def := KartTrackDef.new()
	def.id = "circle%d" % roundi(r)
	var pts := PackedVector3Array()
	var widths := PackedFloat32Array()
	var bank := PackedFloat32Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector3(r * cos(a), 0.0, -r * sin(a)))
		widths.append(half_width)
		bank.append(0.0)
	def.points = pts
	def.half_widths = widths
	def.banking = bank
	def.verge = verge
	return def


## An oval: two straights `straight` metres long joined by half circles of radius `r`. s = 0 is
## the middle of the first straight, which runs along +x.
static func oval(straight := 300.0, r := 40.0, half_width := 6.0, verge := 4.0) -> KartTrackDef:
	var def := KartTrackDef.new()
	def.id = "oval"
	var pts := PackedVector3Array()
	var half := straight * 0.5
	var steps := maxi(2, ceili(straight / 50.0))
	# First straight along +x at z = 0, from the middle.
	for k in range(steps / 2, steps):
		pts.append(Vector3(-half + straight * k / steps, 0.0, 0.0))
	# Left half circle round (half, -r).
	for k in 8:
		var a := -PI * 0.5 + PI * k / 8.0
		pts.append(Vector3(half + r * cos(a), 0.0, -r - r * sin(a)))
	for k in steps:
		pts.append(Vector3(half - straight * k / steps, 0.0, -2.0 * r))
	for k in 8:
		var a := PI * 0.5 + PI * k / 8.0
		pts.append(Vector3(-half + r * cos(a), 0.0, -r - r * sin(a)))
	for k in range(0, steps / 2):
		pts.append(Vector3(-half + straight * k / steps, 0.0, 0.0))
	def.points = pts
	var widths := PackedFloat32Array()
	var bank := PackedFloat32Array()
	for i in pts.size():
		widths.append(half_width)
		bank.append(0.0)
	def.half_widths = widths
	def.banking = bank
	def.verge = verge
	return def


static func meadow() -> KartTrackDef:
	return load("res://games/kart_race/tracks/meadow_ring.gd").build()
