class_name KartModels
extends RefCounted
## The racers' models (#43): a toy kart in one of three designs (light, medium, heavy) and its
## animal driver, built in code from smooth shapes (KartMeshKit: superellipsoids, lathes and
## tubes with analytic normals) into ONE mesh per kart, each vertex tagged with its bone (UV2.x).
## KartView poses the bones and the kart shaders move the vertices, so a kart and driver is one
## draw plus its outline pass.
##
## Everything faces -Z (the kart's forward), y up, the ground at y = 0. Vertex colours carry
## the paint and painted AO; COLOR.a is the gloss mask, UV.x the outline width and UV.y the
## self-lit share (KartLook's kart shader). Budget: about 3k triangles a kart with its driver.

enum { BODY, DRIVER, HEAD, EYES, EARS, ARM_L, ARM_R, STEER, WHEEL_FL, WHEEL_FR, WHEEL_RL, WHEEL_RR }
const BONES := ["body", "driver", "head", "eyes", "ears", "arm_l", "arm_r", "steer",
	"wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]
const PARENTS := [-1, BODY, DRIVER, HEAD, HEAD, DRIVER, DRIVER, BODY, -1, -1, -1, -1]

## Where the driver's parts sit, from the seat (the DRIVER bone).
const NECK := Vector3(0.0, 0.36, 0.0)
const HEAD_C := Vector3(0.0, 0.66, -0.02)
const HEAD_R := Vector3(0.34, 0.31, 0.31)
const SHOULDER := Vector3(0.2, 0.3, -0.03)

const BLACK := Color(0.06, 0.05, 0.07, 0.9)
const WHITE := Color(0.98, 0.97, 0.95, 0.15)
const RUBBER := Color(0.13, 0.13, 0.15, 0.12)
const DARK := Color(0.16, 0.16, 0.19, 0.35)
const CHROME := Color(0.8, 0.8, 0.84, 1.0)
const PINK := Color(1.0, 0.58, 0.66, 0.1)

static var _layouts := {}


## The kart class's layout: wheel centres, radii and widths (FL, FR, RL, RR), the seat (the
## driver's origin), the steering wheel, the exhausts, the number plate and the item hold.
static func layout(cls: String) -> Dictionary:
	if _layouts.has(cls):
		return _layouts[cls]
	var l := {}
	match cls:
		"light":
			l = {"wheels": [Vector3(-0.66, 0.27, -0.8), Vector3(0.66, 0.27, -0.8), Vector3(-0.68, 0.3, 0.66), Vector3(0.68, 0.3, 0.66)],
				"radii": [0.27, 0.27, 0.3, 0.3], "widths": [0.2, 0.2, 0.26, 0.26],
				"seat": Vector3(0.0, 0.44, 0.22), "steer": Vector3(0.0, 0.74, -0.24),
				"exhaust": [Vector3(-0.1, 0.62, 1.12), Vector3(0.1, 0.62, 1.12)],
				"number": Vector3(0.0, 1.0, 1.0), "item": Vector3(0.0, 1.5, 0.95)}
		"heavy":
			l = {"wheels": [Vector3(-0.76, 0.31, -0.8), Vector3(0.76, 0.31, -0.8), Vector3(-0.8, 0.38, 0.74), Vector3(0.8, 0.38, 0.74)],
				"radii": [0.31, 0.31, 0.38, 0.38], "widths": [0.28, 0.28, 0.42, 0.42],
				"seat": Vector3(0.0, 0.5, 0.26), "steer": Vector3(0.0, 0.8, -0.22),
				"exhaust": [Vector3(-0.3, 1.18, 0.88), Vector3(0.3, 1.18, 0.88)],
				"number": Vector3(0.0, 0.64, 1.07), "item": Vector3(0.0, 1.55, 1.0)}
		_:
			l = {"wheels": [Vector3(-0.72, 0.3, -0.78), Vector3(0.72, 0.3, -0.78), Vector3(-0.74, 0.34, 0.72), Vector3(0.74, 0.34, 0.72)],
				"radii": [0.3, 0.3, 0.34, 0.34], "widths": [0.24, 0.24, 0.34, 0.34],
				"seat": Vector3(0.0, 0.47, 0.24), "steer": Vector3(0.0, 0.77, -0.23),
				"exhaust": [Vector3(-0.22, 0.52, 1.24), Vector3(0.22, 0.52, 1.24)],
				"number": Vector3(0.0, 1.05, 1.13), "item": Vector3(0.0, 1.5, 0.95)}
	_layouts[cls] = l
	return l


## Each bone's rest position in kart space (all rests are unrotated).
static func bone_points(r: Dictionary) -> Array:
	var l := layout(KartRoster.kart_class(r))
	var seat: Vector3 = l.seat
	var hr := head_radii(r)
	var hc := seat + HEAD_C
	var eye := eye_spot(r)
	var pts := []
	pts.resize(BONES.size())
	pts[BODY] = Vector3(0.0, 0.25, 0.0)
	pts[DRIVER] = seat
	pts[HEAD] = seat + NECK
	pts[EYES] = hc + Vector3(0.0, eye.y, -hr.z * 0.9)
	pts[EARS] = hc + Vector3(0.0, hr.y * 0.6, 0.0)
	pts[ARM_L] = seat + Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z)
	pts[ARM_R] = seat + SHOULDER
	pts[STEER] = l.steer
	for i in 4:
		pts[WHEEL_FL + i] = l.wheels[i]
	return pts


