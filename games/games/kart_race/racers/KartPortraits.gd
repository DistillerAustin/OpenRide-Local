class_name KartPortraits
extends RefCounted
## Racer portraits for the HUD and the boards (#43): each racer's head (KartModels.head) rendered
## once into a small transparent SubViewport, three-quarter view, framed from the mesh's bounds
## so tall ears fit. `texture(parent, racer)` returns the viewport's texture; the viewport is
## added under `parent` and renders once.

const SIZE := 160
const YAW := 0.42  ## turned a little towards the viewer's left


static func texture(parent: Node, racer: Dictionary, size := SIZE) -> ViewportTexture:
	var vp := SubViewport.new()
	vp.name = "Portrait_%s" % str(racer.get("id", ""))
	vp.size = Vector2i(size, size)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(vp)
	var head := MeshInstance3D.new()
	head.mesh = KartView.head_mesh(racer)
	head.material_override = KartLook.kart_material(true)
	head.rotation = Vector3(0.05, YAW, 0.0)
	vp.add_child(head)
	var cam := Camera3D.new()
	var f := framing(head.mesh)
	cam.fov = f.fov
	vp.add_child(cam)
	cam.look_at_from_position(f.eye, f.at, Vector3.UP)
	cam.current = true
	return vp.get_texture()


## Where the portrait camera sits and looks for a head mesh: the face centred, the ears' tips in.
static func framing(mesh: Mesh) -> Dictionary:
	var box := mesh.get_aabb()
	var top := box.end.y
	var bottom := box.position.y
	var height := maxf(top - bottom, box.size.x)
	var at := Vector3(0.0, (top + bottom) * 0.5 - 0.02, 0.0)
	var fov := 34.0
	var dist := height * 0.56 / tan(deg_to_rad(fov * 0.5))
	return {"eye": at + Vector3(0.0, 0.04, -dist), "at": at, "fov": fov}
