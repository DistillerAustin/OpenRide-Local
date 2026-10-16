class_name GameMix
extends RefCounted
## Shared mix settings for the games (#55): the Master chain every game sets (a limiter, so the
## sum of music, effects and cues never clips) and the duck a game asks for under its own big
## moments (a sting, a banner).

const MASTER_CEILING_DB := -1.0
const STING_DUCK_DB := -8.0  ## the music under a game's sting or banner
const MOMENT_DUCK_DB := -5.0  ## under a smaller moment that must read (a hit, a streak)


## The Master bus chain: a hard limiter at -1 dBFS.
static func master_effects() -> Array[AudioEffect]:
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = MASTER_CEILING_DB
	limiter.release = 0.12
	return [limiter]


## Ducks the music under a game's sting or banner for `seconds`.
static func duck_for_sting(seconds: float) -> void:
	AudioDirector.duck_music(STING_DUCK_DB, seconds)


## Ducks the music a little under a smaller moment.
static func duck_for_moment(seconds: float) -> void:
	AudioDirector.duck_music(MOMENT_DUCK_DB, seconds)
