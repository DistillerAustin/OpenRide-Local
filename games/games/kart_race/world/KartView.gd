class_name KartView
extends Node3D
## One kart on screen (#43): a toy kart and its animal driver (KartModels), one mesh on a rigid
## 12-bone rig, drawn with the hand-lit toon shader and a soft outline (KartLook). The rig runs in
## the vertex shader (shaders/rig.gdshaderinc): each frame this sets the bones' matrices on the
## kart's two materials, far cheaper on the Compatibility renderer than a Skeleton3D, whose
## deform pass cost about 0.2 ms a kart even on the desktop. It only reads a `KartState`
## (`sync`, every frame) and poses the bones procedurally:
##
## - the wheels spin at the road speed and the front ones steer; the steering wheel turns;
## - the body rolls into turns, pitches with acceleration, squashes over crests and hops, and
##   spins out;
## - the driver leans into turns and back under boost, breathes, and looks into the corner (or
##   at `look_target`); the ears sweep back with speed; the eyes blink;
## - poses: on the grid the driver looks around; on a spin-out the arms flail, the head wobbles
##   and the eyes squeeze shut; past the finish line the arms go up (both on a podium, a wave
##   otherwise) and the kart bounces.
##
## Anchors (`anchor(name)`, Node3D markers that follow the rig): exhaust_l, exhaust_r, wheel_fl,
## wheel_fr, wheel_rl, wheel_rr, driver_head, item_hold, shadow. Effects and item views attach
## to them.
##
## Draw calls: the kart and driver, its outline, the number (on the helmet) and the shadow (4).
## Two materials (the kart shader and its outline pass); the shadow's is shared by every kart.

const ANCHORS := ["exhaust_l", "exhaust_r", "wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr",
	"driver_head", "item_hold", "shadow"]
const WHEEL_RADIUS := 0.3  ## a typical front wheel (each class has its own: KartModels.layout)
const BODY_LEAN := 0.09  ## radians of body roll at full steer
const DRIVER_LEAN := 0.3  ## the driver leans further, into the turn
const STEER_ANGLE := 0.42  ## front wheels at full steer
const STEERING_WHEEL := 1.3  ## the steering wheel's turn at full steer
const SPIN_TURNS := 2.0  ## turns of the body over a spin-out
const CHEER_RATE := 2.5  ## the celebration blends in over 0.4 s

var racer := {}
## The drift's body yaw (radians, + = nose left), copied from KartState.slide (the physics') in
## `sync`; and a 0-1 boost glow, set by the effects.
var slide := 0.0
var boost_glow := 0.0
## Optional, set by others (items, bots): a world point the driver glances at, weight 0-1.
var look_target := Vector3.ZERO
var look_weight := 0.0

var _mesh: MeshInstance3D
var _line: ShaderMaterial  ## this kart's outline pass (it carries the rig too)
var _poses: Array[Transform3D] = []  ## each bone's pose in its parent's space
var _global: Array[Transform3D] = []
var _skin := PackedFloat32Array()  ## the bones' matrices for the shaders, column-major
var _body: Node3D  ## mirrors the body bone: the anchors that move with the kart live under it
var _driver: Node3D  ## mirrors the driver bone
var _head: Node3D  ## mirrors the head bone
var _shadow: MeshInstance3D
var _number: Label3D
var _anchors := {}
var _rest: Array = []  ## each bone's rest offset from its parent
var _points: Array = []  ## each bone's rest position in kart space
var _radii: Array = []
var _arm_dir: Array = []  ## shoulder to hand, per arm (kart space)
var _column := Vector3.UP  ## the steering column's axis
var _turn_f := 0.0
var _turn_r := 0.0
var _squash := 0.0
var _squash_v := 0.0
var _last_y := 0.0
var _last_speed := 0.0
var _accel := 0.0
var _lean := 0.0
var _look := 0.0
var _time := 0.0
var _phase := 0.0
var _cheer := 0.0
var _blink_at := 2.0
var _mat: ShaderMaterial
var _shown_glow := 0.0

