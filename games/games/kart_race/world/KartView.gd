class_name KartView
extends Node3D
## One kart on screen (#43): a placeholder box kart with axles, a head for the driver and a blob
## shadow. It only reads a `KartState` (`sync`, every frame). The racers agent replaces the
## model and the rig (wheels that steer, body lean and squash, the driver's lean) and owns this
## file; the API below is frozen (DESIGN.md "Kart view").
##
## Anchors (`anchor(name)`, Node3D markers that follow the rig): exhaust_l, exhaust_r, wheel_fl,
## wheel_fr, wheel_rl, wheel_rr, driver_head, item_hold, shadow. Effects and item views attach
## to them.
##
## Draw calls: body, head, two axles, shadow (5).

const ANCHORS := ["exhaust_l", "exhaust_r", "wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr",
	"driver_head", "item_hold", "shadow"]
const WHEEL_RADIUS := 0.3
const BODY_LEAN := 0.08  ## radians of body roll at full steer
const SPIN_TURNS := 2.0  ## turns of the body over a spin-out

var racer := {}

var _body: Node3D  ## leans and spins; the anchors that move with the kart live under it
var _front_axle: Node3D  ## spins about x; the wheel anchors ride on it
var _rear_axle: Node3D
var _shadow: MeshInstance3D
var _anchors := {}
var _wheel_turn := 0.0

static var _shadow_material: StandardMaterial3D


func setup(racer_info: Dictionary) -> void:
	racer = racer_info
	name = "Kart_%s" % str(racer.get("id", "racer"))
	var color: Color = racer.get("color", Color(0.9, 0.3, 0.2))
	var accent: Color = racer.get("accent", Color.WHITE)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 0.45, 2.0)
	hull.mesh = box
	hull.material_override = _lit(color)
	hull.position = Vector3(0.0, 0.45, 0.0)
	_body.add_child(hull)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	sphere.radial_segments = 10
	sphere.rings = 5
	head.mesh = sphere
	head.material_override = _lit(accent)
	head.position = Vector3(0.0, 1.0, 0.2)
	_body.add_child(head)
	_front_axle = _axle(-0.7)
	_rear_axle = _axle(0.7)
	_shadow = MeshInstance3D.new()
	_shadow.name = "shadow"
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.9, 2.6)
	_shadow.mesh = quad
	_shadow.material_override = _blob()
	_shadow.position = Vector3(0.0, 0.03, 0.0)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_anchors["shadow"] = _shadow
	_marker("exhaust_l", _body, Vector3(-0.35, 0.4, 1.05))
	_marker("exhaust_r", _body, Vector3(0.35, 0.4, 1.05))
	_marker("wheel_fl", _front_axle, Vector3(-0.7, 0.0, 0.0))
	_marker("wheel_fr", _front_axle, Vector3(0.7, 0.0, 0.0))
	_marker("wheel_rl", _rear_axle, Vector3(-0.7, 0.0, 0.0))
	_marker("wheel_rr", _rear_axle, Vector3(0.7, 0.0, 0.0))
	_marker("driver_head", _body, head.position)
	_marker("item_hold", _body, Vector3(0.0, 1.3, 1.0))


## Places and poses the kart from its state (every frame).
func sync(k: KartState, dt: float) -> void:
	var up := k.normal if k.normal.length_squared() > 0.5 else Vector3.UP
	var fwd := k.forward()
	fwd = (fwd - up * fwd.dot(up)).normalized()
	transform = Transform3D(Basis.looking_at(fwd, up), k.pos)
	var spin := 0.0
	if k.spin_time > 0.0:
		spin = TAU * SPIN_TURNS * (k.spin_time / KartPhysics.SPIN_SEC)
	_body.transform = Transform3D(Basis(Vector3.UP, spin) * Basis(Vector3.BACK, -k.steer * BODY_LEAN),
		Vector3(0.0, k.hop, 0.0))
	_wheel_turn = fmod(_wheel_turn + k.speed / WHEEL_RADIUS * dt, TAU)
	_front_axle.rotation.x = -_wheel_turn
	_rear_axle.rotation.x = -_wheel_turn


## One of the ANCHORS, or null.
func anchor(anchor_name: String) -> Node3D:
	return _anchors.get(anchor_name)


func _axle(z: float) -> Node3D:
	var axle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = WHEEL_RADIUS
	cyl.bottom_radius = WHEEL_RADIUS
	cyl.height = 1.6
	cyl.radial_segments = 10
	cyl.rings = 1
	axle.mesh = cyl
	axle.material_override = _lit(Color(0.12, 0.12, 0.13))
	# A cylinder stands on y: lie it across the kart (x), then it spins about x.
	var holder := Node3D.new()
	holder.position = Vector3(0.0, WHEEL_RADIUS, z)
	add_child(holder)
	axle.rotation = Vector3(0.0, 0.0, PI * 0.5)
	holder.add_child(axle)
	return holder


func _marker(anchor_name: String, parent: Node3D, at: Vector3) -> void:
	var m := Node3D.new()
	m.name = anchor_name
	m.position = at
	parent.add_child(m)
	_anchors[anchor_name] = m


static func _lit(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


## A soft dark ellipse under the kart, shared by every kart.
static func _blob() -> StandardMaterial3D:
	if _shadow_material:
		return _shadow_material
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_shadow_material = mat
	return mat
