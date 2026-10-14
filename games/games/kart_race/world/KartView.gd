class_name KartView
extends Node3D
## One kart on screen (#43): a chunky toy kart and its animal driver in a helmet, built in code
## (KartMeshKit) and drawn with the hand-lit toon shader and an outline (KartLook). It only reads
## a `KartState` (`sync`, every frame): the wheels spin and the front ones steer, the body leans
## into turns and squashes over bumps, the driver leans and bobs, and a soft shadow stretches
## away from the low sun.
##
## Anchors (`anchor(name)`, Node3D markers that follow the rig): exhaust_l, exhaust_r, wheel_fl,
## wheel_fr, wheel_rl, wheel_rr, driver_head, item_hold, shadow. Effects and item views attach
## to them.
##
## Draw calls: body + outline, driver + outline, wheels (one MultiMesh) + outline, number, shadow (8).

const ANCHORS := ["exhaust_l", "exhaust_r", "wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr",
	"driver_head", "item_hold", "shadow"]
const WHEEL_RADIUS := 0.3  ## front; the rear ones are REAR_SCALE bigger
const REAR_SCALE := 1.15
const BODY_LEAN := 0.09  ## radians of body roll at full steer
const DRIVER_LEAN := 0.32  ## the driver leans further, into the turn
const STEER_ANGLE := 0.42  ## front wheels at full steer
const SPIN_TURNS := 2.0  ## turns of the body over a spin-out
const WHEELS := [Vector3(-0.68, 0.0, -0.72), Vector3(0.68, 0.0, -0.72), Vector3(-0.7, 0.0, 0.68), Vector3(0.7, 0.0, 0.68)]
## Race numbers by roster order.
const NUMBERS := {"fox": 7, "panda": 22, "frog": 5, "rabbit": 12, "bear": 33, "otter": 9, "penguin": 44, "raccoon": 18}

var racer := {}
## Set by effects: an extra body yaw (a drift's slide, radians, + = nose left), and a 0-1 boost glow.
var slide := 0.0
var boost_glow := 0.0

var _body: Node3D  ## leans, squashes and spins; the anchors that move with the kart live under it
var _driver: Node3D
var _wheels: MultiMesh
var _shadow: MeshInstance3D
var _number: Label3D
var _anchors := {}
var _wheel_turn := 0.0
var _squash := 0.0
var _squash_v := 0.0
var _last_y := 0.0
var _lean := 0.0
var _time := 0.0
var _phase := 0.0
var _mat: ShaderMaterial
var _shown_glow := 0.0

## The inverted-hull outlines (a dev switch: KartRace's tuning file, [render] outlines).
static var outlines := true
static var _shadow_material: StandardMaterial3D
static var _wheel_mesh: ArrayMesh
static var _materials := {}


func setup(racer_info: Dictionary) -> void:
	racer = racer_info
	var id := str(racer.get("id", "racer"))
	name = "Kart_%s" % id
	_phase = float(hash(id) % 1000) / 1000.0 * TAU
	_mat = _material_for(id)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_body.add_child(KartMeshKit.mesh_node(body_mesh(racer), _mat, "Hull"))
	_driver = Node3D.new()
	_driver.name = "Driver"
	_driver.position = Vector3(0.0, 0.5, 0.18)
	_body.add_child(_driver)
	_driver.add_child(KartMeshKit.mesh_node(driver_mesh(racer), _mat, "DriverMesh"))
	_number = Label3D.new()
	_number.name = "Number"
	_number.text = str(NUMBERS.get(id, 1))
	_number.font = KartTheme.display()
	_number.font_size = 72
	_number.outline_size = 18
	_number.outline_modulate = Color(0.1, 0.06, 0.2)
	_number.pixel_size = 0.0036
	_number.position = Vector3(0.0, 1.0, 1.21)
	_number.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	_number.double_sided = false
	_number.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_number)
	# Wheels: one MultiMesh of four.
	_wheels = MultiMesh.new()
	_wheels.transform_format = MultiMesh.TRANSFORM_3D
	_wheels.mesh = wheel_mesh()
	_wheels.instance_count = 4
	var wheels := MultiMeshInstance3D.new()
	wheels.name = "Wheels"
	wheels.multimesh = _wheels
	wheels.material_override = _material_for("wheels")
	wheels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wheels)
	_shadow = MeshInstance3D.new()
	_shadow.name = "shadow"
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.2, 4.4)
	_shadow.mesh = quad
	_shadow.material_override = _blob()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_anchors["shadow"] = _shadow
	_marker("exhaust_l", _body, Vector3(-0.22, 0.5, 1.3))
	_marker("exhaust_r", _body, Vector3(0.22, 0.5, 1.3))
	for i in 4:
		_marker(["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"][i], self, WHEELS[i] + Vector3.UP * WHEEL_RADIUS * (1.0 if i < 2 else REAR_SCALE))
	_marker("driver_head", _driver, Vector3(0.0, 0.8, -0.02))
	_marker("item_hold", _body, Vector3(0.0, 1.45, 0.9))
	_pose_wheels(0.0)