## The whole kart with its driver: one rigged mesh.
static func model(r: Dictionary) -> ArrayMesh:
	var kit := KartMeshKit.new()
	kit.skinned = true
	kit.flags = true
	var cls := KartRoster.kart_class(r)
	var l := layout(cls)
	kit.bone = BODY
	kit.ao_y0 = 0.1
	kit.ao_y1 = 0.7
	kit.ao_min = 0.6
	match cls:
		"light":
			_kart_light(kit, r, l)
		"heavy":
			_kart_heavy(kit, r, l)
		_:
			_kart_medium(kit, r, l)
	_steering(kit, l)
	kit.ao_min = 1.0
	for i in 4:
		kit.bone = WHEEL_FL + i
		_wheel(kit, r, l.wheels[i], l.radii[i], l.widths[i], -1.0 if i % 2 == 0 else 1.0)
	_driver(kit, r, l.seat, l.steer)
	return kit.commit()


## The head alone, centred at the origin and facing -Z, sized for the HUD's portraits.
static func head(r: Dictionary) -> ArrayMesh:
	var kit := KartMeshKit.new()
	kit.flags = true
	_head(kit, r, Vector3.ZERO)
	return _scaled(kit.commit(), 0.84)


# --- Karts ---

static func _paint(r: Dictionary) -> Color:
	var c: Color = r.get("color", Color(0.9, 0.3, 0.2))
	return Color(c.r, c.g, c.b, 1.0)


static func _accent(r: Dictionary) -> Color:
	var c: Color = r.get("accent", Color.WHITE)
	return Color(c.r, c.g, c.b, 0.9)


## A soft racing stripe in the accent colour along the top centre of a shape.
static func _stripe(accent: Color, width: float) -> Callable:
	return func(p: Vector3, n: Vector3, c: Color) -> Color:
		var k := (1.0 - smoothstep(width * 0.5, width, absf(p.x))) * smoothstep(0.1, 0.5, n.y)
		return c.lerp(accent, k)


static func _kart_medium(kit: KartMeshKit, r: Dictionary, _l: Dictionary) -> void:
	var K := KartMeshKit
	var paint := _paint(r)
	var accent := _accent(r)
	var deep := Color(paint.r * 0.72, paint.g * 0.72, paint.b * 0.72, 0.9)
	kit.add(K.blob(Vector3(0.58, 0.06, 1.1), 0.35, 0.35, 12, 4), K.xf(Vector3(0, 0.2, 0.02)), DARK)
	kit.paint = _stripe(accent, 0.16)
	kit.add(K.blob(Vector3(0.5, 0.25, 1.06), 0.55, 0.75, 16, 7), K.xf(Vector3(0, 0.4, -0.06)), paint)
	kit.paint = Callable()
	_bar(kit, [Vector3(-0.72, 0.21, -1.02), Vector3(-0.45, 0.19, -1.2), Vector3(0.45, 0.19, -1.2), Vector3(0.72, 0.21, -1.02)], 0.065, accent)
	for side: float in [-1.0, 1.0]:
		kit.add(K.blob(Vector3(0.17, 0.15, 0.46), 0.6, 0.8, 8, 5), K.xf(Vector3(side * 0.5, 0.32, 0.1)), deep)
		kit.outline = 0.5
		kit.add(K.lathe(_pipe_profile(0.06, 0.3), 6), K.xf(Vector3(side * 0.22, 0.47, 1.0), Vector3(75, 0, 0)), CHROME)
		kit.add(K.blob(Vector3(0.03, 0.15, 0.2), 0.5, 0.5, 6, 4), K.xf(Vector3(side * 0.74, 1.0, 1.05)), paint)
		kit.add(K.tube(PackedVector3Array([Vector3(side * 0.3, 0.6, 0.98), Vector3(side * 0.32, 0.98, 1.04)]),
			PackedFloat32Array([0.03]), 4), Transform3D.IDENTITY, DARK)
		_lamp(kit, Vector3(side * 0.3, 0.42, 1.0), Color(1.0, 0.25, 0.2), 0.045)
		kit.outline = 1.0
	kit.add(K.blob(Vector3(0.27, 0.27, 0.09), 0.5, 0.6, 10, 5), K.xf(Vector3(0, 0.72, 0.52), Vector3(-10, 0, 0)), DARK)
	kit.add(K.blob(Vector3(0.28, 0.17, 0.2), 0.4, 0.5, 8, 4), K.xf(Vector3(0, 0.46, 0.86)), Color(0.45, 0.45, 0.5, 0.8))
	_wing(kit, Vector3(0, 1.0, 1.04), 0.74, 0.16, accent)


