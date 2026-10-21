extends GdUnitTestSuite
## The hub's avatar (AvatarView): Kotlin re-renders the rider's PNG at the same path every visit,
## so a changed photo or emoji must show, and a failed load must not stick (review of PR #58).

const PATH := "user://avatar_view_test.png"


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _write(color: Color) -> void:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.save_png(PATH)


func test_a_re_rendered_avatar_at_the_same_path_is_reloaded() -> void:
	_write(Color.RED)
	var first := AvatarView.load_png(PATH)
	assert_object(first).is_not_null()
	assert_object(AvatarView.load_png(PATH)).is_same(first)  # unchanged: cached
	OS.delay_msec(1100)  # file times have one-second resolution
	_write(Color.BLUE)
	var second := AvatarView.load_png(PATH)
	assert_object(second).is_not_same(first)
	assert_that(second.get_image().get_pixel(0, 0)).is_equal(Color.BLUE)


func test_a_missing_avatar_is_tried_again_later() -> void:
	assert_object(AvatarView.load_png(PATH)).is_null()
	_write(Color.GREEN)
	assert_object(AvatarView.load_png(PATH)).is_not_null()