## Places and poses the kart from its state (every frame).
func sync(k: KartState, dt: float) -> void:
	_time += dt
	var up := k.normal if k.normal.length_squared() > 0.5 else Vector3.UP
	var fwd := k.forward()
	fwd = (fwd - up * fwd.dot(up)).normalized()
	transform = Transform3D(Basis.looking_at(fwd, up), k.pos)
	# Squash and stretch: a spring driven by vertical speed changes (crests, dips, hops).
	if dt > 0.0:
		var vy := (k.pos.y + k.hop - _last_y) / dt
		_last_y = k.pos.y + k.hop
		_squash_v += (-_squash * 160.0 - _squash_v * 11.0) * dt - clampf(vy * 0.02, -0.6, 0.6) * dt * 30.0
		_squash = clampf(_squash + _squash_v * dt, -0.12, 0.12)
	var idle := 0.012 * sin(_time * 38.0 + _phase) * clampf(1.0 - k.speed / 6.0, 0.0, 1.0)
	var sq := _squash + idle
	var spin := 0.0
	if k.spin_time > 0.0:
		spin = TAU * SPIN_TURNS * (k.spin_time / KartPhysics.SPIN_SEC)
	_lean = lerpf(_lean, k.steer, 1.0 - exp(-8.0 * dt))
	var basis := Basis(Vector3.UP, spin + slide) * Basis(Vector3.BACK, -_lean * BODY_LEAN)
	_body.transform = Transform3D(basis.scaled(Vector3(1.0 - sq * 0.5, 1.0 + sq, 1.0 - sq * 0.5)), Vector3(0.0, k.hop, 0.0))
	_driver.rotation = Vector3(-0.05 + sin(_time * 3.1 + _phase) * 0.02, -_lean * 0.25, -_lean * DRIVER_LEAN)
	_wheel_turn = fmod(_wheel_turn + k.speed / WHEEL_RADIUS * dt, TAU)
	_pose_wheels(k.steer)
	# The long low-sun shadow: on the road, stretched away from the sun (its texture is darkest
	# at the kart's end), widest across the kart.
	var away := Vector3(-KartLook.SUN_DIR.x, 0.0, -KartLook.SUN_DIR.z).normalized()
	var across := absf(away.dot(fwd.cross(up).normalized()))
	var sb := Basis.looking_at(-away, up).scaled(Vector3(lerpf(1.0, 0.95, across), 1.0, lerpf(0.62, 0.85, across)))
	_shadow.global_transform = Transform3D(sb, k.pos + away * lerpf(0.55, 0.95, across) + up * 0.035)
	if boost_glow != _shown_glow:
		_shown_glow = boost_glow
		_mat.set_shader_parameter("flash", boost_glow * 0.18)


