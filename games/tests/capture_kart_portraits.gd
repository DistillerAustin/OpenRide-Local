extends SceneTree
## Bakes Kart Race's racer portraits for the Games hub's kart cards (spec §7.2): each racer's
## head (KartPortraits, the HUD's live render) over its round backdrop in the kart's colour with
## a white ring (ui/shaders/portrait.gdshader's look, composited here: that shader's alpha is the
## texture's, so on its own it would drop the disc), saved as games/kart_race/ui/portraits/<racer>.png
## (SIZE x SIZE, transparent outside the disc, straight alpha). The hub shows these PNGs, so it
## never loads Kart Race's 3D. Not headless; run it again after a racer's look changes:
##   $GODOT_BIN --path games --resolution 1920x1080 -s res://tests/capture_kart_portraits.gd

const SIZE := 256
const OUT := "res://games/kart_race/ui/portraits/"
## portrait.gdshader with the head as a uniform, drawn on a ColorRect: the disc stays opaque.
const COMPOSITE := """
shader_type canvas_item;
uniform sampler2D head : filter_linear;
uniform vec4 backdrop : source_color = vec4(0.9, 0.4, 0.2, 1.0);
uniform vec4 ring : source_color = vec4(1.0);
uniform float ring_width = 0.09;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = fwidth(r) * 1.5;
	vec4 h = texture(head, UV);
	vec3 bg = mix(backdrop.rgb * 1.25, backdrop.rgb * 0.55, smoothstep(0.0, 1.0, r + p.y * 0.3));
	vec3 col = mix(bg, h.rgb, h.a);
	float inner = 1.0 - ring_width;
	col = mix(col, ring.rgb, smoothstep(inner - aa, inner, r));
	col = mix(col, vec3(0.12, 0.06, 0.24), smoothstep(1.0 - aa * 2.0 - 0.03, 1.0 - 0.03, r));
	COLOR = vec4(col, 1.0 - smoothstep(1.0 - aa, 1.0, r));
}
"""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var holder := Node.new()
	root.add_child(holder)
	var shader := Shader.new()
	shader.code = COMPOSITE
	for racer in KartRoster.RACERS:
		var head: ViewportTexture = KartPortraits.texture(holder, racer, SIZE)
		var comp := SubViewport.new()
		comp.size = Vector2i(SIZE, SIZE)
		comp.transparent_bg = true
		comp.disable_3d = true
		comp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		holder.add_child(comp)
		var rect := ColorRect.new()
		rect.size = Vector2(SIZE, SIZE)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("head", head)
		mat.set_shader_parameter("backdrop", racer.get("color", Color(0.5, 0.4, 0.9)))
		mat.set_shader_parameter("ring", Color(1, 1, 1))
		rect.material = mat
		comp.add_child(rect)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = comp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		_unpremultiply(img)
		var path := ProjectSettings.globalize_path(OUT + str(racer.id) + ".png")
		var err := img.save_png(path)
		print("PORTRAIT %s -> %s (%d)" % [racer.id, path, err])
		comp.queue_free()
	quit(0)


## The viewport holds premultiplied colour (drawn over a clear background); a PNG wants straight.
static func _unpremultiply(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.a < 1.0:
				img.set_pixel(x, y, Color(minf(c.r / c.a, 1.0), minf(c.g / c.a, 1.0), minf(c.b / c.a, 1.0), c.a))
