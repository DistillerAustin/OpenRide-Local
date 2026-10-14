extends RefCounted
## Meadow Ring, v0 (#43): the hero track. Green hills and wide sweepers, about 1.15 km: a
## straight past the grandstand, a long banked left-hander, a climb along the back to a crest,
## a winding descent and a flowing run back to the line. An original layout (from a sum of
## sines, rounded to control points). The world agent owns the final layout and dressing.

const POINTS := [
	Vector3(58.2, 0.0, 87.9), Vector3(81.4, 0.0, 78.6), Vector3(107.5, 0.0, 68.1),
	Vector3(141.0, 0.0, 54.6), Vector3(183.6, 0.0, 33.9), Vector3(224.0, 0.0, 0.0),
	Vector3(241.0, 0.0, -44.6), Vector3(221.7, 0.0, -85.8), Vector3(174.1, 0.0, -110.0),
	Vector3(120.3, 0.0, -116.2), Vector3(77.1, 0.0, -116.1), Vector3(44.7, 0.8, -119.7),
	Vector3(15.2, 2.4, -125.7), Vector3(-15.2, 4.4, -126.1), Vector3(-44.2, 6.6, -118.4),
	Vector3(-71.4, 8.6, -107.6), Vector3(-101.0, 9.8, -97.6), Vector3(-134.3, 10.0, -84.8),
	Vector3(-163.2, 9.4, -63.2), Vector3(-177.6, 8.0, -32.8), Vector3(-177.3, 6.2, 0.0),
	Vector3(-173.3, 4.4, 32.0), Vector3(-173.3, 2.8, 67.1), Vector3(-170.6, 1.4, 107.8),
	Vector3(-151.1, 0.5, 145.9), Vector3(-110.3, 0.0, 166.2), Vector3(-60.0, 0.0, 160.5),
	Vector3(-16.6, 0.0, 137.1), Vector3(13.6, 0.0, 112.6), Vector3(36.2, 0.0, 96.8),
]
## The start straight is wider, for the grid.
const WIDE := 7.5
const ROAD := 6.5
## The long left-hander (points 5-7) is banked a little.
const BANK := 0.08


static func build() -> KartTrackDef:
	var def := KartTrackDef.new()
	def.id = "meadow_ring"
	def.title = "Meadow Ring"
	def.theme = "meadow"
	def.points = PackedVector3Array(POINTS)
	var widths := PackedFloat32Array()
	var bank := PackedFloat32Array()
	for i in POINTS.size():
		widths.append(WIDE if i in [28, 29, 0, 1, 2] else ROAD)
		bank.append(BANK if i in [5, 6, 7] else 0.0)
	def.half_widths = widths
	def.banking = bank
	def.verge = 4.0
	def.start_s = 0.0
	def.zones = [
		{"type": "start", "s0": 1100.0, "s1": 2.0},
		{"type": "items", "s0": 290.0, "s1": 292.0},
		{"type": "climb", "s0": 465.0, "s1": 650.0},
		{"type": "items", "s0": 875.0, "s1": 877.0},
		{"type": "boost", "s0": 1020.0, "s1": 1026.0, "d": -2.8, "w": 1.4},
		{"type": "boost", "s0": 1020.0, "s1": 1026.0, "d": 2.8, "w": 1.4},
	]
	return def
