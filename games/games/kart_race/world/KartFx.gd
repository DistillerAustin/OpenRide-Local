class_name KartFx
extends Node3D
## Kart Race's effects (#43): exhaust puffs, dust off the kerbs and grass, drift sparks in three
## tiers, boost flames, and (for the hero slice) a scripted drift every few seconds, since
## drifting arrives with the handling agent's Phase 2 physics. Two pooled MultiMeshes drawn as
## camera-facing sprites (one alpha-blended for smoke and dust, one additive for sparks and
## flames), simulated here and written to the MultiMesh buffers each frame: 2 draw calls for
## every effect on every kart, nothing allocated per frame.
##
## Reads `KartState`s and pokes the views' `slide` / `boost_glow` and the camera's `kick`.

const PUFFS := 150
const SPARKS := 110
const DRIFT_EVERY := 5.5  ## seconds between the rider's scripted drifts
const DRIFT_SEC := 1.9
const BOOST_SEC := 0.9
const TIER_SEC := [0.0, 0.55, 1.15]
const TIER_COLORS := [Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.15), Color(0.9, 0.55, 1.0)]

var views: Array = []
var camera: KartChaseCamera
## The rider's scripted drift, 0-1 charge (for the HUD's meter), and its tier (0 = none).
var drift_charge := 0.0
var drift_tier := 0
var demo_drifts := true

var _puff_mm: MultiMesh
var _spark_mm: MultiMesh
var _puff_buf := PackedFloat32Array()
var _spark_buf := PackedFloat32Array()
# Per particle: position, velocity, age, life, size start/end, colour.
var _pp := PackedVector3Array()
var _pv := PackedVector3Array()
var _pa := PackedFloat32Array()
var _pl := PackedFloat32Array()
var _ps := PackedVector2Array()
var _pc := PackedColorArray()
var _pn := 0
var _sp := PackedVector3Array()
var _sv := PackedVector3Array()
var _sa := PackedFloat32Array()
var _sl := PackedFloat32Array()
var _ss := PackedVector2Array()
var _sc := PackedColorArray()
var _sn := 0
var _rng := RandomNumberGenerator.new()
var _emit := PackedFloat32Array()  # per kart: exhaust timer
var _drift_t := PackedFloat32Array()  # per kart: time in the current drift (-1 none)
var _drift_next := PackedFloat32Array()  # per kart: seconds to the next drift
var _drift_dir := PackedFloat32Array()
var _boost_t := PackedFloat32Array()


func _ready() -> void:
	_rng.seed = 77
	_puff_mm = _pool("Puffs", PUFFS, false)
	_spark_mm = _pool("Sparks", SPARKS, true)
	_pp.resize(PUFFS); _pv.resize(PUFFS); _pa.resize(PUFFS); _pl.resize(PUFFS); _ps.resize(PUFFS); _pc.resize(PUFFS)
	_sp.resize(SPARKS); _sv.resize(SPARKS); _sa.resize(SPARKS); _sl.resize(SPARKS); _ss.resize(SPARKS); _sc.resize(SPARKS)
	_puff_buf.resize(PUFFS * 16)
	_spark_buf.resize(SPARKS * 16)


## A new race: the views per kart id.
func begin(kart_views: Array) -> void:
	views = kart_views
	var n := views.size()
	_emit.resize(n)
	_drift_t.resize(n)
	_drift_next.resize(n)
	_drift_dir.resize(n)
	_boost_t.resize(n)
	for i in n:
		_emit[i] = _rng.randf() * 0.1
		_drift_t[i] = -1.0
		_drift_next[i] = (2.5 if i == 0 else _rng.randf_range(3.0, 9.0))
		_boost_t[i] = 0.0
	_pn = 0
	_sn = 0


## A boost on kart `id` (an item, the start): flames and, for the rider, a camera kick.
func boost(id: int, seconds := BOOST_SEC) -> void:
	if id < _boost_t.size():
		_boost_t[id] = seconds
		if id == 0 and camera:
			camera.kick(1.0)


func step(race: KartRaceLogic, dt: float) -> void:
	if race == null or views.is_empty():
		return
	var racing := race.phase == KartRaceLogic.Phase.RACING or race.phase == KartRaceLogic.Phase.FINISHED
	for i in mini(views.size(), race.karts.size()):
		var k: KartState = race.karts[i]
		var v: KartView = views[i]
		_kart(i, k, v, race, dt, racing)
	_simulate(dt)


