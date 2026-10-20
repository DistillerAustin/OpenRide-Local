class_name CadenceWorld
extends Node3D
## Cadence Karaoke's 3D view (#42), first person down a neon tunnel. Your orb rolls along the
## floor. A lane is marked on the floor, a box with a bright beat line across its middle, and beat
## rings fly down the tunnel toward the line, one landing on it every beat. When your cadence
## matches the target the orb sits in the middle of the box on the line; the faster you pedal above
## the target the further it moves in front of the box (further up the floor), the slower below it
## the further it falls behind the box (nearer you, lower on the screen). Keep it inside the box.
## All of it is procedural: shaders for the tunnel, rings, orb and portal, a built frame mesh for the
## rings, boxes for the lane, nothing imported. The look is ART_BIBLE.md (this folder).
##
## It only draws: `CadenceLogic` holds the rules. The tablet recipe (docs/GAMES.md, "On the
## tablet") applies: unshaded surfaces, MultiMesh, and nothing laid out per frame beyond a dozen
## ring transforms.

const ORB_Z := -18.0  ## the depth of the beat line
const Z_RANGE := 10.0  ## metres the orb moves at full gap: in front of or behind the band
const RING_SPACING := 7.0  ## metres between beat rings
const CAMERA_Y := 2.2
const CAMERA_PITCH := -12.0
const ORB_RADIUS := 0.6
const LANE_HALF_W := 3.2  ## half the width of the lane the box is marked on
const RING_COUNT := 18
const RING_SIZE := Vector2(15.0, 7.4)
const FLOOR_Y := -3.4
const CEIL_Y := 4.2
const HALF_W := 7.5
const RING_STRIP := 0.7  ## the ring frame's strip width, metres (its core is about a sixth of it)
const PORTAL_Z := -130.0  ## the portal at the tunnel's end, inside the camera's far plane (140)
const SPARK_COUNT := 16
const SPARK_LIFE := 0.55  ## seconds
const BACKGROUND := Color(0.01, 0.01, 0.03)
const HAZE_DENSITY := 0.028

const THEMES := {
	"warmup": Color(0.25, 0.8, 1.0),
	"recovery": Color(0.3, 1.0, 0.65),
	"cooldown": Color(0.72, 0.5, 1.0),
	"free": Color(1.0, 0.45, 0.8),
	"cyan": Color(0.25, 0.8, 1.0),
	"green": Color(0.3, 1.0, 0.65),
	"violet": Color(0.72, 0.5, 1.0),
	"pink": Color(1.0, 0.45, 0.8),
}
## Each theme's secondary (ART_BIBLE.md §2): the cross lines, the walls' equaliser tops, the
## portal and the horizon glow. Never in the HUD.
const SECONDARY := {
	"warmup": Color("ff4fd8"),
	"recovery": Color("3da5ff"),
	"cooldown": Color("ff8fb3"),
	"free": Color("ffa347"),
	"cyan": Color("ff4fd8"),
	"green": Color("3da5ff"),
	"violet": Color("ff8fb3"),
	"pink": Color("ffa347"),
}
## The theme's brightness on the tunnel: cool-down (violet) winds down about 20% dimmer.
const ENERGY := {"cooldown": 0.8, "violet": 0.8}

var camera: Camera3D
var theme_color: Color = THEMES.free
var secondary_color: Color = SECONDARY.free
var theme_energy := 1.0
var beat := 0.0  ## 0-1, decays after each beat; set by the scene
var orb_flash := 0.0  ## 0-1, a red flash when the streak breaks

var _grid_mats: Array[ShaderMaterial] = []
var _floor_mat: ShaderMaterial
var _wall_mats: Array[ShaderMaterial] = []
var _ring_mat: ShaderMaterial
var _ring_mm: MultiMesh
var _portal_mat: ShaderMaterial
var _pool: MeshInstance3D
var _pool_mat: ShaderMaterial
var _spark_mat: ShaderMaterial
var _spark_mm: MultiMesh
var _sparks: MultiMeshInstance3D
var _spark_until := 0.2  ## the clock at which the last burst has died: hidden after it (drawn, all dead, for the first frames so its shader compiles under the intro card, not at the first burst)
var _rng := RandomNumberGenerator.new()
var _clock := 0.0  ## seconds, the sparks' clock
var _beats := 0  ## beats since the start: the equaliser's clock, with beat_phase
var _last_phase := 0.0
var _frozen := 0.0  ## 0-1, eased: the tunnel's desaturation while scoring is frozen
var _line: MeshInstance3D
var _line_mat: StandardMaterial3D
var _gates: Array[MeshInstance3D] = []
var _gate_mat: StandardMaterial3D
var _lane: MeshInstance3D
var _lane_mat: StandardMaterial3D
var _orb: MeshInstance3D
var _orb_mat: ShaderMaterial
var _halo: MeshInstance3D
var _halo_mat: ShaderMaterial
var _scroll := 0.0
var _orb_z := ORB_Z


