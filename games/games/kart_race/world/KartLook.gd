class_name KartLook
extends RefCounted
## Kart Race's art direction in one place (#43, the hero slice): the late-afternoon light every
## shader shares, and material factories that set it. Everything in the world is `unshaded` and
## lit by hand from these values (shaders/light.gdshaderinc), so the karts, the road and the
## scenery always agree, and no engine light pass runs on the tablet.

## Towards the sun: low in the west-south-west, behind and left of the start straight's chase
## view, so karts on the grid are lit and their shadows stretch long to the right.
const SUN_DIR := Vector3(-0.762, 0.438, -0.476)
const SUN_COLOR := Color(1.0, 0.85, 0.64)
const SKY_AMBIENT := Color(0.52, 0.62, 0.84)
const GROUND_AMBIENT := Color(0.44, 0.40, 0.28)
const HAZE := Color(0.93, 0.84, 0.74)
const HAZE_DENSITY := 0.0024

const SHADERS := "res://games/kart_race/world/shaders/"

static var _noise: ImageTexture
static var _shaders := {}


static func noise() -> ImageTexture:
	if _noise == null:
		_noise = KartMeshKit.noise_texture(4242)
	return _noise


static func shader(file: String) -> Shader:
	if not _shaders.has(file):
		_shaders[file] = load(SHADERS + file)
	return _shaders[file]


## A ShaderMaterial on one of the world shaders, with the shared light set.
static func material(file: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader(file)
	apply_light(mat)
	return mat


static func apply_light(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	mat.set_shader_parameter("sun_color", SUN_COLOR)
	mat.set_shader_parameter("sky_color", SKY_AMBIENT)
	mat.set_shader_parameter("ground_color", GROUND_AMBIENT)
	mat.set_shader_parameter("haze_color", HAZE)
	mat.set_shader_parameter("haze_density", HAZE_DENSITY)
	mat.set_shader_parameter("noise_tex", noise())


## The kart paint and fur material, with its outline as the next pass.
static func kart_material(outline := true) -> ShaderMaterial:
	var mat := material("kart.gdshader")
	if outline:
		var line := ShaderMaterial.new()
		line.shader = shader("outline.gdshader")
		mat.next_pass = line
	return mat
