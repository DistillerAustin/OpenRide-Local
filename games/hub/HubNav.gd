class_name HubNav
extends RefCounted
## The hub's screen stack (spec §8.1): ids with their args, top last. Only the top screen is
## built; the hub frees a screen when it leaves and rebuilds it from `Session.hub` and HubPrefs
## when it comes back. The home screen is always at the bottom.
##
## Picked over a TabContainer (every page built up front, small tab targets, no back stack) and
## over showing and hiding pre-built screens (more live nodes; on the tablet the canvas's CPU
## side is the cost).

signal changed(id: String, args: Dictionary)

const HOME := "home"
const GAME := "game"
const CIRCUIT := "circuit"
const SETTINGS := "settings"
const MY_CIRCUITS := "my_circuits"
const BUILDER := "builder"

var _stack: Array = [{"id": HOME, "args": {}}]


func top() -> Dictionary:
	return _stack.back()


func top_id() -> String:
	return str(_stack.back().id)


func depth() -> int:
	return _stack.size()


func push(id: String, args := {}) -> void:
	_stack.append({"id": id, "args": args})
	changed.emit(id, args)


## Steps back a screen; false (nothing changes) on the home screen.
func pop() -> bool:
	if _stack.size() <= 1:
		return false
	_stack.pop_back()
	changed.emit(top_id(), top().args)
	return true


func reset_to_home() -> void:
	_stack = [{"id": HOME, "args": {}}]
	changed.emit(HOME, {})


## The stack as plain data, to restore it when the hub comes back after a plan.
func snapshot() -> Array:
	return _stack.duplicate(true)


## Restores a snapshot (without signalling: the hub builds the top itself).
func restore(stack: Array) -> void:
	if stack.is_empty() or str(stack[0].get("id", "")) != HOME:
		_stack = [{"id": HOME, "args": {}}]
	else:
		_stack = stack.duplicate(true)