func _kart(i: int, k: KartState, v: KartView, race: KartRaceLogic, dt: float, racing: bool) -> void:
	var xf := v.global_transform
	var back := xf.basis.z
	# Exhaust: puffs from both pipes, faster with speed; a little idle smoke on the grid.
	_emit[i] -= dt
	if _emit[i] <= 0.0:
		_emit[i] = 0.09 if k.speed > 2.0 else 0.22
		for a in ["exhaust_l", "exhaust_r"]:
			var p := v.anchor(a).global_position
			_puff(p, back * 1.2 + Vector3.UP * 0.6 + _jitter(0.3), 0.55, Vector2(0.16, 0.55), Color(0.55, 0.55, 0.6, 0.38))
	# Dust off the road edges and the grass.
	if racing and k.surface != KartTrackModel.Surface.ROAD and k.speed > 4.0 and _rng.randf() < dt * 30.0:
		var w := v.anchor("wheel_rl" if _rng.randf() < 0.5 else "wheel_rr").global_position
		_puff(w, back * 2.0 + Vector3.UP * 1.0 + _jitter(0.8), 0.9, Vector2(0.3, 1.3), Color(0.72, 0.62, 0.45, 0.5))
	# The scripted drift: slide, sparks by tier, then a boost.
	if demo_drifts and racing and k.speed > 9.0:
		if _drift_t[i] < 0.0:
			_drift_next[i] -= dt
			if _drift_next[i] <= 0.0:
				var curv := race.track.curvature(k.s)
				_drift_dir[i] = signf(curv) if absf(curv) > 0.002 else (1.0 if _rng.randf() < 0.5 else -1.0)
				_drift_t[i] = 0.0
		else:
			_drift_t[i] += dt
			var t := _drift_t[i]
			var tier := 3 if t >= TIER_SEC[2] else (2 if t >= TIER_SEC[1] else 1)
			if t >= DRIFT_SEC:
				_drift_t[i] = -1.0
				_drift_next[i] = DRIFT_EVERY if i == 0 else _rng.randf_range(6.0, 11.0)
				boost(i)
			else:
				var c: Color = TIER_COLORS[tier - 1]
				var outer := "wheel_rr" if _drift_dir[i] > 0.0 else "wheel_rl"
				var inner := "wheel_rl" if _drift_dir[i] > 0.0 else "wheel_rr"
				var rate := 50.0 + 30.0 * tier
				# A flickering glow at both rear wheels in the tier's colour.
				for a in [outer, inner]:
					var w := v.anchor(a).global_position - Vector3.UP * 0.18
					_spark(w, Vector3.ZERO, 0.05, Vector2(0.75 + 0.25 * _rng.randf(), 0.6), Color(c.r, c.g, c.b, 0.9))
				for a in [outer, inner]:
					if _rng.randf() < dt * rate:
						var p := v.anchor(a).global_position - Vector3.UP * 0.22
						_spark(p, back * 3.0 + Vector3.UP * _rng.randf_range(1.0, 3.0) + _jitter(2.0), 0.3, Vector2(0.16, 0.04), c)
						_spark(p, back * 2.0 + Vector3.UP * _rng.randf_range(0.5, 2.0) + _jitter(1.5), 0.18, Vector2(0.09, 0.03), Color(1, 1, 0.9))
				if _rng.randf() < dt * 14.0:
					_puff(v.anchor(outer).global_position, back * 1.5 + Vector3.UP * 0.8 + _jitter(0.5), 0.7, Vector2(0.3, 1.0), Color(0.85, 0.85, 0.88, 0.35))
			if i == 0:
				drift_charge = clampf(t / DRIFT_SEC, 0.0, 1.0) if _drift_t[i] >= 0.0 else 0.0
				drift_tier = tier if _drift_t[i] >= 0.0 else 0
	var slide_goal := 0.0
	if _drift_t[i] >= 0.0:
		slide_goal = _drift_dir[i] * 0.32 * smoothstep(0.0, 0.25, _drift_t[i])
	v.slide = lerpf(v.slide, slide_goal, 1.0 - exp(-10.0 * dt))
	# Boost flames.
	if _boost_t[i] > 0.0:
		_boost_t[i] -= dt
		for a in ["exhaust_l", "exhaust_r"]:
			var p := v.anchor(a).global_position
			_spark(p, back * 4.0 + _jitter(0.6), 0.18, Vector2(0.5, 0.15), Color(1.0, 0.55, 0.15))
			_spark(p, back * 3.0 + _jitter(0.4), 0.12, Vector2(0.3, 0.08), Color(1.0, 0.9, 0.5))
	v.boost_glow = clampf(_boost_t[i] / BOOST_SEC, 0.0, 1.0)


