class_name KartBaked
extends TextureRect
## A HUD widget baked into a texture (#43, the tablet's draw-call budget). The widget moves into
## its own small transparent SubViewport, which renders only when something inside it redraws
## (a label's text, a custom `_draw`, a portrait swapped in), is shown or hidden, or moves (a
## tweened row), plus `keep(seconds)` for anything else. On screen it's this one TextureRect:
## one draw call however many labels, outlines, panels and portraits the widget has.
##
## Measured on the desktop: the lap badge 8 calls → 1, the racer list 8 → 1, the ride strip 9 → 1,
## the place badge 8 → 1. The widget keeps working as before (its parent is now the viewport);
## put scale/rotation tweens on this rect (`pivot_offset` matches the widget's), not the widget.
##
## The viewport's texture holds premultiplied alpha (drawn over a clear background), so it's
## drawn with a premultiplied blend: soft edges keep their brightness.

const PAD := 12.0  ## room around the widget for outlines and small pops

var widget: Control
var viewport: SubViewport
var renders := 0  ## renders made, for tests
## At most one render per this many seconds (a readout that changes every frame needn't
## re-render every frame); 0 = whenever it changes.
var min_interval := 0.0

var _keep := 0.0
var _pending := false
var _since := INF
static var _premult: CanvasItemMaterial


## Bakes `w` (positioned in `parent`'s space; `bake_size` when its own size isn't known yet, as
## for a container) and takes its place in `parent`.
func _init(w: Control, parent: Control, bake_size := Vector2.ZERO) -> void:
	widget = w
	var area := bake_size if bake_size != Vector2.ZERO else w.size
	name = "Baked_" + str(w.name)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.name = "Bake"
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.size = Vector2i(ceili(area.x + PAD * 2.0), ceili(area.y + PAD * 2.0))
	add_child(viewport)
	if w.get_parent():
		w.get_parent().remove_child(w)
	position = w.position - Vector2(PAD, PAD)
	size = Vector2(viewport.size)
	pivot_offset = w.pivot_offset + Vector2(PAD, PAD)
	w.position = Vector2(PAD, PAD)
	viewport.add_child(w)
	texture = viewport.get_texture()
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	if _premult == null:
		_premult = CanvasItemMaterial.new()
		_premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = _premult
	parent.add_child(self)
	_watch(w)
	w.visibility_changed.connect(func():
		visible = w.visible
		_render())


## Render once more now, and every frame for `seconds` (motion that doesn't redraw).
func keep(seconds := 0.0) -> void:
	_keep = maxf(_keep, seconds)
	_render()


func _process(delta: float) -> void:
	_since += delta
	if _keep > 0.0:
		_keep -= delta
		_pending = true
	if _pending and _since >= min_interval:
		_pending = false
		_since = 0.0
		renders += 1
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _render() -> void:
	_pending = true


## Every canvas item under the widget: a redraw re-renders the bake (rows added later too).
func _watch(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).draw.is_connected(_render):
		(n as CanvasItem).draw.connect(_render)
		(n as CanvasItem).visibility_changed.connect(_render)
	if n is Control and not (n as Control).item_rect_changed.is_connected(_render):
		(n as Control).item_rect_changed.connect(_render)  # moved or resized (a row sliding)
	if not n.child_entered_tree.is_connected(_on_entered):
		n.child_entered_tree.connect(_on_entered)
	for c in n.get_children():
		_watch(c)


func _on_entered(n: Node) -> void:
	_watch(n)
