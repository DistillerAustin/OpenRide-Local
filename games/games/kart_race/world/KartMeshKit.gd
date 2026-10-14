class_name KartMeshKit
extends RefCounted
## Procedural mesh helpers for Kart Race's look (#43, the hero slice). Every model in the game is
## built here from primitive shapes merged into one vertex-coloured ArrayMesh per object, so a
## kart is a couple of draw calls and a whole forest is one MultiMesh. Colours carry the look:
## painted ambient occlusion (darker low down and underneath) is baked into them, and the alpha
## channel is a per-vertex mask the shaders read (gloss on karts, sway weight on foliage).
##
## The shaders light everything by hand (see shaders/): the tablet's GPU is fill-rate bound and
## the engine's per-pixel lights cost about a third of its frame (docs/GAMES.md, Dodge Ball).

## Painted AO for the next `add` calls: colours darken towards `ao_min` below `ao_y0` (metres,
## in the merged mesh's space), reaching full brightness at `ao_y1`. ao_min = 1 turns it off.
var ao_y0 := 0.0
var ao_y1 := 1.0
var ao_min := 1.0

var _st := SurfaceTool.new()
var _empty := true


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Appends `mesh` (a PrimitiveMesh or any one-surface ArrayMesh), transformed by `xf`, in `color`
## (alpha = the shader mask).
func add(mesh: Mesh, xf: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var nb := xf.basis.inverse().transposed()
	var count := indices.size() if not indices.is_empty() else verts.size()
	# PrimitiveMesh winding is clockwise front faces; keep it (Godot's convention).
	for i in count:
		var vi := indices[i] if not indices.is_empty() else i
		var p := xf * verts[vi]
		var n := (nb * normals[vi]).normalized() if normals.size() > vi else Vector3.UP
		var c := color
		if ao_min < 1.0:
			var k := clampf((p.y - ao_y0) / maxf(ao_y1 - ao_y0, 0.001), 0.0, 1.0)
			var f := lerpf(ao_min, 1.0, k * k * (3.0 - 2.0 * k))
			# Faces pointing down get a little darker still.
			f *= lerpf(0.82, 1.0, clampf(n.y + 1.0, 0.0, 1.0))
			c = Color(color.r * f, color.g * f, color.b * f, color.a)
		_st.set_color(c)
		_st.set_normal(n)
		_st.add_vertex(p)
	_empty = false


## Appends a vertex-coloured mesh built by a kit (its colours times `tint`), transformed by `xf`.
## Used to bake many instances into one static mesh per sector of the world.
func add_baked(mesh: ArrayMesh, xf: Transform3D, tint := Color.WHITE) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var b := xf.basis
	for i in verts.size():
		_st.set_color(colors[i] * tint)
		_st.set_normal((b * normals[i]).normalized())
		_st.add_vertex(xf * verts[i])
	_empty = false


## A quad a-b-c-d (clockwise seen from the front) with a flat normal.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var n := (c - a).cross(b - a).normalized()
	for p in [a, b, c, a, c, d]:
		_st.set_color(color)
		_st.set_normal(n)
		_st.add_vertex(p)
	_empty = false


func is_empty() -> bool:
	return _empty


func commit() -> ArrayMesh:
	return _st.commit()


# --- Primitive shortcuts (low segment counts: the tablet) ---

static func sphere(radius: float, segments := 10, rings := 5, hemisphere := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * (1.0 if hemisphere else 2.0)
	m.radial_segments = segments
	m.rings = rings
	m.is_hemisphere = hemisphere
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(top: float, bottom: float, height: float, segments := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func capsule(radius: float, height: float, segments := 10, rings := 2) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = segments
	m.rings = rings
	return m


static func torus(inner: float, outer: float, rings := 14, ring_segments := 6) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = ring_segments
	return m


static func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m


## Transform helper: translate, then rotate (degrees, YXZ), then scale.
static func xf(pos: Vector3, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	return Transform3D(b.scaled_local(scale), pos)


## 64x64 random values; with linear filtering and repeat, sampling it is value noise for the
## shaders (cheaper on the tablet's PowerVR than hashing per pixel). Dodge Ball's pattern.
static func noise_texture(seed_value := 1337) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var data := PackedByteArray()
	data.resize(64 * 64)
	for i in data.size():
		data[i] = rng.randi_range(0, 255)
	var img := Image.create_from_data(64, 64, false, Image.FORMAT_L8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A soft round sprite (white, alpha falls off), for puffs, halos and shadows.
static func soft_disc(size := 64, hardness := 0.0) -> ImageTexture:
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var r := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = lerpf(a * a * (3.0 - 2.0 * a), 1.0 if r < 0.85 else 0.0, hardness)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func multimesh_node(mesh: Mesh, transforms: Array, node_name: String, custom: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = not custom.is_empty()
	# In the Compatibility renderer, custom data without instance colours multiplies COLOR by zero:
	# carry white instance colours along with it.
	mm.use_colors = not custom.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if not custom.is_empty():
			mm.set_instance_custom_data(i, custom[i])
			mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


static func mesh_node(mesh: Mesh, mat: Material, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
