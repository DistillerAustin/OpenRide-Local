class_name KartTrackPoint
extends RefCounted
## One answer from `KartTrackModel`: a place on the track in both track space (s, d) and the
## world.

var s: float  ## metres along the centre line from the start line, 0..length
var d: float  ## metres across the road from the centre line, + = the driver's right
var position: Vector3  ## the point on the road surface at (s, d)
var height: float  ## the road surface's y at (s, d)
var tangent: Vector3  ## unit, along the road in the driving direction (follows the grade)
var right: Vector3  ## unit, horizontal, to the driver's right: the d axis
var normal: Vector3  ## unit, the road surface's up (banking and grade included)