## The outlines (a dev switch: KartRace's tuning file, [render] outlines).
static var outlines := true
static var _shadow_material: StandardMaterial3D
static var _models := {}


## Pose this kart every this many syncs (KartRace sets 3 for far karts); 1 = every frame.
var pose_every := 1
var _pose_skip := 0
var _pose_dt := 0.0

func setup(racer_info: Dictionary) -> void:
	racer = racer_info
	var id := str(racer.get("id", "racer"))
	name = "Kart_%s" % id
	_phase = float(hash(id) % 1000) / 1000.0 * TAU
	_blink_at = 1.0 + fmod(_phase, 3.0)
	var layout := KartModels.layout(KartRoster.kart_class(racer))
	_radii = layout.radii
	_mat = KartLook.material("kart.gdshader")
	_mat.set_shader_parameter("rigged", true)
	if outlines:
		_line = ShaderMaterial.new()
		_line.shader = KartLook.shader("outline.gdshader")
		_line.set_shader_parameter("rigged", true)
		_mat.next_pass = _line
	var pts := KartModels.bone_points(racer)
	_points = pts
	for i in KartModels.BONES.size():
		var parent: int = KartModels.PARENTS[i]
		_rest.append((pts[i] as Vector3) - (pts[parent] as Vector3 if parent >= 0 else Vector3.ZERO))
		_poses.append(Transform3D(Basis.IDENTITY, _rest[i]))
		_global.append(Transform3D.IDENTITY)
	_skin.resize(16 * KartModels.BONES.size())
	_mesh = MeshInstance3D.new()
	_mesh.name = "Model"
	_mesh.mesh = model_mesh(racer)
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The rig moves vertices up to about a metre (a hop, the cheering arms): keep it drawn.
	_mesh.extra_cull_margin = 1.5
	add_child(_mesh)
	for side in 2:
		var sh: Vector3 = pts[KartModels.ARM_L + side]
		var hand: Vector3 = (layout.steer as Vector3) + Vector3((-1.0 if side == 0 else 1.0) * 0.12, 0.03, 0.02)
		_arm_dir.append((hand - sh).normalized())
	_column = Basis(Vector3.RIGHT, deg_to_rad(-62)) * Vector3.UP
	# Node mirrors of the moving bones, for the anchors.
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_driver = Node3D.new()
	_driver.name = "Driver"
	_body.add_child(_driver)
	_head = Node3D.new()
	_head.name = "Head"
	_driver.add_child(_head)
	var body_at: Vector3 = pts[KartModels.BODY]
	_number = Label3D.new()
	_number.name = "Number"
	_number.text = str(racer.get("number", 1))
	_number.font = KartTheme.display()
	_number.font_size = 56
	_number.outline_size = 14
	_number.outline_modulate = Color(0.1, 0.06, 0.2)
	_number.pixel_size = 0.0036
	# On the back of the helmet: the part of a racer the chase camera sees most.
	var hr := KartModels.head_radii(racer)
	var back := Vector3(0.0, 0.45, 0.89).normalized()
	_number.position = KartModels.HEAD_C - KartModels.NECK + Vector3(0.0, 0.025, 0.035) \
		+ back * Vector3(hr.x * 1.1, hr.y * 1.16, hr.z * 1.12) * 1.03
	_number.rotation = Vector3(-0.47, 0.0, 0.0)
	_number.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	_number.double_sided = false
	_number.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(_number)
	_shadow = MeshInstance3D.new()
	_shadow.name = "shadow"
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.2, 4.4)
	_shadow.mesh = quad
	_shadow.material_override = _blob()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_anchors["shadow"] = _shadow
	_marker("exhaust_l", _body, (layout.exhaust[0] as Vector3) - body_at)
	_marker("exhaust_r", _body, (layout.exhaust[1] as Vector3) - body_at)
	for i in 4:
		_marker(["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"][i], self, layout.wheels[i])
	_marker("driver_head", _head, KartModels.HEAD_C - KartModels.NECK)
	_marker("item_hold", _body, (layout.item as Vector3) - body_at)
	_pose(null, 0.0)


