class_name KartState
extends RefCounted
## One kart's whole simulated state (#43). The logic writes it; the views only read it.

var id: int  ## its index in KartRaceLogic.karts; 0 is the rider
var racer_id: String  ## KartRoster's id
var weight := 1.0  ## 0.85 light .. 1.15 heavy (kart-kart contacts)
var pos: Vector3  ## on the road surface
var heading := 0.0  ## yaw, radians (Node3D.rotation.y: forward is -Z at 0, + turns left)
var speed := 0.0  ## kart m/s (world)
var v_bike := 0.0  ## virtual bike m/s
var s := 0.0  ## track space (KartTrackModel)
var d := 0.0
var lap := 0  ## start-line crossings: 0 on the grid, 1 on the first lap, laps + 1 when finished
var surface := 0  ## KartTrackModel.Surface under the kart
var normal := Vector3.UP  ## the road surface's normal under the kart (for the views)
var steer := 0.0  ## -1..1, + = right, for visuals
var drift_dir := 0  ## -1 left, 0 none, +1 right
var drift_charge := 0.0  ## seconds of charge
var drift_tier := 0  ## 0 none, 1-3 spark tiers
var knob_boosting := false  ## the resistance knob is speeding up the drift charge
var boost_time := 0.0  ## seconds of boost left
var spin_time := 0.0  ## seconds of spin-out left (no control)
var shield_time := 0.0  ## seconds of shield left
var hop := 0.0  ## visual hop height, metres
var item := ""  ## the held item's id, "" for none
var roulette_time := 0.0  ## seconds of item roulette left
var finished := false
var finish_time := 0.0  ## race seconds at the finish (projected for karts placed early)
var place := 0  ## 1-based race position
var draft := 0.0  ## 0..1 this tick


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))
