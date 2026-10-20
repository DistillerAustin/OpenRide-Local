extends GdUnitTestSuite
## Every hub button clicks as it goes down (bike test, 2026-10-20): buttons on the screen that
## opens first and on screens opened later, dialog buttons too, once per press.

var local: Node
var hub: Node


func before_test() -> void:
	local = Session._local
	local.process_mode = Node.PROCESS_MODE_DISABLED
	Session.director.phase = SessionDirector.Phase.IDLE
	local.hub.begin_visit()
	hub = get_tree().current_scene
	await _settle()


func after_test() -> void:
	local.hub.phase = ""
	Session.visit_id = ""
	Session.hub = {}
	local.process_mode = Node.PROCESS_MODE_INHERIT


func test_every_button_on_the_first_screen_clicks_once_per_press() -> void:
	var buttons := _buttons(hub.screen)
	assert_int(buttons.size()).is_greater(0)
	for b in buttons:
		var before: int = hub.taps
		b.button_down.emit()
		assert_int(hub.taps).override_failure_message("%s did not click" % b.get_path()).is_equal(before + 1)


func test_buttons_on_a_screen_opened_later_click_too() -> void:
	hub.nav.push(HubNav.SETTINGS, {})
	await _settle()
	var buttons := _buttons(hub.screen)
	assert_int(buttons.size()).is_greater(0)
	var before: int = hub.taps
	buttons[0].button_down.emit()
	assert_int(hub.taps).is_equal(before + 1)


func _buttons(root: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	for n in root.find_children("*", "BaseButton", true, false):
		out.append(n)
	return out


func _settle() -> void:
	for i in 10:
		await get_tree().process_frame