## One of the ANCHORS, or null.
func anchor(anchor_name: String) -> Node3D:
	return _anchors.get(anchor_name)


func _pose_wheels(steer: float) -> void:
	var spin := Basis(Vector3.RIGHT, -_wheel_turn)
	var turn := Basis(Vector3.UP, -steer * STEER_ANGLE)
	for i in 4:
		var scale := 1.0 if i < 2 else REAR_SCALE
		var b := (turn * spin if i < 2 else spin).scaled(Vector3(scale * (1.0 if i < 2 else 1.2), scale, scale))
		var p: Vector3 = WHEELS[i] + Vector3.UP * WHEEL_RADIUS * scale
		_wheels.set_instance_transform(i, Transform3D(b, p))


func _marker(anchor_name: String, parent: Node3D, at: Vector3) -> void:
	var m := Node3D.new()
	m.name = anchor_name
	m.position = at
	parent.add_child(m)
	_anchors[anchor_name] = m


# --- Models (static, so portraits and tests can build them) ---

## The kart: a glossy tub with a nose cone and wing, side pods, a seat, a steering wheel, an
## engine with twin exhausts and a rear spoiler. COLOR.a = gloss.
static func body_mesh(r: Dictionary) -> ArrayMesh:
	var paint: Color = r.get("color", Color(0.9, 0.3, 0.2))
	var accent: Color = r.get("accent", Color.WHITE)
	paint.a = 1.0
	accent.a = 1.0
	if accent.get_luminance() < 0.2 and paint.get_luminance() < 0.25:
		accent = Color(0.95, 0.75, 0.2)
	var dark := Color(0.13, 0.13, 0.15, 0.15)
	var chrome := Color(0.78, 0.78, 0.82, 1.0)
	var kit := KartMeshKit.new()
	kit.ao_y0 = 0.12
	kit.ao_y1 = 0.75
	kit.ao_min = 0.55
	var K := KartMeshKit
	kit.add(K.box(Vector3(1.15, 0.1, 1.95)), K.xf(Vector3(0, 0.22, 0.05)), dark)
	kit.add(K.capsule(0.3, 2.0, 12, 2), K.xf(Vector3(0, 0.42, 0.0), Vector3(90, 0, 0), Vector3(1.45, 1.0, 0.62)), paint)
	kit.add(K.sphere(0.3, 12, 5), K.xf(Vector3(0, 0.36, -0.92), Vector3.ZERO, Vector3(1.35, 0.55, 1.7)), paint)
	kit.add(K.box(Vector3(1.55, 0.07, 0.34)), K.xf(Vector3(0, 0.19, -1.14)), accent)
	for side: float in [-1.0, 1.0]:
		kit.add(K.box(Vector3(0.06, 0.22, 0.4)), K.xf(Vector3(side * 0.78, 0.25, -1.12)), paint)
		kit.add(K.capsule(0.17, 1.05, 8, 1), K.xf(Vector3(side * 0.5, 0.33, 0.12), Vector3(90, 0, 0)), accent)
		kit.add(K.cylinder(0.075, 0.085, 0.5, 8), K.xf(Vector3(side * 0.22, 0.5, 1.06), Vector3(90, 0, 0)), chrome)
		kit.add(K.cylinder(0.05, 0.05, 0.02, 8), K.xf(Vector3(side * 0.22, 0.5, 1.32), Vector3(90, 0, 0)), Color(0.05, 0.05, 0.05, 0.0))
		kit.add(K.box(Vector3(0.06, 0.5, 0.1)), K.xf(Vector3(side * 0.36, 0.76, 0.98)), dark)
		kit.add(K.box(Vector3(0.05, 0.36, 0.5)), K.xf(Vector3(side * 0.74, 1.0, 1.0)), paint)
	kit.add(K.torus(0.25, 0.36, 12, 4), K.xf(Vector3(0, 0.58, -0.04), Vector3.ZERO, Vector3(1.15, 1.0, 1.45)), dark)
	kit.add(K.capsule(0.2, 0.62, 8, 1), K.xf(Vector3(0, 0.72, 0.36), Vector3(-18, 0, 0), Vector3(1.2, 1.0, 0.5)), Color(0.1, 0.1, 0.12, 0.3))
	kit.add(K.sphere(0.28, 10, 4), K.xf(Vector3(0, 0.62, 0.66), Vector3.ZERO, Vector3(1.1, 0.9, 1.25)), paint)
	kit.add(K.box(Vector3(0.62, 0.3, 0.42)), K.xf(Vector3(0, 0.4, 0.8)), Color(0.42, 0.42, 0.47, 0.8))
	kit.add(K.box(Vector3(1.48, 0.08, 0.4)), K.xf(Vector3(0, 1.0, 1.0), Vector3(-8, 0, 0)), accent)
	kit.add(K.cylinder(0.18, 0.18, 0.03, 10), K.xf(Vector3(0, 0.53, -0.95), Vector3(-75, 0, 0)), Color(0.98, 0.98, 0.98, 0.6))
	kit.add(K.cylinder(0.028, 0.028, 0.42, 6), K.xf(Vector3(0, 0.66, -0.42), Vector3(-55, 0, 0)), dark)
	kit.add(K.torus(0.11, 0.16, 10, 4), K.xf(Vector3(0, 0.8, -0.3), Vector3(-60, 0, 0)), Color(0.16, 0.16, 0.18, 0.6))
	return kit.commit()