## Places and poses the kart from its state (every frame).
func sync(k: KartState, dt: float) -> void:
	_time += dt
	slide = k.slide
	var up := k.normal if k.normal.length_squared() > 0.5 else Vector3.UP
	var fwd := k.forward()
	fwd = (fwd - up * fwd.dot(up)).normalized()
	transform = Transform3D(Basis.looking_at(fwd, up), k.pos)
	if dt > 0.0:
		# Squash and stretch: a spring driven by vertical speed changes (crests, dips, hops).
		var vy := (k.pos.y + k.hop - _last_y) / dt
		_last_y = k.pos.y + k.hop
		_squash_v += (-_squash * 160.0 - _squash_v * 11.0) * dt - clampf(vy * 0.02, -0.6, 0.6) * dt * 30.0
		_squash = clampf(_squash + _squash_v * dt, -0.12, 0.12)
		var a := clampf((k.speed - _last_speed) / dt, -25.0, 25.0)
		_last_speed = k.speed
		_accel = lerpf(_accel, a, 1.0 - exp(-5.0 * dt))
		_turn_f = fmod(_turn_f + k.speed / float(_radii[0]) * dt, TAU)
		_turn_r = fmod(_turn_r + k.speed / float(_radii[2]) * dt, TAU)
		_cheer = move_toward(_cheer, 1.0 if k.finished else 0.0, CHEER_RATE * dt)
	_lean = lerpf(_lean, k.steer, 1.0 - exp(-8.0 * dt))
	# The pose (and its bone upload to both materials) every `pose_every` frames: a far kart's
	# driver needn't breathe at 60 Hz (the main thread is the tablet's bottleneck).
	_pose_dt += dt
	_pose_skip += 1
	if _pose_skip >= pose_every:
		_pose_skip = 0
		_pose(k, _pose_dt)
		_pose_dt = 0.0
	# The low-sun shadow: on the road, stretched away from the sun (its texture is darkest at the
	# kart's end), widest across the kart; smaller and fainter-looking as the kart hops.
	var away := Vector3(-KartLook.SUN_DIR.x, 0.0, -KartLook.SUN_DIR.z).normalized()
	var across := absf(away.dot(fwd.cross(up).normalized()))
	var lift := 1.0 / (1.0 + maxf(k.hop, 0.0) * 1.2)
	var sb := Basis.looking_at(-away, up).scaled(Vector3(lerpf(1.0, 0.95, across) * lift, 1.0, lerpf(0.62, 0.85, across) * lift))
	_shadow.global_transform = Transform3D(sb, k.pos + away * lerpf(0.55, 0.95, across) * lift + up * 0.035)
	if boost_glow != _shown_glow:
		_shown_glow = boost_glow
		_mat.set_shader_parameter("flash", boost_glow * 0.18)


## One of the ANCHORS, or null.
func anchor(anchor_name: String) -> Node3D:
	return _anchors.get(anchor_name)


## The current pose of a bone (for tests and effects), in its parent's space.
func bone_pose(bone_name: String) -> Transform3D:
	return _poses[KartModels.BONES.find(bone_name)]


