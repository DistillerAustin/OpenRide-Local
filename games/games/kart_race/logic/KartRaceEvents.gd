class_name KartRaceEvents
extends RefCounted
## Everything that happens in a race, as signals (#43, DESIGN.md "Signal map"). One instance per
## race, owned by `KartRaceLogic` (`race.events`); `KartPhysics` and the item logic emit into
## it during the fixed step. The views, HUD, audio and scoring only listen: none of them reaches
## into the logic to find out what happened.
##
## Kart ids are indexes into `KartRaceLogic.karts` (0 is the rider). Places are 1-based.

signal race_started()
signal lap_completed(kart_id: int, lap: int, lap_time: float)  ## lap: the lap just completed, 1-based
signal final_lap(kart_id: int)
signal kart_finished(kart_id: int, place: int, time: float)
signal race_finished(order: Array)  ## kart ids, first to last
signal position_changed(kart_id: int, old_place: int, new_place: int)
signal drift_started(kart_id: int, dir: int)
signal drift_tier(kart_id: int, tier: int)
signal boost_started(kart_id: int, kind: String, tier: int)  ## kind: "drift"|"pad"|"item"|"start"
signal item_picked(kart_id: int, item: String)
signal item_used(kart_id: int, item: String)
signal kart_hit(kart_id: int, by_id: int, item: String)
signal shield_blocked(kart_id: int)
signal wall_bump(kart_id: int, strength: float)  ## strength 0..1
signal kart_bump(a_id: int, b_id: int, strength: float)  ## strength 0..1