## A fat tyre with a coloured hub and spokes, axis along x (unit: front wheel).
static func wheel_mesh() -> ArrayMesh:
	if _wheel_mesh:
		return _wheel_mesh
	var kit := KartMeshKit.new()
	var K := KartMeshKit
	kit.add(K.cylinder(WHEEL_RADIUS, WHEEL_RADIUS, 0.32, 16), K.xf(Vector3.ZERO, Vector3(0, 0, 90)), Color(0.11, 0.11, 0.12, 0.2))
	kit.add(K.torus(WHEEL_RADIUS * 0.72, WHEEL_RADIUS * 1.02, 12, 3), K.xf(Vector3(0.155, 0, 0), Vector3(0, 0, 90), Vector3(1, 0.4, 1)), Color(0.16, 0.16, 0.17, 0.2))
	kit.add(K.torus(WHEEL_RADIUS * 0.72, WHEEL_RADIUS * 1.02, 12, 3), K.xf(Vector3(-0.155, 0, 0), Vector3(0, 0, 90), Vector3(1, 0.4, 1)), Color(0.16, 0.16, 0.17, 0.2))
	kit.add(K.cylinder(0.15, 0.15, 0.34, 10), K.xf(Vector3.ZERO, Vector3(0, 0, 90)), Color(0.95, 0.82, 0.25, 1.0))
	kit.add(K.box(Vector3(0.35, 0.24, 0.05)), K.xf(Vector3.ZERO), Color(0.85, 0.85, 0.9, 1.0))
	kit.add(K.box(Vector3(0.35, 0.05, 0.24)), K.xf(Vector3.ZERO), Color(0.85, 0.85, 0.9, 1.0))
	_wheel_mesh = kit.commit()
	return _wheel_mesh