func _pose(k: KartState, dt: float) -> void:
	var speed := k.speed if k else 0.0
	var steer := k.steer if k else 0.0
	var spin_w := clampf(k.spin_time / 0.25, 0.0, 1.0) if k else 0.0
	var boost := 1.0 if k and k.boost_time > 0.0 else 0.0
	var hop := k.hop if k else 0.0
	var podium := k != null and k.finished and k.place >= 1 and k.place <= 3
	var still := clampf(1.0 - speed / 4.0, 0.0, 1.0)
	var t := _time
	# Body: yaw (spin, slide), roll into the turn, pitch with acceleration, squash, hop, a
	# victory bounce and an idling engine's shiver.
	var spin := 0.0
	if k and k.spin_time > 0.0:
		spin = TAU * SPIN_TURNS * (k.spin_time / KartPhysics.SPIN_SEC)
	var pitch := clampf(_accel * 0.004, -0.07, 0.07)
	var sq := _squash + 0.012 * sin(t * 38.0 + _phase) * still
	var bounce := _cheer * absf(sin(t * 6.0)) * 0.12
	var body_b := Basis(Vector3.UP, spin + slide) * Basis(Vector3.BACK, -_lean * BODY_LEAN) * Basis(Vector3.RIGHT, pitch)
	body_b = body_b.scaled(Vector3(1.0 - sq * 0.5, 1.0 + sq, 1.0 - sq * 0.5))
	var body_xf := Transform3D(body_b, _rest[KartModels.BODY] + Vector3(0.0, hop + bounce, 0.0))
	_set_bone(KartModels.BODY, body_xf)
	_body.transform = body_xf
	# Driver: leans into the turn and back under boost, breathes, sways when cheering.
	var breathe := sin(t * 3.1 + _phase) * 0.02
	var flail := sin(t * 17.0) * spin_w
	var driver_b := Basis.from_euler(Vector3(-0.05 + breathe - boost * 0.12 + _cheer * 0.08,
		-_lean * 0.25 + flail * 0.2, -_lean * DRIVER_LEAN + sin(t * 4.0) * 0.12 * _cheer))
	var driver_xf := Transform3D(driver_b, _rest[KartModels.DRIVER] + Vector3(0.0, absf(breathe) * 0.4, 0.0))
	_set_bone(KartModels.DRIVER, driver_xf)
	_driver.transform = driver_xf
	# Head: looks into the corner (or at a target), looks around on the grid, wobbles when dizzy,
	# tips back to cheer.
	var look := steer * -0.45 - slide * 0.6
	look += still * (1.0 - _cheer) * 0.5 * sin(t * 0.7 + _phase) * sin(t * 0.31 + _phase * 2.0)
	if look_weight > 0.0 and is_inside_tree():
		var local := global_transform.affine_inverse() * look_target
		look = lerpf(look, clampf(atan2(-local.x, -local.z), -1.3, 1.3), clampf(look_weight, 0.0, 1.0))
	_look = lerpf(_look, look, 1.0 - exp(-6.0 * dt)) if dt > 0.0 else look
	var wobble := sin(t * 11.0) * 0.35 * spin_w
	var head_b := Basis.from_euler(Vector3(-0.04 * _cheer - 0.1 * spin_w * sin(t * 7.0), _look, wobble + _lean * 0.1))
	var head_xf := Transform3D(head_b, _rest[KartModels.HEAD])
	_set_bone(KartModels.HEAD, head_xf)
	_head.transform = head_xf
	# Eyes: a blink every few seconds; squeezed shut when dizzy; happy squint when cheering.
	var open := 1.0
	if t >= _blink_at:
		var u := (t - _blink_at) / 0.14
		open = absf(u * 2.0 - 1.0)
		if u >= 1.0:
			_blink_at = t + 2.2 + fmod(_phase * 13.7 + t, 3.0)
	open = minf(open, lerpf(1.0, 0.18, spin_w))
	open = minf(open, lerpf(1.0, 0.35, _cheer if podium else 0.0))
	_set_bone(KartModels.EYES, Transform3D(Basis.from_scale(Vector3(1.0, maxf(open, 0.08), 1.0)), _rest[KartModels.EYES]))
	# Ears: swept back by speed, flicked by bumps.
	var ears := clampf(speed / 30.0, 0.0, 1.0) * 0.45 + _squash * 2.0 + boost * 0.15
	_set_bone(KartModels.EARS, Transform3D(Basis(Vector3.RIGHT, ears), _rest[KartModels.EARS]))
	# Arms: on the wheel, turning with it; up to cheer; flailing when spun.
	var wheel_turn := -steer * STEERING_WHEEL
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var q := Quaternion(_column, wheel_turn * 0.35)
		var raise := _cheer if (podium or i == 1) else 0.0
		raise = maxf(raise, spin_w * (0.6 + 0.4 * sin(t * 13.0 + i * 2.0)))
		if raise > 0.0:
			var wave := sin(t * 9.0 + i * 1.7) * 0.35
			var target := Vector3(side * (0.55 + wave * 0.5), 1.0, -0.15).normalized()
			var from: Vector3 = _arm_dir[i]
			q = q.slerp(Quaternion(from, target), raise)
		_set_bone(KartModels.ARM_L + i, Transform3D(Basis(q), _rest[KartModels.ARM_L + i]))
	_set_bone(KartModels.STEER, Transform3D(Basis(_column, wheel_turn), _rest[KartModels.STEER]))
	# Wheels.
	var spin_f := Basis(Vector3.RIGHT, -_turn_f)
	var spin_r := Basis(Vector3.RIGHT, -_turn_r)
	var turn := Basis(Vector3.UP, -steer * STEER_ANGLE)
	_set_bone(KartModels.WHEEL_FL, Transform3D(turn * spin_f, _rest[KartModels.WHEEL_FL]))
	_set_bone(KartModels.WHEEL_FR, Transform3D(turn * spin_f, _rest[KartModels.WHEEL_FR]))
	_set_bone(KartModels.WHEEL_RL, Transform3D(spin_r, _rest[KartModels.WHEEL_RL]))
	_set_bone(KartModels.WHEEL_RR, Transform3D(spin_r, _rest[KartModels.WHEEL_RR]))
	_upload()


