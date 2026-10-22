class_name AvatarView
extends Control
## The rider's avatar in a circle (spec §4.3): Kotlin's 256x256 PNG (`rider.avatar_png`, loaded
## again when the file changes), or the rider's initial on their avatar colour. Drawn inside the header's
## bake, so its shapes cost nothing per frame.

const SEGMENTS := 48

## path → [modified time, ImageTexture]: Kotlin re-renders the PNG at the same path every visit,
## so a newer file (a changed photo or emoji) replaces the cached texture.
static var _textures := {}

var texture: Texture2D
var color := Color("7a7cff")
var initial := ""
var ring := Color.WHITE


func _init(diameter := 110.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## From hub_state's rider.
func set_rider(rider: Dictionary) -> void:
	texture = load_png(rider.get("avatar_png"))
	color = Color.from_string(str(rider.get("avatar_color", "#7A7CFF")), Color("7a7cff"))
	var name_text := str(rider.get("name", "")).strip_edges()
	initial = name_text.substr(0, 1).to_upper() if not name_text.is_empty() else "?"
	queue_redraw()


static func load_png(path) -> Texture2D:
	if path == null or str(path).is_empty():
		return null
	var key := str(path)
	if not FileAccess.file_exists(key):
		return null
	var stamp := FileAccess.get_modified_time(key)
	var cached: Array = _textures.get(key, [])
	if not cached.is_empty() and cached[0] == stamp:
		return cached[1]
	var image := Image.load_from_file(key)
	if image == null:
		return null  # not cached: the next visit's render is tried again
	var tex := ImageTexture.create_from_image(image)
	_textures[key] = [stamp, tex]
	return tex


func _draw() -> void:
	var r := size.x / 2.0
	var c := size / 2.0
	draw_circle(c, r, ring)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var p := Vector2(cos(a), sin(a))
		points.append(c + p * (r - 5.0))
		uvs.append(Vector2(0.5, 0.5) + p * 0.5)
	if texture:
		draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)
	else:
		draw_colored_polygon(points, color)
		var font := GameTheme.display_font()
		var fs := int(size.y * 0.52)
		var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := c.y + font.get_ascent(fs) * 0.36
		draw_string_outline(font, Vector2(c.x - w / 2.0, base), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, color.darkened(0.55))
		draw_string(font, Vector2(c.x - w / 2.0, base), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