## The driver: a racing suit with arms on the wheel, a big round animal head and an open-face
## helmet in the kart's colour. Origin at the seat; the head's centre is at (0, 0.8, -0.02).
static func driver_mesh(r: Dictionary) -> ArrayMesh:
	var paint: Color = r.get("color", Color(0.9, 0.3, 0.2))
	var accent: Color = r.get("accent", Color.WHITE)
	paint.a = 1.0
	accent.a = 0.4
	var kit := KartMeshKit.new()
	var K := KartMeshKit
	kit.ao_y0 = -0.1
	kit.ao_y1 = 0.5
	kit.ao_min = 0.6
	var suit := accent
	kit.add(K.capsule(0.2, 0.62, 8, 2), K.xf(Vector3(0, 0.24, 0.02), Vector3(-12, 0, 0), Vector3(1.15, 1.0, 0.95)), suit)
	kit.add(K.box(Vector3(0.06, 0.5, 0.42)), K.xf(Vector3(0, 0.26, -0.01), Vector3(-12, 0, 0)), Color(paint.r, paint.g, paint.b, 0.4))
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.21, 0.42, -0.02)
		var hand := Vector3(side * 0.13, 0.31, -0.42)
		var mid := (shoulder + hand) * 0.5
		var dir := (hand - shoulder).normalized()
		var basis := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
		kit.add(K.capsule(0.07, shoulder.distance_to(hand) + 0.1, 6, 1), Transform3D(basis, mid), suit)
		kit.add(K.sphere(0.075, 6, 3), K.xf(hand), Color(0.97, 0.97, 0.97, 0.3))
	kit.ao_min = 1.0
	_head(kit, r, Vector3(0, 0.8, -0.02))
	return kit.commit()


## The head alone (for portraits), centred at the origin.
static func head_mesh(r: Dictionary) -> ArrayMesh:
	var kit := KartMeshKit.new()
	_head(kit, r, Vector3.ZERO)
	return kit.commit()