func _ready() -> void:
	_build_environment()
	_build_tunnel()
	_build_rings()
	_build_line()
	_build_orb()
	_build_sparks()
	camera = Camera3D.new()
	camera.fov = 64.0
	camera.near = 0.1
	camera.far = 140.0
	camera.position = Vector3(0.0, CAMERA_Y, 0.0)
	camera.rotation_degrees = Vector3(CAMERA_PITCH, 0.0, 0.0)
	add_child(camera)
	WorldLook.apply(_tunnel_materials(), {"noise_tex": WorldLook.noise_texture()})
	# The additive layers fade toward black, so a far ring adds nothing rather than the haze.
	WorldLook.apply(_additive_materials(), {"haze_color": Color.BLACK, "haze_density": HAZE_DENSITY + 0.004, "haze_max": 1.0})
	set_theme_color(theme_color, secondary_color, theme_energy)


## Draws one frame. `gap` is -1 to 1: 0 puts the orb on the line, 1 in front of the box and -1
## behind it. `band` is the box's half-depth on that scale, `beat_phase` 0-1 through the current
## beat (a ring lands on the line as it wraps), `state` "in_bonus", "in_band", "near" or "out"
## (the orb's colour), `frozen` whether scoring is frozen, `streak` 0-1 (how far through the
## multiplier) and `beat_rate` beats per second.
func update_view(delta: float, gap: float, band: float, beat_phase: float, state: String, frozen: bool, streak: float, beat_rate: float) -> void:
	_scroll += delta * beat_rate * RING_SPACING
	_clock += delta
	if beat_phase < _last_phase - 0.5:
		_beats += 1
		if state == "in_bonus" and not frozen:
			_fire_sparks()
	_last_phase = beat_phase
	_frozen = move_toward(_frozen, 1.0 if frozen else 0.0, delta * 2.5)
	for mat in _grid_mats:
		mat.set_shader_parameter("scroll", _scroll)
		mat.set_shader_parameter("beat", beat)
		mat.set_shader_parameter("frozen", _frozen)
	_floor_mat.set_shader_parameter("ring_phase", beat_phase)
	for mat in _wall_mats:
		mat.set_shader_parameter("beat_clock", float(_beats) + beat_phase)
	_ring_mat.set_shader_parameter("pulse", beat)
	_ring_mat.set_shader_parameter("frozen", _frozen)
	_portal_mat.set_shader_parameter("beat", beat)
	_portal_mat.set_shader_parameter("frozen", _frozen)
	_spark_mat.set_shader_parameter("now", _clock)
	_sparks.visible = _clock < _spark_until  # a draw only while a burst is alive
	_line_mat.emission_energy_multiplier = 1.6 + beat * 1.6
	_lane_mat.albedo_color = Color(theme_color, 0.16 + beat * 0.1)
	_update_rings(beat_phase)
	var reach := maxf(band * Z_RANGE, 0.4)  # the box's half-depth
	_gates[0].position.z = ORB_Z - reach
	_gates[1].position.z = ORB_Z + reach
	_lane.scale = Vector3(1.0, 1.0, reach * 2.0)
	_orb_z = lerpf(_orb_z, ORB_Z - gap * Z_RANGE, minf(delta * 8.0, 1.0))
	orb_flash = maxf(orb_flash - delta * 2.5, 0.0)
	var color := _orb_color(state, frozen)
	color = color.lerp(Color(1.0, 0.15, 0.1), orb_flash)
	var glow := 1.0 + beat * 0.8 + streak * 0.6
	_orb_mat.set_shader_parameter("state_color", color)
	_orb_mat.set_shader_parameter("glow", glow)
	_halo_mat.set_shader_parameter("state_color", color)
	_halo_mat.set_shader_parameter("strength", 0.9 + beat * 0.4 + streak * 0.4)
	_pool_mat.set_shader_parameter("state_color", color)
	_pool_mat.set_shader_parameter("strength", 0.7 + beat * 0.3)
	_pool_mat.set_shader_parameter("trail", streak)
	_spark_mat.set_shader_parameter("spark_color", color)
	_orb.position = Vector3(0.0, FLOOR_Y + ORB_RADIUS, _orb_z)
	# Plain perspective: small and far when ahead, big and close when behind.
	var size := 1.0 + beat * 0.12 + streak * 0.2
	_orb.scale = Vector3.ONE * size
	_halo.position = _orb.position
	var halo_size := size + beat * 0.3 + streak * 0.5
	_halo.scale = Vector3.ONE * halo_size
	# The halo starts just outside the orb's edge: the orb's radius over the quad's half-size.
	_halo_mat.set_shader_parameter("inner", (ORB_RADIUS * size * 1.04) / (1.8 * halo_size))
	_pool.position.z = _orb_z


