class_name TugQualityGovernor
extends RefCounted
## Tug of War's one quality step (the tablet with the face tracker on; Kart Race's
## `KartQualityGovernor` is the prior art). While a round is being pulled it averages the frame
## rate over WINDOW_SEC; a window below TARGET_FPS steps down to the low tier, once. It never
## steps back up: each game (a new governor) starts at full quality. Frames outside a round (the
## intro, a fall, the rest between rounds) don't count, so a splash or a board doesn't trip it.
##
## Plain logic: TugOfWar feeds it frame times and applies the tier (`render_scale`).

## 0 full; 1 the 3D view at LOW_SCALE of the screen instead of TugOfWar.RENDER_SCALE (about a
## fifth fewer pixels; the HUD stays sharp). The tablet's GPU is fill-rate bound, and every
## per-pixel trim that keeps the look is already in (GFX_POLISH.md, Tablet performance), so the
## step left is fewer pixels.
const TIERS: Array[StringName] = [&"full", &"scale"]
const WINDOW_SEC := 4.0
const TARGET_FPS := 54.0
const LOW_SCALE := 0.55

var tier := 0
## The last judged window's average fps (0 before the first).
var last_fps := 0.0

var _time := 0.0
var _frames := 0


## One frame of `delta` seconds; `pulling` counts it. True when this frame stepped down.
func sample(delta: float, pulling: bool) -> bool:
	if not pulling:
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
