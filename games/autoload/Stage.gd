extends Node
## The centred stage (#57). Every layout is designed on a `HudTheme.W` x `HudTheme.H`
## (1920x1080) canvas, but stretch aspect `keep_height` shows more than that on a wider window:
## the bike's 1920x1008 window shows about 2057x1080 (a taller window letterboxes). Rather than letterbox, this autoload shifts the
## default canvas and every CanvasLayer of the root viewport by `pad`, so a Control at (0, 0)
## still sits at the stage's top left and the stage stays centred. Only full-screen pieces
## (backdrops, shades, 3D views) cover the whole canvas: `bleed(control)`, `view_size(scale)`.
##
## On a 16:9 or taller window (the desktop tests, headless runs, captures) `pad` is zero and
## nothing moves.

## The window, and so `pad` and `visible_size`, changed. A game resizes its 3D view on it.
signal changed

const BLEED_GROUP := &"stage_bleed"

var pad := Vector2.ZERO  ## the canvas shown left of (and above) the stage, in canvas pixels
var visible_size := Vector2(HudTheme.W, HudTheme.H)  ## the whole canvas the window shows


func _ready() -> void:
	get_tree().root.size_changed.connect(_refit)
	get_tree().node_added.connect(_on_node_added)
	_refit()


## The pad for a window that shows `visible` canvas pixels: half the extra on each side, whole
## pixels so the stage's edges stay crisp.
static func pad_for(visible: Vector2) -> Vector2:
	return ((visible - Vector2(HudTheme.W, HudTheme.H)) / 2.0).max(Vector2.ZERO).floor()


## The whole visible canvas in stage coordinates (it starts left of and above the stage).
func bleed_rect() -> Rect2:
	return Rect2(-pad, visible_size)


## Makes `control` cover the whole visible canvas, now and whenever the window changes. It must
## sit where the stage's origin is: a direct child of a CanvasLayer, a game or the hub.
func bleed(control: Control) -> void:
	control.add_to_group(BLEED_GROUP)
	_place(control)


## The pixel size of a 3D view drawn over the whole canvas at `scale` of its resolution.
func view_size(scale: float) -> Vector2i:
	return Vector2i((visible_size * scale).round())


## A point in a 3D view's pixels (a view drawn over `bleed_rect()`, `view_px` big) on the stage.
func from_view(point: Vector2, view_px: Vector2) -> Vector2:
	return point * (visible_size / view_px) - pad


## Applies a window showing `visible` canvas pixels (`_refit` reads it from the root viewport).
func fit(visible: Vector2) -> void:
	visible_size = visible.max(Vector2(HudTheme.W, HudTheme.H))
	pad = pad_for(visible_size)
	var root := get_tree().root
	root.canvas_transform = Transform2D(0.0, pad)
	for layer in root.find_children("*", "CanvasLayer", true, false):
		_offset(layer)
	for c in get_tree().get_nodes_in_group(BLEED_GROUP):
		_place(c)
	changed.emit()


func _refit() -> void:
	var visible := get_tree().root.get_visible_rect().size
	if visible.max(Vector2(HudTheme.W, HudTheme.H)) != visible_size:
		fit(visible)


func _on_node_added(node: Node) -> void:
	if node is CanvasLayer:
		_offset(node)
	elif node is Control and node.is_in_group(BLEED_GROUP):
		_place(node)


## Root-viewport layers only: a layer inside a SubViewport draws on that view, not the stage.
func _offset(layer: CanvasLayer) -> void:
	if layer.get_viewport() == get_tree().root and not layer.follow_viewport_enabled:
		layer.offset = pad


func _place(c: Control) -> void:
	c.position = -pad
	c.size = visible_size