static func _kart_light(kit: KartMeshKit, r: Dictionary, _l: Dictionary) -> void:
	var K := KartMeshKit
	var paint := _paint(r)
	var accent := _accent(r)
	kit.add(K.blob(Vector3(0.42, 0.05, 1.0), 0.4, 0.4, 10, 4), K.xf(Vector3(0, 0.19, 0.0)), DARK)
	kit.paint = _stripe(accent, 0.12)
	kit.add(K.blob(Vector3(0.36, 0.2, 1.16), 0.75, 0.8, 16, 7), K.xf(Vector3(0, 0.37, -0.06)), paint)
	kit.paint = Callable()
	kit.add(K.blob(Vector3(0.2, 0.09, 0.22), 0.6, 0.8, 8, 4), K.xf(Vector3(0, 0.36, -1.08), Vector3(8, 0, 0)), accent)
	_bar(kit, [Vector3(-0.56, 0.18, -1.04), Vector3(-0.3, 0.17, -1.16), Vector3(0.3, 0.17, -1.16), Vector3(0.56, 0.18, -1.04)], 0.045, accent)
	# Nerf bars: a tube loop down each side, and the front bumper.
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector3Array([Vector3(side * 0.3, 0.24, -0.62), Vector3(side * 0.5, 0.25, -0.4),
			Vector3(side * 0.53, 0.26, 0.2), Vector3(side * 0.34, 0.28, 0.48)])
		kit.add(K.tube(pts, PackedFloat32Array([0.045]), 5), Transform3D.IDENTITY, accent)
		_lamp(kit, Vector3(side * 0.36, 0.24, 1.0), Color(1.0, 0.25, 0.2), 0.04)
	kit.add(K.blob(Vector3(0.24, 0.24, 0.08), 0.5, 0.6, 10, 5), K.xf(Vector3(0, 0.66, 0.5), Vector3(-12, 0, 0)), DARK)
	kit.add(K.blob(Vector3(0.22, 0.15, 0.2), 0.45, 0.5, 8, 4), K.xf(Vector3(0, 0.42, 0.84)), Color(0.45, 0.45, 0.5, 0.8))
	kit.outline = 0.5
	kit.add(K.lathe(_pipe_profile(0.065, 0.34), 6), K.xf(Vector3(0.14, 0.5, 0.9), Vector3(55, 0, -10)), CHROME)
	kit.outline = 1.0
	# The shark fin and its little wing.
	kit.add(K.blob(Vector3(0.035, 0.22, 0.24), 0.6, 0.6, 8, 5), K.xf(Vector3(0, 0.8, 0.86), Vector3(-14, 0, 0)), paint)
	_wing(kit, Vector3(0, 1.0, 0.96), 0.56, 0.13, accent)


static func _kart_heavy(kit: KartMeshKit, r: Dictionary, _l: Dictionary) -> void:
	var K := KartMeshKit
	var paint := _paint(r)
	var accent := _accent(r)
	kit.add(K.blob(Vector3(0.66, 0.07, 1.1), 0.35, 0.35, 12, 4), K.xf(Vector3(0, 0.22, 0.0)), DARK)
	kit.paint = _stripe(accent, 0.2)
	kit.add(K.blob(Vector3(0.6, 0.29, 1.02), 0.4, 0.45, 16, 7), K.xf(Vector3(0, 0.44, 0.0)), paint)
	kit.paint = Callable()
	# The fat bumper, the rear fenders, the roll hoop and twin stacks.
	kit.add(K.tube(PackedVector3Array([Vector3(-0.78, 0.3, -1.0), Vector3(-0.55, 0.28, -1.2), Vector3(0.55, 0.28, -1.2),
		Vector3(0.78, 0.3, -1.0)]), PackedFloat32Array([0.11]), 7), Transform3D.IDENTITY, accent)
	for side: float in [-1.0, 1.0]:
		kit.add(K.blob(Vector3(0.27, 0.1, 0.42), 0.5, 0.6, 8, 5), K.xf(Vector3(side * 0.8, 0.76, 0.74), Vector3(0, 0, side * -8)), paint)
		kit.outline = 0.5
		kit.add(K.lathe(_pipe_profile(0.07, 0.5), 6), K.xf(Vector3(side * 0.3, 0.66, 0.86), Vector3(12, 0, 0)), CHROME)
		_lamp(kit, Vector3(side * 0.34, 0.5, -1.0), Color(1.0, 0.92, 0.6), 0.06)
		_lamp(kit, Vector3(side * 0.42, 0.56, 1.0), Color(1.0, 0.25, 0.2), 0.05)
		kit.outline = 1.0
	kit.add(K.tube(PackedVector3Array([Vector3(-0.34, 0.66, 0.66), Vector3(-0.3, 1.08, 0.66), Vector3(0.3, 1.08, 0.66),
		Vector3(0.34, 0.66, 0.66)]), PackedFloat32Array([0.05]), 6), Transform3D.IDENTITY, accent)
	kit.add(K.blob(Vector3(0.3, 0.28, 0.1), 0.5, 0.6, 10, 5), K.xf(Vector3(0, 0.76, 0.55), Vector3(-10, 0, 0)), DARK)


## A pipe (hollow end) along +Y.
static func _pipe_profile(radius: float, length: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(radius * 0.9, 0.0), Vector2(radius, length * 0.85), Vector2(radius * 1.15, length),
		Vector2(radius * 0.7, length), Vector2(radius * 0.7, length * 0.8)])


