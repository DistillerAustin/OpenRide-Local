class_name KartBotDriver
extends RefCounted
## A bot's driving (#43), v0: it holds its share of the rider's FTP (drifting ±4% over time, no
## reaction to the rider) and follows the racing line, offset to its own lane, by pure pursuit.
## It drives through the same `KartPhysics` as the rider, so the race is honest. The race-systems
## agent owns the full version: overtaking, avoidance, drifting, items, hazards.
##
## profile: {power_pct, line_offset, drift_skill, item_skill, aggression}

const POWER_WANDER := 0.04  ## ± share of the bot's power, slowly over time
const WANDER_HZ := 0.03
const LOOKAHEAD_SEC := 0.6
const LOOKAHEAD_MIN := 6.0
const LOOKAHEAD_MAX := 18.0
const EDGE_MARGIN := 1.2  ## the bot's line keeps this far inside the road's edge
const CADENCE := 85.0

var profile: Dictionary
var ftp_w: float
var power_pct: float
var line_offset: float
var _noise := FastNoiseLite.new()
var _t := 0.0
var _input := KartInput.new()


func _init(bot_profile: Dictionary, rider_ftp_w: float, rng_seed: int) -> void:
	profile = bot_profile
	ftp_w = rider_ftp_w
	power_pct = float(profile.get("power_pct", 0.6))
	line_offset = float(profile.get("line_offset", 0.0))
	_noise.seed = rng_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = WANDER_HZ


## The watts the bot pedals at `t` seconds into its life.
func power_at(t: float) -> float:
	return ftp_w * power_pct * (1.0 + POWER_WANDER * clampf(_noise.get_noise_1d(t) * 1.6, -1.0, 1.0))


func think(k: KartState, race: KartRaceLogic, dt: float) -> KartInput:
	_t += dt
	var track := race.track
	_input.power_w = power_at(_t)
	_input.cadence = CADENCE
	_input.resistance = 30.0
	_input.use_item = false
	# Pure pursuit toward a point ahead on the bot's line.
	var ahead := clampf(k.speed * LOOKAHEAD_SEC, LOOKAHEAD_MIN, LOOKAHEAD_MAX)
	var s := track.wrap(k.s + ahead)
	var limit := maxf(0.0, track.half_width(s) - EDGE_MARGIN)
	var target := track.position_at(s, clampf(track.racing_line(s) + line_offset, -limit, limit))
	var to := target - k.pos
	var alpha := angle_difference(k.heading, atan2(-to.x, -to.z))  # + = the target is to the left
	var dist := maxf(1.0, Vector2(to.x, to.z).length())
	var yaw_rate := 2.0 * k.speed * sin(alpha) / dist
	_input.lean = race.physics.lean_for_yaw_rate(k, track, yaw_rate)
	return _input