## The theme by its name (a workout role or a colour option): neon, secondary and brightness.
func set_theme(theme_name: String) -> void:
	var key := theme_name if THEMES.has(theme_name) else "free"
	set_theme_color(THEMES[key], SECONDARY[key], ENERGY.get(key, 1.0))


## `secondary` defaults to the secondary of the theme whose neon is `color`.
func set_theme_color(color: Color, secondary := Color(0, 0, 0, 0), energy := 1.0) -> void:
	theme_color = color
	if secondary.a == 0.0:
		secondary = SECONDARY.free
		for key in THEMES:
			if THEMES[key] == color:
				secondary = SECONDARY[key]
				energy = ENERGY.get(key, energy)
				break
	secondary_color = secondary
	theme_energy = energy
	# The far end glows faintly in the secondary: the haze the tunnel fades into.
	var haze := BACKGROUND + secondary * 0.05
	WorldLook.apply(_tunnel_materials(), {"haze_color": haze, "haze_density": HAZE_DENSITY, "haze_max": 1.0})
	for mat in _grid_mats:
		mat.set_shader_parameter("line_color", color)
		mat.set_shader_parameter("line2_color", secondary)
		mat.set_shader_parameter("energy", energy)
	_ring_mat.set_shader_parameter("ring_color", color)
	_ring_mat.set_shader_parameter("energy", energy)
	_portal_mat.set_shader_parameter("disc_color", secondary)
	_portal_mat.set_shader_parameter("neon_color", color)
	_portal_mat.set_shader_parameter("energy", energy)
	_gate_mat.albedo_color = color
	_gate_mat.emission = color
	_lane_mat.emission = color


## The opaque tunnel materials (full grade, haze toward the background).
func _tunnel_materials() -> Array:
	var mats: Array = _grid_mats.duplicate()
	mats.append(_portal_mat)
	return mats


## The additive layers (the grade's linear parts only, haze toward black).
func _additive_materials() -> Array:
	return [_ring_mat, _halo_mat, _pool_mat, _spark_mat]


func _orb_color(state: String, frozen: bool) -> Color:
	if frozen:
		return Color(1.0, 0.7, 0.2)
	match state:
		"in_bonus":
			return Color(0.45, 1.0, 0.65)
		"in_band":
			return Color(0.6, 1.0, 0.5)
		"near":
			return Color(1.0, 0.85, 0.3)
	return Color(1.0, 0.4, 0.35)


# --- Building ---

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.6)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	add_child(env_node)