func _set_bone(i: int, xf: Transform3D) -> void:
	_poses[i] = xf


## The bones' skinning matrices (pose x inverse rest, kart space) to both passes. Parents come
## before their children in KartModels.BONES.
func _upload() -> void:
	for i in _poses.size():
		var parent: int = KartModels.PARENTS[i]
		var g: Transform3D = _global[parent] * _poses[i] if parent >= 0 else _poses[i]
		_global[i] = g
		var m := g.translated_local(-(_points[i] as Vector3))
		var o := i * 16
		_skin[o] = m.basis.x.x
		_skin[o + 1] = m.basis.x.y
		_skin[o + 2] = m.basis.x.z
		_skin[o + 3] = 0.0
		_skin[o + 4] = m.basis.y.x
		_skin[o + 5] = m.basis.y.y
		_skin[o + 6] = m.basis.y.z
		_skin[o + 7] = 0.0
		_skin[o + 8] = m.basis.z.x
		_skin[o + 9] = m.basis.z.y
		_skin[o + 10] = m.basis.z.z
		_skin[o + 11] = 0.0
		_skin[o + 12] = m.origin.x
		_skin[o + 13] = m.origin.y
		_skin[o + 14] = m.origin.z
		_skin[o + 15] = 1.0
	_mat.set_shader_parameter("bones", _skin)
	if _line:
		_line.set_shader_parameter("bones", _skin)


func _marker(anchor_name: String, parent: Node3D, at: Vector3) -> void:
	var m := Node3D.new()
	m.name = anchor_name
	m.position = at
	parent.add_child(m)
	_anchors[anchor_name] = m


# --- Models (static, so portraits and tests can build them) ---

## The kart and its driver: one skinned mesh (cached per racer).
static func model_mesh(r: Dictionary) -> ArrayMesh:
	var id := str(r.get("id", ""))
	if not _models.has(id):
		_models[id] = KartModels.model(r)
	return _models[id]


## The head alone (for portraits), centred at the origin, facing -Z.
static func head_mesh(r: Dictionary) -> ArrayMesh:
	return KartModels.head(r)


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
