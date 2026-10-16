class_name KartQualityGovernor
extends RefCounted
## Kart Race's adaptive quality (#43, the tablet with the face tracker running). While racing it
## averages the frame rate over WINDOW_SEC; a window below TARGET_FPS steps down one tier. Each
## window starts afresh after it's judged, so steps are at least WINDOW_SEC of racing apart. It
## never steps back up: a session (a new governor) starts at full quality, and the tier holds
## from race to race. Frames outside racing (the grid, countdowns, boards) don't count.
##
## Plain logic: KartRace feeds it frame times and applies `tier` to the world (`TIERS`).

## The tablet is CPU-bound (the main thread), so the trims that save main-thread work come
## first, the GPU-side ones last (docs/GAMES.md, Kart Race → On the tablet): 0 everything on;
## 1 half the effects' particle caps (their simulation runs in GDScript); 2 trackside foliage
## drawn to 150 m instead of 230 (fewer objects to cull and draw); 3 half the grandstand crowd;
## 4 render scale 0.58 instead of 0.62.
const TIERS: Array[StringName] = [&"full", &"fx", &"foliage", &"crowd", &"scale"]
const WINDOW_SEC := 4.0
const TARGET_FPS := 56.0

## The lowest tier it may reach.
var floor_tier := TIERS.size() - 1
var tier := 0
## The last judged window's average fps (0 before the first).
var last_fps := 0.0
## Every step taken: {tier, fps}.
var steps: Array[Dictionary] = []

var _time := 0.0
var _frames := 0


## One frame of `delta` seconds; `racing` counts it. True when this frame stepped down a tier.
func sample(delta: float, racing: bool) -> bool:
	if not racing:
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
	if last_fps >= TARGET_FPS or tier >= floor_tier:
		return false
	tier += 1
	steps.append({"tier": tier, "fps": last_fps})
	return true


func tier_name() -> StringName:
	return TIERS[tier]


## Whether the trim named `name` is in force at the current tier.
func trims(name: StringName) -> bool:
	var at := TIERS.find(name)
	return at > 0 and tier >= at