## A round bar through `pts` (bumpers, hoops).
static func _bar(kit: KartMeshKit, pts: Array, radius: float, color: Color) -> void:
	kit.add(KartMeshKit.tube(PackedVector3Array(pts), PackedFloat32Array([radius]), 6), Transform3D.IDENTITY, color)


## A flat wing with rounded ends, spanning x, `chord` deep.
static func _wing(kit: KartMeshKit, at: Vector3, half_span: float, chord: float, color: Color) -> void:
	var t := KartMeshKit.tube(PackedVector3Array([Vector3(-half_span, 0, 0), Vector3(half_span, 0, 0)]), PackedFloat32Array([chord * 0.5]), 8)
	kit.add(t, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-6)) * Basis.from_scale(Vector3(1.0, 0.45, 1.0)), at), color)


## A small self-lit lamp (a dome facing out of the kart's nearest face).
static func _lamp(kit: KartMeshKit, at: Vector3, color: Color, radius: float) -> void:
	var g := kit.glow
	var o := kit.outline
	kit.glow = 0.85
	kit.outline = 0.4
	var out := Vector3(0, 0, signf(at.z))
	var b := Basis.looking_at(out, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	kit.add(KartMeshKit.lathe(_dome(), 6), Transform3D(b.scaled_local(Vector3(radius, radius * 0.6, radius)), at), Color(color.r, color.g, color.b, 1.0))
	kit.glow = g
	kit.outline = o


## A low dome in three rings (eyes, blush, glints): the cheapest round bump.
static func _flat() -> PackedVector2Array:
	return PackedVector2Array([Vector2(1.0, 0.0), Vector2(0.72, 0.8), Vector2(0.0, 1.0)])


static func _dome() -> PackedVector2Array:
	return PackedVector2Array([Vector2(1.0, 0.0), Vector2(0.9, 0.45), Vector2(0.55, 0.85), Vector2(0.0, 1.0)])


static func _steering(kit: KartMeshKit, l: Dictionary) -> void:
	var K := KartMeshKit
	var s: Vector3 = l.steer
	kit.bone = BODY
	kit.outline = 0.6
	kit.add(K.tube(PackedVector3Array([s + Vector3(0, -0.22, -0.28), s + Vector3(0, -0.02, -0.03)]), PackedFloat32Array([0.025]), 4),
		Transform3D.IDENTITY, DARK)
	kit.bone = STEER
	kit.add(K.torus(0.11, 0.15, 8, 3), K.xf(s, Vector3(-62, 0, 0)), Color(0.12, 0.12, 0.14, 0.6))
	kit.add(K.blob(Vector3(0.045, 0.02, 0.045), 1.0, 1.0, 6, 3), K.xf(s, Vector3(-62, 0, 0)), Color(0.95, 0.8, 0.2, 1.0))
	kit.outline = 1.0
	kit.bone = BODY


## A chunky tyre around its axle (x), a two-tone hub cap outside: three lobes read as spin.
static func _wheel(kit: KartMeshKit, r: Dictionary, at: Vector3, radius: float, width: float, side: float) -> void:
	var K := KartMeshKit
	var hw := width * 0.5
	var ri := radius * 0.6
	var tyre := PackedVector2Array([Vector2(ri, -hw * 0.95), Vector2(radius * 0.86, -hw), Vector2(radius, -hw * 0.55),
		Vector2(radius, hw * 0.55), Vector2(radius * 0.86, hw), Vector2(ri, hw * 0.95)])
	var axle := Basis(Vector3.BACK, PI * 0.5)  # lathe Y -> kart x
	kit.add(K.lathe(tyre, 11), Transform3D(axle, at), RUBBER)
	var hub_col := _accent(r)
	if hub_col.get_luminance() < 0.3:
		hub_col = Color(0.95, 0.85, 0.3, 0.9)
	var dark := Color(hub_col.r * 0.55, hub_col.g * 0.55, hub_col.b * 0.55, 0.9)
	kit.paint = func(p: Vector3, _n: Vector3, c: Color) -> Color:
		var a := atan2(p.z, p.x)
		var k := smoothstep(-0.2, 0.2, sin(a * 3.0))
		return dark.lerp(c, k) if Vector2(p.x, p.z).length() > ri * 0.3 else c
	kit.outline = 0.5
	var hub := PackedVector2Array([Vector2(ri * 1.02, 0.0), Vector2(ri * 0.75, hw * 0.28), Vector2(0.0, hw * 0.38)])
	# The hub faces outward (-x on the left wheels, +x on the right).
	var out_b := Basis(Vector3.BACK, -side * PI * 0.5)
	kit.add(K.lathe(hub, 9), Transform3D(out_b, at + Vector3(side * hw * 0.9, 0, 0)), hub_col)
	kit.paint = Callable()
	kit.outline = 1.0


# --- The driver ---

static func _driver(kit: KartMeshKit, r: Dictionary, seat: Vector3, steer: Vector3) -> void:
	var K := KartMeshKit
	var suit: Color = r.get("suit", Color(0.2, 0.2, 0.3))
	suit.a = 0.3
	var paint := _paint(r)
	var accent := _accent(r)
	kit.bone = DRIVER
	kit.ao_y0 = seat.y
	kit.ao_y1 = seat.y + 0.35
	kit.ao_min = 0.7
	# Torso with a chest panel in the kart's colour.
	kit.paint = func(p: Vector3, n: Vector3, c: Color) -> Color:
		var k := smoothstep(0.35, 0.75, -n.z) * (1.0 - smoothstep(0.08, 0.13, absf(p.x)))
		return c.lerp(Color(paint.r, paint.g, paint.b, 0.6), k * smoothstep(-0.12, -0.02, p.y))
	kit.add(K.blob(Vector3(0.21, 0.22, 0.17), 0.9, 1.0, 10, 6), K.xf(seat + Vector3(0, 0.2, 0.0)), suit)
	kit.paint = Callable()
	# Arms to the wheel, white gloves.
	var glove := Color(0.97, 0.97, 0.97, 0.3) if suit.get_luminance() < 0.5 else Color(0.2, 0.2, 0.24, 0.3)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		kit.bone = ARM_L + i
		var sh := seat + Vector3(side * SHOULDER.x, SHOULDER.y, SHOULDER.z)
		var hand := steer + Vector3(side * 0.12, 0.03, 0.02)
		var elbow := sh.lerp(hand, 0.5) + Vector3(side * 0.07, -0.08, 0.0)
		kit.add(K.tube(PackedVector3Array([sh, elbow, hand]), PackedFloat32Array([0.07, 0.06, 0.055]), 5), Transform3D.IDENTITY, suit)
		kit.add(K.blob(Vector3(0.065, 0.06, 0.07), 1.0, 1.0, 6, 3), K.xf(hand), glove)
	kit.ao_min = 1.0
	kit.bone = DRIVER
	var tail := str(r.get("species", "")) in ["fox", "raccoon"]
	if tail:
		_tail(kit, r, seat)
	_head(kit, r, seat + HEAD_C)


static func _tail(kit: KartMeshKit, r: Dictionary, seat: Vector3) -> void:
	var fur := fur_color(r)
	var cols := PackedColorArray()
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var n := 7
	for i in n:
		var t := float(i) / (n - 1)
		pts.append(seat + Vector3(0.16 + 0.3 * t, 0.02 + 0.2 * sin(t * 2.4), 0.3 + 0.36 * t))
		radii.append(lerpf(0.06, 0.13, sin(t * PI * 0.85)) * (1.0 - 0.6 * t * t * t))
		if str(r.species) == "raccoon":
			cols.append(Color(0.22, 0.2, 0.24, 0.1) if i % 2 == 1 else fur)
		else:
			cols.append(WHITE if i >= n - 2 else fur)
	kit.add(KartMeshKit.tube(pts, radii, 5, cols), Transform3D.IDENTITY, Color.WHITE)


## The species' fur colour (COLOR.a = a little sheen).
static func fur_color(r: Dictionary) -> Color:
	match str(r.get("species", "fox")):
		"fox": return Color(1.0, 0.52, 0.16, 0.12)
		"panda": return Color(0.98, 0.98, 0.97, 0.1)
		"frog": return Color(0.45, 0.82, 0.32, 0.5)
		"rabbit": return Color(0.98, 0.95, 0.93, 0.1)
		"bear": return Color(0.5, 0.29, 0.15, 0.1)
		"otter": return Color(0.7, 0.48, 0.3, 0.14)
		"penguin": return Color(0.16, 0.18, 0.28, 0.4)
		"raccoon": return Color(0.62, 0.62, 0.68, 0.1)
	return Color(0.9, 0.6, 0.3, 0.1)


## The helmet's colour: the racer's `helmet` when set (a contrast to its fur), else the kart's.
static func helmet_color(r: Dictionary) -> Color:
	var c: Color = r.get("helmet", r.get("color", Color(0.9, 0.3, 0.2)))
	return Color(c.r, c.g, c.b, 1.0)


static func head_radii(r: Dictionary) -> Vector3:
	match str(r.get("species", "")):
		"frog": return Vector3(0.38, 0.26, 0.31)
		"penguin": return Vector3(0.33, 0.32, 0.31)
		"bear", "panda": return Vector3(0.35, 0.31, 0.31)
	return HEAD_R


## The eyes' (x, y) on the face, from the head's centre.
static func eye_spot(r: Dictionary) -> Vector2:
	match str(r.get("species", "")):
		"frog": return Vector2(0.15, 0.2)
		"penguin": return Vector2(0.12, 0.04)
	return Vector2(0.125, 0.02)


# --- The head: fur, face, ears, eyes, helmet and goggles ---

static func _head(kit: KartMeshKit, r: Dictionary, h: Vector3) -> void:
	var K := KartMeshKit
	var sp := str(r.get("species", "fox"))
	var fur := fur_color(r)
	var hr := head_radii(r)
	var eye := eye_spot(r)
	var black := BLACK
	kit.bone = HEAD
	# The head, painted per species (cheeks, faces, bellies).
	kit.paint = _fur_painter(sp, hr)
	kit.add(K.blob(hr, 1.0, 1.0, 16, 10), Transform3D(Basis.IDENTITY, h), fur)
	kit.paint = Callable()
	var muzzle := WHITE
	var nose := black
	var mr := Vector3(0.12, 0.085, 0.1)
	var my := -0.085
	match sp:
		"fox":
			mr = Vector3(0.12, 0.08, 0.15)
		"bear":
			muzzle = Color(0.92, 0.74, 0.5, 0.1)
			mr = Vector3(0.14, 0.1, 0.11)
		"otter":
			muzzle = Color(0.95, 0.86, 0.7, 0.1)
			mr = Vector3(0.16, 0.095, 0.1)
		"rabbit":
			nose = Color(1.0, 0.45, 0.58, 0.9)
			mr = Vector3(0.1, 0.075, 0.08)
		"raccoon":
			mr = Vector3(0.11, 0.075, 0.12)
		"frog", "penguin":
			mr = Vector3.ZERO
	# Masks and patches sit under the eyes.
	if sp == "panda":
		for side: float in [-1.0, 1.0]:
			var t := K.on_surface(hr, side * eye.x * 1.05, eye.y - 0.01, 0.012)
			t.basis = t.basis * Basis(Vector3.UP, side * 0.5)
			kit.outline = 0.0
			kit.add(K.lathe(_flat(), 9), Transform3D(t.basis.scaled_local(Vector3(0.085, 0.03, 0.11)), h + t.origin), Color(0.1, 0.1, 0.12, 0.3))
			kit.outline = 1.0
	elif sp == "raccoon":
		kit.outline = 0.0
		for side: float in [-1.0, 1.0]:
			var t := K.on_surface(hr, side * (eye.x + 0.03), eye.y + 0.005, 0.012)
			kit.add(K.lathe(_flat(), 9), Transform3D(t.basis.scaled_local(Vector3(0.13, 0.03, 0.08)), h + t.origin), Color(0.17, 0.16, 0.2, 0.3))
		kit.outline = 1.0
	elif sp == "frog":
		for side: float in [-1.0, 1.0]:
			kit.add(K.blob(Vector3(0.13, 0.12, 0.12), 1.0, 1.0, 10, 6), Transform3D(Basis.IDENTITY, h + Vector3(side * eye.x, eye.y - 0.02, -0.12)), fur)
	# Muzzle, nose and smile.
	var front := h + Vector3(0, my, -hr.z * 0.8)
	if mr != Vector3.ZERO:
		kit.add(K.blob(mr, 1.0, 1.0, 8, 5), Transform3D(Basis.IDENTITY, front), muzzle)
		var tip := front + Vector3(0, mr.y * 0.45, -mr.z * 0.92)
		kit.outline = 0.4
		kit.add(K.blob(Vector3(0.045, 0.03, 0.03), 1.0, 1.0, 6, 4), Transform3D(Basis.IDENTITY, tip), nose)
		kit.outline = 0.0
		_smile(kit, front + Vector3(0, -mr.y * 0.35, -mr.z * 0.88), 0.045)
		if sp == "otter":
			for side: float in [-1.0, 1.0]:
				for w in 2:
					var root := front + Vector3(side * mr.x * 0.7, mr.y * (0.1 - w * 0.35), -mr.z * 0.55)
					var end := root + Vector3(side * 0.13, 0.03 - w * 0.05, 0.02)
					kit.add(K.tube(PackedVector3Array([root, root.lerp(end, 0.5) + Vector3(0, 0.012, 0), end]),
						PackedFloat32Array([0.006, 0.005, 0.003]), 3), Transform3D.IDENTITY, Color(0.3, 0.2, 0.16, 0.2))
		if sp == "rabbit":
			kit.outline = 0.4
			kit.add(K.blob(Vector3(0.035, 0.03, 0.012), 0.5, 0.5, 6, 3), Transform3D(Basis.IDENTITY, front + Vector3(0, -mr.y * 0.75, -mr.z * 0.9)), WHITE)
		kit.outline = 1.0
	elif sp == "penguin":
		kit.outline = 0.6
		var t := K.on_surface(hr, 0.0, -0.06, 0.02)
		kit.add(K.lathe(PackedVector2Array([Vector2(0.075, 0.0), Vector2(0.06, 0.06), Vector2(0.0, 0.15)]), 8),
			Transform3D(t.basis.scaled_local(Vector3(1.3, 1.0, 0.8)), h + t.origin), Color(1.0, 0.62, 0.12, 0.8))
		kit.outline = 0.0
		_smile(kit, h + K.on_surface(hr, 0.0, -0.15, 0.005).origin, 0.04)
		kit.outline = 1.0
	else:  # frog: a wide grin
		kit.outline = 0.0
		_smile(kit, h + K.on_surface(hr, 0.0, -0.07, 0.006).origin, 0.15)
		kit.outline = 1.0
	# Blush.
	kit.outline = 0.0
	kit.glow = 0.25
	for side: float in [-1.0, 1.0]:
		var t := K.on_surface(hr, side * (eye.x + 0.07), eye.y - 0.1, 0.006)
		kit.add(K.lathe(_flat(), 7), Transform3D(t.basis.scaled_local(Vector3(0.05, 0.01, 0.032)), h + t.origin), Color(1.0, 0.5, 0.58, 0.0))
	kit.glow = 0.0
	kit.outline = 1.0
	# Eyes.
	kit.bone = EYES
	var iris: Color = r.get("eyes", Color(0.3, 0.2, 0.1))
	for side: float in [-1.0, 1.0]:
		var at := Vector2(side * eye.x, eye.y)
		if sp == "frog":
			var bump := h + Vector3(side * eye.x, eye.y - 0.02, -0.12)
			var t := K.on_surface(Vector3(0.13, 0.12, 0.12), 0.0, 0.03, 0.01)
			_eye(kit, Transform3D(t.basis, bump + t.origin), iris, side, 1.0)
		else:
			var t := K.on_surface(hr, at.x, at.y, 0.012)
			_eye(kit, Transform3D(t.basis, h + t.origin), iris, side, 1.0)
	# Ears (and the penguin's tuft) on their own bone, for the speed sweep.
	kit.bone = EARS
	_ears(kit, sp, h, hr, fur)
	kit.bone = HEAD
	_helmet(kit, r, h, hr)


## Paints fur: pale cheeks and chins, faces, bellies.
static func _fur_painter(sp: String, hr: Vector3) -> Callable:
	return func(p: Vector3, n: Vector3, c: Color) -> Color:
		var front := smoothstep(0.1, 0.6, -n.z)
		match sp:
			"fox", "raccoon":
				var k := smoothstep(-0.02, -0.14, p.y) * smoothstep(0.0, 0.5, -n.z + 0.2)
				return c.lerp(WHITE, k)
			"otter":
				return c.lerp(Color(0.97, 0.9, 0.78, 0.1), smoothstep(0.02, -0.1, p.y) * front)
			"frog":
				return c.lerp(Color(0.86, 0.95, 0.6, 0.4), smoothstep(-0.05, -0.2, p.y))
			"penguin":
				# A white heart of a face.
				var heart := smoothstep(0.5, 0.75, -n.z) * (1.0 - smoothstep(0.1, 0.16, p.y - absf(p.x) * 0.5))
				return c.lerp(Color(0.98, 0.98, 1.0, 0.2), clampf(heart + smoothstep(-0.12, -0.25, p.y) * front, 0.0, 1.0))
		return c


## One big cartoon eye at `t` (+Y out of the face, +Z up): a white, a deep iris with a pupil, and
## two self-lit glints (no outlines but the white's soft rim).
static func _eye(kit: KartMeshKit, t: Transform3D, iris: Color, side: float, size: float) -> void:
	var K := KartMeshKit
	var s := size
	kit.outline = 0.55
	kit.add(K.lathe(_flat(), 9), Transform3D(t.basis.scaled_local(Vector3(0.068, 0.025, 0.088) * s), t.origin), Color(0.98, 0.98, 1.0, 0.9))
	kit.outline = 0.0
	var iris_cols := PackedColorArray([Color(iris.r * 1.6, iris.g * 1.6, iris.b * 1.6, 1.0), Color(iris.r, iris.g, iris.b, 1.0),
		Color(0.02, 0.02, 0.03, 1.0)])
	var it := t.origin + t.basis * Vector3(-side * 0.006, 0.0, -0.008) * s
	kit.add(K.lathe(_flat(), 9, iris_cols), Transform3D(t.basis.scaled_local(Vector3(0.052, 0.034, 0.068) * s), it), Color.WHITE)
	kit.glow = 1.0
	var g1 := t.origin + t.basis * Vector3(side * 0.016, 0.03, 0.026) * s
	kit.add(K.lathe(_flat(), 6), Transform3D(t.basis.scaled_local(Vector3(0.018, 0.012, 0.022) * s), g1), Color(1, 1, 1, 0.0))
	var g2 := t.origin + t.basis * Vector3(-side * 0.014, 0.03, -0.026) * s
	kit.add(K.lathe(_flat(), 4), Transform3D(t.basis.scaled_local(Vector3(0.009, 0.01, 0.009) * s), g2), Color(1, 1, 1, 0.0))
	kit.glow = 0.0
	kit.outline = 1.0


static func _smile(kit: KartMeshKit, at: Vector3, width: float) -> void:
	var pts := PackedVector3Array()
	for i in 4:
		var u := (i / 3.0) * 2.0 - 1.0
		pts.append(at + Vector3(u * width, -0.02 * (1.0 - u * u) + 0.004, -0.004 * (1.0 - u * u)))
	kit.add(KartMeshKit.tube(pts, PackedFloat32Array([0.009]), 4), Transform3D.IDENTITY, Color(0.32, 0.1, 0.12, 0.6))


static func _ears(kit: KartMeshKit, sp: String, h: Vector3, hr: Vector3, fur: Color) -> void:
	var K := KartMeshKit
	var inner := Color(1.0, 0.72, 0.72, 0.1)
	for side: float in [-1.0, 1.0]:
		match sp:
			"fox", "raccoon":
				var tip := BLACK if sp == "fox" else Color(0.2, 0.19, 0.23, 0.1)
				var prof := PackedVector2Array([Vector2(0.11, 0.0), Vector2(0.105, 0.1), Vector2(0.07, 0.22), Vector2(0.025, 0.31), Vector2(0.0, 0.33)])
				var cols := PackedColorArray([fur, fur, fur, tip, tip])
				var b := Basis.from_euler(Vector3(deg_to_rad(-8), 0, deg_to_rad(-side * 24))).scaled_local(Vector3(1.0, 1.0, 0.45))
				var base := h + Vector3(side * 0.19, hr.y * 0.62, 0.02)
				kit.add(K.lathe(prof, 7, cols), Transform3D(b, base), Color.WHITE)
				kit.outline = 0.0
				kit.add(K.lathe(prof, 5), Transform3D(b * Basis.from_scale(Vector3(0.6, 0.72, 0.5)), base + b * Vector3(0, 0.03, -0.05)), WHITE if sp == "fox" else inner)
				kit.outline = 1.0
			"rabbit":
				var prof := PackedVector2Array([Vector2(0.07, 0.0), Vector2(0.09, 0.14), Vector2(0.085, 0.3), Vector2(0.055, 0.43), Vector2(0.0, 0.49)])
				var b := Basis.from_euler(Vector3(deg_to_rad(-10), 0, deg_to_rad(-side * 12))).scaled_local(Vector3(1.0, 1.0, 0.45))
				var base := h + Vector3(side * 0.12, hr.y * 0.7, 0.04)
				kit.add(K.lathe(prof, 7), Transform3D(b, base), fur)
				kit.outline = 0.0
				kit.add(K.lathe(prof, 5), Transform3D(b * Basis.from_scale(Vector3(0.6, 0.85, 0.5)), base + b * Vector3(0, 0.02, -0.04)), PINK)
				kit.outline = 1.0
			"bear", "panda", "otter":
				var rad := 0.085 if sp == "otter" else 0.12
				var col := Color(0.1, 0.1, 0.12, 0.2) if sp == "panda" else fur
				var c := h + Vector3(side * hr.x * (0.82 if sp == "otter" else 0.76), hr.y * (0.62 if sp == "otter" else 0.82), 0.04)
				kit.add(K.blob(Vector3(rad, rad, rad * 0.55), 1.0, 1.0, 8, 5), Transform3D(Basis(Vector3.BACK, -side * 0.35), c), col)
				kit.outline = 0.0
				var ic := inner if sp != "panda" else Color(0.25, 0.22, 0.25, 0.2)
				kit.add(K.blob(Vector3(rad * 0.6, rad * 0.6, rad * 0.3), 1.0, 1.0, 6, 4), Transform3D(Basis(Vector3.BACK, -side * 0.35), c + Vector3(0, 0, -rad * 0.32)), ic)
				kit.outline = 1.0
			"penguin":
				if side > 0.0:
					for i in 3:
						var a := (i - 1) * 0.45
						var b := Basis.from_euler(Vector3(-0.4, 0, a))
						kit.add(K.lathe(PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.02, 0.07), Vector2(0.0, 0.11)]), 5),
							Transform3D(b, h + Vector3(0, hr.y * 0.95, 0.04)), fur)


