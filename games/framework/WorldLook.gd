class_name WorldLook
extends RefCounted
## The 3D games' shared world look (framework/shaders/world_look.gdshaderinc): the hand-made sun,
## hemisphere ambient and haze every world shader lights itself with, so a game sets its light
## once for all its materials. Kart Race keeps its own (`KartLook`, light.gdshaderinc).
##
## A look is a Dictionary of the include's uniforms (`PARAMS`); keys it doesn't know are ignored,
## so a game can pass a richer table (its time-of-day preset's other values) straight through.

const PARAMS: Array[StringName] = [&"sun_dir", &"sun_color", &"sky_color", &"ground_color",
	&"haze_color", &"haze_density", &"haze_max", &"noise_tex"]


## Sets `look`'s values on every ShaderMaterial in `materials` (others are skipped). Colours may be
## Color or Vector3; the shader takes either.
static func apply(materials: Array, look: Dictionary) -> void:
	for mat in materials:
		var sm := mat as ShaderMaterial
		if sm == null:
			continue
		for key in PARAMS:
			if look.has(key):
				sm.set_shader_parameter(key, look[key])
			elif look.has(String(key)):
				sm.set_shader_parameter(key, look[String(key)])


## The direction towards the sun (unit, world space) for an elevation above the horizon and an
## azimuth from straight ahead (-z), positive to the right (+x), both in degrees: the convention of
## Dodge Ball's time-of-day presets.
static func sun_dir(elevation_deg: float, azimuth_deg: float) -> Vector3:
	var e := deg_to_rad(elevation_deg)
	var a := deg_to_rad(azimuth_deg)
	return Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))


## The shared 64x64 random-value texture behind `vnoise` (linear filtering with repeat makes it
## value noise). The same seed gives the same texture as Dodge Ball's, so a shader moved onto the
## include keeps its pattern. GLES3 keeps filtering per texture: make another for nearest reads.
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
