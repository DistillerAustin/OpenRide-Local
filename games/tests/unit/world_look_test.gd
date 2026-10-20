extends GdUnitTestSuite
## The 3D games' shared world look (WorldLook, framework/shaders/world_look.gdshaderinc): the
## include compiles with its defaults and with a game's grade defines, `apply` sets only the look's
## uniforms, the sun direction follows the time-of-day convention, and the noise matches Dodge
## Ball's.

const INCLUDE := "res://framework/shaders/world_look.gdshaderinc"


## The uniform names of a spatial shader built on the include (empty when it fails to compile).
func _uniforms(defines: String) -> Array:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled;
%s
#include "%s"
varying vec3 v_light;
void vertex() {
	v_light = sun_light(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}
void fragment() {
	vec3 col = vec3(0.5) * (0.8 + 0.4 * vnoise(UV * 64.0)) * v_light;
	ALBEDO = grade(haze(col, length(VERTEX)), SCREEN_UV);
}
""" % [defines, INCLUDE]
	return shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return str(u.name))


func test_the_include_compiles_with_its_defaults() -> void:
	var names := _uniforms("")
	for p in WorldLook.PARAMS:
		assert_array(names).contains([String(p)])


func test_a_games_grade_defines_compile() -> void:
	var names := _uniforms("""#define LOOK_SAT 1.1
#define LOOK_CONTRAST 1.05
#define LOOK_GAIN vec3(1.03, 1.0, 0.96)
#define LOOK_LIFT vec3(0.01, 0.0, 0.03)
#define LOOK_VIGNETTE 0.3
#define LOOK_VIGNETTE_TINT vec3(0.9, 0.85, 1.05)""")
	assert_array(names).contains(["haze_color", "noise_tex"])


func test_apply_sets_the_look_and_skips_the_rest() -> void:
	var shader := Shader.new()
	shader.code = "shader_type spatial;\n#include \"%s\"\nuniform float own = 1.0;\nvoid fragment() { ALBEDO = haze(hemi(NORMAL), 1.0); }" % INCLUDE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("own", 2.0)
	var plain := StandardMaterial3D.new()
	WorldLook.apply([mat, plain, null], {
		&"haze_color": Color(0.2, 0.3, 0.4), "haze_density": 0.01, &"sun_dir": Vector3.UP,
		"own": 9.0, "lamp_glow": 1.0})
	assert_object(mat.get_shader_parameter("haze_color")).is_equal(Color(0.2, 0.3, 0.4))
	assert_float(mat.get_shader_parameter("haze_density")).is_equal_approx(0.01, 0.00001)
	assert_vector(mat.get_shader_parameter("sun_dir")).is_equal(Vector3.UP)
	assert_float(mat.get_shader_parameter("own")).is_equal(2.0)


func test_sun_dir_follows_the_time_of_day_convention() -> void:
	assert_vector(WorldLook.sun_dir(90.0, 0.0)).is_equal_approx(Vector3.UP, Vector3.ONE * 0.0001)
	assert_vector(WorldLook.sun_dir(0.0, 0.0)).is_equal_approx(Vector3.FORWARD, Vector3.ONE * 0.0001)
	assert_vector(WorldLook.sun_dir(0.0, 90.0)).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.0001)
	assert_float(WorldLook.sun_dir(38.0, -150.0).length()).is_equal_approx(1.0, 0.0001)


func test_the_noise_is_dodge_balls() -> void:
	var a := WorldLook.noise_texture().get_image()
	var b := DodgeWorld._noise_texture().get_image()
	assert_int(a.get_width()).is_equal(64)
	assert_bool(a.get_data() == b.get_data()).is_true()