func _build_tunnel() -> void:
	var length := 150.0
	# [centre, rotation in degrees, size, the axis the long lines are spaced along, shader]
	var faces := [
		[Vector3(0.0, FLOOR_Y, -length / 2.0), Vector3(0, 0, 0), Vector2(HALF_W * 2.0, length), Vector3(1, 0, 0), "floor"],
		[Vector3(0.0, CEIL_Y, -length / 2.0), Vector3(0, 0, 0), Vector2(HALF_W * 2.0, length), Vector3(1, 0, 0), "ceiling"],
		[Vector3(-HALF_W, (FLOOR_Y + CEIL_Y) / 2.0, -length / 2.0), Vector3(0, 0, 90), Vector2(CEIL_Y - FLOOR_Y, length), Vector3(0, 1, 0), "wall"],
		[Vector3(HALF_W, (FLOOR_Y + CEIL_Y) / 2.0, -length / 2.0), Vector3(0, 0, 90), Vector2(CEIL_Y - FLOOR_Y, length), Vector3(0, 1, 0), "wall"],
	]
	for face in faces:
		var mesh := PlaneMesh.new()
		mesh.size = face[2]
		var mat := ShaderMaterial.new()
		mat.shader = load("res://games/cadence_karaoke/shaders/grid_%s.gdshader" % face[4])
		mat.set_shader_parameter("across_axis", face[3])
		match face[4]:
			"floor":
				_floor_mat = mat
				mat.set_shader_parameter("ring_spacing", RING_SPACING)
				mat.set_shader_parameter("line_z", ORB_Z)
			"wall":
				_wall_mats.append(mat)
				mat.set_shader_parameter("floor_y", FLOOR_Y)
				mat.set_shader_parameter("wall_height", CEIL_Y - FLOOR_Y)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = face[0]
		mi.rotation_degrees = face[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_grid_mats.append(mat)
	# The portal closes the far end: a disc card in the secondary.
	var card := QuadMesh.new()
	card.size = Vector2(HALF_W * 2.0, CEIL_Y - FLOOR_Y)
	_portal_mat = ShaderMaterial.new()
	_portal_mat.shader = load("res://games/cadence_karaoke/shaders/portal.gdshader")
	_portal_mat.set_shader_parameter("size", card.size)
	var portal := MeshInstance3D.new()
	portal.name = "Portal"
	portal.mesh = card
	portal.material_override = _portal_mat
	portal.position = Vector3(0.0, (FLOOR_Y + CEIL_Y) / 2.0, PORTAL_Z)
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(portal)


func _build_rings() -> void:
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = load("res://games/cadence_karaoke/shaders/ring.gdshader")
	_ring_mat.set_shader_parameter("line_z", ORB_Z)
	_ring_mm = MultiMesh.new()
	_ring_mm.transform_format = MultiMesh.TRANSFORM_3D
	_ring_mm.mesh = frame_mesh(RING_SIZE, RING_STRIP)
	_ring_mm.instance_count = RING_COUNT
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rings"
	mmi.multimesh = _ring_mm
	mmi.material_override = _ring_mat
	mmi.extra_cull_margin = 200.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_update_rings(0.0)


## A rectangular frame `size` across (outer edge) made of four mitred strips `strip` wide, each
## split at its middle: 24 vertices, 16 triangles, facing +z. UV.y runs 0 (outer edge) to 1 (inner
## edge) across the strip; UV.x is the distance in metres from the nearest corner along the strip,
## for the corner glints. Replaces a full quad that discarded all but its border.
static func frame_mesh(size: Vector2, strip: float) -> ArrayMesh:
	var h := size / 2.0
	var outer := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	var inner := [Vector2(-h.x + strip, -h.y + strip), Vector2(h.x - strip, -h.y + strip),
		Vector2(h.x - strip, h.y - strip), Vector2(-h.x + strip, h.y - strip)]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for side in 4:
		var a: int = side
		var b: int = (side + 1) % 4
		var half_len: float = (outer[b] - outer[a]).length() / 2.0 - strip / 2.0
		var base := verts.size()
		# outer a, outer mid, outer b, inner a, inner mid, inner b
		var pts: Array[Vector2] = [outer[a], (outer[a] + outer[b]) / 2.0, outer[b],
			inner[a], (inner[a] + inner[b]) / 2.0, inner[b]]
		var us := [0.0, half_len, 0.0, 0.0, half_len, 0.0]
		for i in 6:
			verts.append(Vector3(pts[i].x, pts[i].y, 0.0))
			uvs.append(Vector2(us[i], 0.0 if i < 3 else 1.0))
			normals.append(Vector3(0.0, 0.0, 1.0))
		for quad in [[0, 1, 4, 3], [1, 2, 5, 4]]:
			indices.append_array([base + quad[0], base + quad[1], base + quad[2],
				base + quad[0], base + quad[2], base + quad[3]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Beat rings: one a beat apart, flowing toward the rider. Ring k lands on the line when
## `beat_phase` reaches 1 (k = 1), so the line flares as a ring arrives.
func _update_rings(beat_phase: float) -> void:
	for i in RING_COUNT:
		_ring_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0.0, (FLOOR_Y + CEIL_Y) / 2.0, ring_z(i, beat_phase))))


## Ring `i`'s depth at `beat_phase`. The floor shader (grid.gdshaderinc, GRID_FLOOR) models the
## same placement for the rings' reflections: keep them together.
static func ring_z(i: int, beat_phase: float) -> float:
	return ORB_Z - (float(i - 1) - beat_phase) * RING_SPACING