func _jitter(r: float) -> Vector3:
	return Vector3(_rng.randf_range(-r, r), _rng.randf_range(-r, r) * 0.5, _rng.randf_range(-r, r))


func _puff(p: Vector3, vel: Vector3, life: float, size: Vector2, c: Color) -> void:
	if _pn >= PUFFS:
		return
	_pp[_pn] = p; _pv[_pn] = vel; _pa[_pn] = 0.0; _pl[_pn] = life; _ps[_pn] = size; _pc[_pn] = c
	_pn += 1


func _spark(p: Vector3, vel: Vector3, life: float, size: Vector2, c: Color) -> void:
	if _sn >= SPARKS:
		return
	_sp[_sn] = p; _sv[_sn] = vel; _sa[_sn] = 0.0; _sl[_sn] = life; _ss[_sn] = size; _sc[_sn] = c
	_sn += 1


func _simulate(dt: float) -> void:
	var i := 0
	while i < _pn:
		_pa[i] += dt
		if _pa[i] >= _pl[i]:
			_pn -= 1
			_pp[i] = _pp[_pn]; _pv[i] = _pv[_pn]; _pa[i] = _pa[_pn]; _pl[i] = _pl[_pn]; _ps[i] = _ps[_pn]; _pc[i] = _pc[_pn]
			continue
		_pv[i] *= 1.0 - 2.5 * dt
		_pv[i].y += 0.6 * dt
		_pp[i] += _pv[i] * dt
		var t := _pa[i] / _pl[i]
		var s := lerpf(_ps[i].x, _ps[i].y, sqrt(t))
		var c := _pc[i]
		_write(_puff_buf, i, _pp[i], s, Color(c.r, c.g, c.b, c.a * (1.0 - t) * minf(1.0, t * 8.0)))
		i += 1
	i = 0
	while i < _sn:
		_sa[i] += dt
		if _sa[i] >= _sl[i]:
			_sn -= 1
			_sp[i] = _sp[_sn]; _sv[i] = _sv[_sn]; _sa[i] = _sa[_sn]; _sl[i] = _sl[_sn]; _ss[i] = _ss[_sn]; _sc[i] = _sc[_sn]
			continue
		_sv[i].y -= 9.0 * dt
		_sp[i] += _sv[i] * dt
		var t := _sa[i] / _sl[i]
		var c := _sc[i]
		_write(_spark_buf, i, _sp[i], lerpf(_ss[i].x, _ss[i].y, t), Color(c.r, c.g, c.b, 1.0 - t * t))
		i += 1
	_puff_mm.visible_instance_count = _pn
	_spark_mm.visible_instance_count = _sn
	if _pn > 0:
		_puff_mm.buffer = _puff_buf
	if _sn > 0:
		_spark_mm.buffer = _spark_buf


## One instance in a TRANSFORM_3D + colour buffer: a uniform scale at p, then RGBA.
static func _write(buf: PackedFloat32Array, i: int, p: Vector3, s: float, c: Color) -> void:
	var o := i * 16
	buf[o] = s; buf[o + 1] = 0.0; buf[o + 2] = 0.0; buf[o + 3] = p.x
	buf[o + 4] = 0.0; buf[o + 5] = s; buf[o + 6] = 0.0; buf[o + 7] = p.y
	buf[o + 8] = 0.0; buf[o + 9] = 0.0; buf[o + 10] = s; buf[o + 11] = p.z
	buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a


func _pool(node_name: String, count: int, additive: bool) -> MultiMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = KartMeshKit.soft_disc(32, 0.3 if additive else 0.0)
	mat.disable_fog = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Particles go anywhere on the track: never cull the pool by its (empty) bounds.
	node.custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 400, 4000))
	add_child(node)
	return mm
