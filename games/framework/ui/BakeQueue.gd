class_name BakeQueue
extends RefCounted
## Spreads BakedView renders over frames (#43, the tablet's draw-call budget). A bake's render
## costs every draw call of its widget, so a results board whose eleven bakes all rendered in
## its first frame spiked to about 205 draw calls. Bakes that share a queue render at most
## `per_frame` of them a frame between them, first come first served.

var per_frame := 1

var _waiting: Array = []  ## BakedView, oldest first
var _frame := -1
var _used := 0


## Whether `bake` may render this frame; if not, it keeps its place in the line.
func grant(bake: Object) -> bool:
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_used = 0
	if not _waiting.has(bake):
		_waiting.append(bake)
	# Bakes that left the tree (a board's old rows) give up their place.
	while not _waiting.is_empty() and (not is_instance_valid(_waiting[0]) or not (_waiting[0] as Node).is_inside_tree()):
		_waiting.pop_front()
	if _used >= per_frame or _waiting.is_empty() or _waiting[0] != bake:
		return false
	_waiting.pop_front()
	_used += 1
	return true


## Bakes waiting their turn.
func waiting() -> int:
	return _waiting.size()