static func _head(kit: KartMeshKit, r: Dictionary, h: Vector3) -> void:
	var K := KartMeshKit
	var species := str(r.get("species", r.get("id", "fox")))
	var paint: Color = r.get("color", Color(0.9, 0.3, 0.2))
	paint.a = 1.0
	var black := Color(0.06, 0.05, 0.07, 1.0)
	var white := Color(0.98, 0.97, 0.95, 0.2)
	var pink := Color(1.0, 0.55, 0.62, 0.0)
	var fur := Color(0.95, 0.5, 0.15, 0.1)
	var muzzle := white
	var nose := black
	var head_scale := Vector3(1.05, 0.95, 1.0)
	match species:
		"fox": fur = Color(0.97, 0.5, 0.14, 0.1)
		"panda": fur = Color(0.97, 0.97, 0.96, 0.1)
		"frog":
			fur = Color(0.42, 0.8, 0.3, 0.3)
			head_scale = Vector3(1.22, 0.82, 1.0)
			muzzle = fur
		"rabbit": fur = Color(0.97, 0.94, 0.92, 0.1)
		"bear":
			fur = Color(0.56, 0.35, 0.2, 0.1)
			muzzle = Color(0.88, 0.7, 0.46, 0.1)
		"otter":
			fur = Color(0.52, 0.34, 0.2, 0.1)
			muzzle = Color(0.94, 0.84, 0.66, 0.1)
		"penguin":
			fur = Color(0.12, 0.14, 0.22, 0.3)
		"raccoon":
			fur = Color(0.62, 0.62, 0.66, 0.1)
	kit.add(K.sphere(0.3, 12, 7), K.xf(h, Vector3.ZERO, head_scale), fur)
	var eye_y := 0.04
	var eye_x := 0.105
	var eye_z := -0.265
	match species:
		"fox":
			kit.add(K.sphere(0.13, 7, 3), K.xf(h + Vector3(0, -0.08, -0.24), Vector3.ZERO, Vector3(1.15, 0.75, 1.5)), muzzle)
			for side: float in [-1.0, 1.0]:
				kit.add(K.prism(Vector3(0.2, 0.3, 0.09)), K.xf(h + Vector3(side * 0.17, 0.36, 0.02), Vector3(0, 0, -side * 18)), fur)
				kit.add(K.prism(Vector3(0.1, 0.13, 0.1)), K.xf(h + Vector3(side * 0.205, 0.46, 0.02), Vector3(0, 0, -side * 18)), black)
				kit.add(K.sphere(0.09, 7, 3), K.xf(h + Vector3(side * 0.13, -0.08, -0.2), Vector3.ZERO, Vector3(1, 0.8, 0.8)), white)
		"panda":
			kit.add(K.sphere(0.12, 7, 3), K.xf(h + Vector3(0, -0.08, -0.24), Vector3.ZERO, Vector3(1.2, 0.8, 1.0)), muzzle)
			for side: float in [-1.0, 1.0]:
				kit.add(K.sphere(0.09, 7, 3), K.xf(h + Vector3(side * 0.2, 0.25, 0.03)), black)
				kit.add(K.sphere(0.075, 7, 3), K.xf(h + Vector3(side * 0.11, 0.03, -0.235), Vector3(0, 0, side * 25), Vector3(1.0, 1.35, 0.6)), black)
		"frog":
			eye_y = 0.21
			eye_z = -0.17
			eye_x = 0.14
			for side: float in [-1.0, 1.0]:
				kit.add(K.sphere(0.11, 7, 3), K.xf(h + Vector3(side * 0.14, 0.17, -0.1)), fur)
				kit.add(K.sphere(0.085, 7, 3), K.xf(h + Vector3(side * 0.14, 0.2, -0.14)), white)
			kit.add(K.torus(0.16, 0.19, 12, 4), K.xf(h + Vector3(0, -0.07, -0.19), Vector3(90, 0, 0), Vector3(1.3, 1.0, 0.35)), Color(0.85, 0.3, 0.35, 0.0))
		"rabbit":
			kit.add(K.sphere(0.12, 7, 3), K.xf(h + Vector3(0, -0.08, -0.24), Vector3.ZERO, Vector3(1.2, 0.8, 1.0)), muzzle)
			nose = pink
			for side: float in [-1.0, 1.0]:
				kit.add(K.capsule(0.07, 0.52, 8, 2), K.xf(h + Vector3(side * 0.1, 0.5, 0.04), Vector3(-6, 0, -side * 10)), fur)
				kit.add(K.capsule(0.04, 0.4, 6, 2), K.xf(h + Vector3(side * 0.1, 0.5, -0.02), Vector3(-6, 0, -side * 10)), pink)
		"bear":
			kit.add(K.sphere(0.13, 7, 3), K.xf(h + Vector3(0, -0.08, -0.24), Vector3.ZERO, Vector3(1.2, 0.85, 1.0)), muzzle)
			for side: float in [-1.0, 1.0]:
				kit.add(K.sphere(0.095, 7, 3), K.xf(h + Vector3(side * 0.21, 0.25, 0.03)), fur)
				kit.add(K.sphere(0.055, 7, 3), K.xf(h + Vector3(side * 0.21, 0.25, -0.03)), muzzle)
		"otter":
			kit.add(K.sphere(0.17, 7, 3), K.xf(h + Vector3(0, -0.07, -0.2), Vector3.ZERO, Vector3(1.35, 0.85, 1.0)), muzzle)
			for side: float in [-1.0, 1.0]:
				kit.add(K.sphere(0.06, 7, 3), K.xf(h + Vector3(side * 0.24, 0.12, 0.02)), fur)
				for w in 2:
					kit.add(K.box(Vector3(0.16, 0.012, 0.012)), K.xf(h + Vector3(side * 0.2, -0.07 - w * 0.03, -0.3), Vector3(0, 0, side * (8 - w * 16))), Color(0.3, 0.2, 0.15, 0.0))
		"penguin":
			kit.add(K.sphere(0.25, 12, 6), K.xf(h + Vector3(0, -0.03, -0.1), Vector3.ZERO, Vector3(1.05, 0.88, 0.85)), white)
			kit.add(K.cylinder(0.0, 0.07, 0.17, 8), K.xf(h + Vector3(0, -0.05, -0.33), Vector3(-90, 0, 0), Vector3(1.4, 1.0, 0.8)), Color(1.0, 0.6, 0.12, 0.5))
			nose = Color(0, 0, 0, -1)
		"raccoon":
			kit.add(K.sphere(0.12, 7, 3), K.xf(h + Vector3(0, -0.09, -0.24), Vector3.ZERO, Vector3(1.15, 0.75, 1.3)), white)
			kit.add(K.sphere(0.12, 7, 3), K.xf(h + Vector3(0, 0.04, -0.2), Vector3.ZERO, Vector3(2.2, 0.62, 0.9)), Color(0.12, 0.11, 0.13, 0.1))
			for side: float in [-1.0, 1.0]:
				kit.add(K.prism(Vector3(0.2, 0.26, 0.09)), K.xf(h + Vector3(side * 0.18, 0.34, 0.03), Vector3(0, 0, -side * 20)), fur)
				kit.add(K.prism(Vector3(0.1, 0.14, 0.1)), K.xf(h + Vector3(side * 0.18, 0.31, 0.0), Vector3(0, 0, -side * 20)), Color(0.15, 0.14, 0.16, 0.0))
	if nose.a >= 0.0:
		var nz := -0.37 if species in ["fox"] else -0.335
		kit.add(K.sphere(0.045, 6, 3), K.xf(h + Vector3(0, -0.04, nz), Vector3.ZERO, Vector3(1.3, 0.9, 1.0)), Color(nose.r, nose.g, nose.b, 1.0))
	for side: float in [-1.0, 1.0]:
		kit.add(K.sphere(0.048, 6, 3), K.xf(h + Vector3(side * eye_x, eye_y, eye_z), Vector3.ZERO, Vector3(0.9, 1.15, 0.7)), Color(0.05, 0.04, 0.08, 1.0))
		kit.add(K.sphere(0.016, 4, 2), K.xf(h + Vector3(side * eye_x + 0.014, eye_y + 0.022, eye_z - 0.035)), Color(1, 1, 1, 1.0))
		if species != "frog":
			kit.add(K.sphere(0.045, 6, 3), K.xf(h + Vector3(side * 0.17, -0.06, -0.22), Vector3.ZERO, Vector3(1.0, 0.6, 0.5)), Color(1.0, 0.55, 0.6, 0.0))
	# The open-face helmet in the kart's colour, with a white stripe.
	kit.add(K.sphere(0.335, 12, 4, true), K.xf(h + Vector3(0, 0.02, 0.05), Vector3(38, 0, 0), Vector3(1.04, 1.0, 1.06)), paint)
	kit.add(K.sphere(0.34, 12, 4, true), K.xf(h + Vector3(0, 0.02, 0.05), Vector3(38, 0, 0), Vector3(0.22, 1.02, 1.08)), Color(0.98, 0.98, 0.98, 1.0))