## The box on the floor: a translucent lane as deep as the band, a dim gate at each end, and the
## beat line, a bright bar across the middle (white, so it is never mistaken for a ring).
func _build_line() -> void:
	_line_mat = _flat_material(Color(1, 1, 1), false)
	_gate_mat = _flat_material(Color(1, 1, 1), false)
	_lane_mat = _flat_material(Color(1, 1, 1, 0.2), true)
	_line = _floor_bar("BeatLine", Vector3(LANE_HALF_W * 2.0 + 1.6, 0.12, 0.45), _line_mat, 0.07)
	_line.position.z = ORB_Z
	for gate_name in ["BoxFar", "BoxNear"]:
		var gate := _floor_bar(gate_name, Vector3(LANE_HALF_W * 2.0 + 0.6, 0.1, 0.22), _gate_mat, 0.06)
		_gates.append(gate)
	_lane = _floor_bar("Lane", Vector3(LANE_HALF_W * 2.0, 0.03, 1.0), _lane_mat, 0.02)
	_lane.position.z = ORB_Z


func _floor_bar(bar_name: String, size: Vector3, mat: StandardMaterial3D, lift: float) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.name = bar_name
	mi.mesh = box
	mi.material_override = mat
	mi.position = Vector3(0.0, FLOOR_Y + lift, ORB_Z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _flat_material(color: Color, see_through: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	if see_through:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.disable_receive_shadows = true
	return mat


func _build_orb() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = ORB_RADIUS
	sphere.height = ORB_RADIUS * 2.0
	sphere.radial_segments = 24  # the fresnel rim and outline show facets below this
	sphere.rings = 12
	_orb_mat = ShaderMaterial.new()
	_orb_mat.shader = load("res://games/cadence_karaoke/shaders/orb.gdshader")
	_orb = MeshInstance3D.new()
	_orb.name = "Orb"
	_orb.mesh = sphere
	_orb.material_override = _orb_mat
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)
	# A soft halo: a billboard whose falloff is in its shader, added to the picture.
	var quad := QuadMesh.new()
	quad.size = Vector2(3.6, 3.6)
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = load("res://games/cadence_karaoke/shaders/orb_halo.gdshader")
	_halo = MeshInstance3D.new()
	_halo.name = "Halo"
	_halo.mesh = quad
	_halo.material_override = _halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	# Its light on the floor: a pool under it and a trail toward the rider (origin under the orb).
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.0, 9.0)
	plane.center_offset = Vector3(0.0, 0.0, 3.0)
	_pool_mat = ShaderMaterial.new()
	_pool_mat.shader = load("res://games/cadence_karaoke/shaders/orb_pool.gdshader")
	_pool = MeshInstance3D.new()
	_pool.name = "Pool"
	_pool.mesh = plane
	_pool.material_override = _pool_mat
	_pool.position = Vector3(0.0, FLOOR_Y + 0.04, ORB_Z)
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pool)


## Sparks off the beat line in the bonus band: one pooled MultiMesh whose motion is in its shader.
func _build_sparks() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_spark_mat = ShaderMaterial.new()
	_spark_mat.shader = load("res://games/cadence_karaoke/shaders/spark.gdshader")
	_spark_mat.set_shader_parameter("origin", Vector3(0.0, FLOOR_Y + 0.13, ORB_Z))
	_spark_mat.set_shader_parameter("half_width", LANE_HALF_W + 0.4)
	_spark_mat.set_shader_parameter("life", SPARK_LIFE)
	_spark_mm = MultiMesh.new()
	_spark_mm.transform_format = MultiMesh.TRANSFORM_3D
	_spark_mm.use_custom_data = true
	_spark_mm.mesh = quad
	_spark_mm.instance_count = SPARK_COUNT
	for i in SPARK_COUNT:
		_spark_mm.set_instance_transform(i, Transform3D.IDENTITY)
		_spark_mm.set_instance_custom_data(i, Color(-100.0, 0.0, 0.0, 0.0))  # long dead
	_sparks = MultiMeshInstance3D.new()
	_sparks.name = "Sparks"
	_sparks.multimesh = _spark_mm
	_sparks.material_override = _spark_mat
	_sparks.extra_cull_margin = 50.0
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.position = Vector3(0.0, FLOOR_Y, ORB_Z)  # for culling; the shader places the sparks in world space
	_sparks.visible = true
	add_child(_sparks)


## A burst as a ring lands: births and seeds for every spark, written once.
func _fire_sparks() -> void:
	_spark_until = _clock + SPARK_LIFE + 0.1
	for i in SPARK_COUNT:
		_spark_mm.set_instance_custom_data(i, Color(_clock - _rng.randf() * 0.05, _rng.randf(), _rng.randf(), _rng.randf()))