## The open-face helmet in the kart's colour with an accent stripe and a goggle strap, the
## goggles pushed up on its brow.
static func _helmet(kit: KartMeshKit, r: Dictionary, h: Vector3, hr: Vector3) -> void:
	var K := KartMeshKit
	var paint := helmet_color(r)
	var accent := _accent(r) if not r.has("helmet") else _paint(r)
	var strap := Color(0.14, 0.14, 0.17, 0.3)
	var radii := Vector3(hr.x * 1.1, hr.y * 1.16, hr.z * 1.12)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(34))
	var at := h + Vector3(0, 0.025, 0.035)
	kit.paint = func(p: Vector3, n: Vector3, c: Color) -> Color:
		var stripe := 1.0 - smoothstep(0.035, 0.06, absf(p.x))
		var band := 1.0 - smoothstep(0.022, 0.04, absf(p.y - radii.y * 0.18))
		return c.lerp(accent, stripe * (1.0 - band)).lerp(strap, band)
	kit.add(K.blob(radii, 1.0, 1.0, 16, 7, PI * 0.56), Transform3D(tilt, at), paint)
	kit.paint = Callable()
	# The goggles on the band, at the front.
	var gl := Color(0.35, 0.85, 1.0, 1.0)
	var rim := Color(0.85, 0.85, 0.9, 1.0)
	var cols := PackedColorArray([rim, rim, gl, gl, gl])
	var prof := PackedVector2Array([Vector2(1.0, 0.0), Vector2(0.92, 0.55), Vector2(0.78, 0.52), Vector2(0.45, 0.64), Vector2(0.0, 0.68)])
	for side: float in [-1.0, 1.0]:
		var t := K.on_surface(radii, side * 0.11, radii.y * 0.18, 0.01)
		kit.outline = 0.6
		kit.add(K.lathe(prof, 8, cols), Transform3D((tilt * t.basis).scaled_local(Vector3(0.078, 0.08, 0.066)), at + tilt * t.origin), Color.WHITE)
	kit.outline = 1.0


static func _scaled(mesh: ArrayMesh, s: float) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i] *= s
	arrays[Mesh.ARRAY_VERTEX] = v
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