static func _material_for(key: String) -> ShaderMaterial:
	if not _materials.has(key):
		_materials[key] = KartLook.kart_material(key != "wheels" and outlines)
	# One material per racer (its boost flash); the wheels share one.
	if key == "wheels":
		return _materials[key]
	var mat: ShaderMaterial = KartLook.kart_material(outlines)
	return mat


## A soft dark ellipse under the kart, shared by every kart.
static func _blob() -> StandardMaterial3D:
	if _shadow_material:
		return _shadow_material
	# An egg: dense at the kart's end (v = 0.3), thinning out along the shadow's length.
	var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var u := (x + 0.5) / 64.0 * 2.0 - 1.0
			var v := (y + 0.5) / 64.0
			var w := lerpf(0.55, 1.0, smoothstep(0.0, 0.35, v)) * lerpf(1.0, 0.75, smoothstep(0.5, 1.0, v))
			var edge := clampf(1.0 - pow(absf(u) / w, 2.0) - pow((v - 0.45) / 0.55, 2.0), 0.0, 1.0)
			var a := smoothstep(0.0, 0.55, edge) * lerpf(0.66, 0.3, smoothstep(0.3, 1.0, v))
			img.set_pixel(x, y, Color(0.08, 0.05, 0.14, a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_fog = true
	_shadow_material = mat
	return mat
