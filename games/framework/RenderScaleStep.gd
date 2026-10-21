class_name RenderScaleStep
extends RefCounted
## A 3D game's one quality step on the tablet (Tug of War, Dodge Ball; Kart Race's
## `KartQualityGovernor` is the prior art). While the game says a frame counts (Tug: a round is
## being pulled; Dodge: play) it averages the frame rate over WINDOW_SEC; a window below
## TARGET_FPS steps down to the low tier, once. It never steps back up: each game (a new
## governor) starts at full quality. Frames that don't count (an intro, a fall, a board) reset
## the window, so a one-off hitch doesn't trip it.
##
## Plain logic: the game feeds it frame times and applies the tier (`render_scale`).

## 0 full; 1 the 3D view at LOW_SCALE of the screen instead of the game's RENDER_SCALE (0.62:
## about a fifth fewer pixels; the HUD stays sharp). The tablet's GPU is fill-rate bound, so the
## step is fewer pixels.
const TIERS: Array[StringName] = [&"full", &"scale"]
const WINDOW_SEC := 4.0
const TARGET_FPS := 54.0
const LOW_SCALE := 0.55

var tier := 0
## The last judged window's average fps (0 before the first).
var last_fps := 0.0

var _time := 0.0
var _frames := 0


## One frame of `delta` seconds, judged only when it `counts`. True when this frame stepped down.
func sample(delta: float, counts: bool) -> bool:
	if not counts:
		_time = 0.0
		_frames = 0
		return false
	_time += delta
	_frames += 1
	if _time < WINDOW_SEC:
		return false
	last_fps = _frames / _time
	_time = 0.0
	_frames = 0
	if last_fps >= TARGET_FPS or tier >= TIERS.size() - 1:
		return false
	tier += 1
	return true


## The 3D view's share of the screen at the current tier.
func render_scale(full_scale: float) -> float:
	return LOW_SCALE if tier >= 1 else full_scale
