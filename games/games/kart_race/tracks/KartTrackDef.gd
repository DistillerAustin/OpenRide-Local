class_name KartTrackDef
extends Resource
## One Kart Race track as data (#43, games/kart_race/DESIGN.md "Tracks"). `KartTrackModel` bakes
## it into track space; the world builders dress it.
##
## The centre line is a closed loop through `points`, in metres, y up, driven in the order given
## (a smooth spline passes through every point). Per-point values (`half_widths`, `banking`) are
## interpolated along the road. Zone `s0`/`s1` are metres along the centre line from `points[0]`,
## driving forward; `KartTrackModel` re-bases them on the start line (and mirrors them in reversed
## mode).

@export var id: String
@export var title: String
@export var theme: String  ## "meadow" | "canyon" | "harbor" | "frost"
@export var points: PackedVector3Array  ## closed loop control points, metres, y up
@export var half_widths: PackedFloat32Array  ## per control point (interpolated), road half-width
@export var banking: PackedFloat32Array  ## per control point, radians; + = the right edge is higher
@export var verge: float = 4.0  ## off-road band beyond the road before the wall
## {type: "climb"|"boost"|"items"|"start", s0: float, s1: float, ...}. Optional extras: `d` (the
## centre of a boost pad across the road, + = right), `w` (a pad's half-width).
@export var zones: Array[Dictionary]
@export var start_s: float = 0.0  ## where the start/finish line is, metres from points[0]
