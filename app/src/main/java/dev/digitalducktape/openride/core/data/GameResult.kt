package dev.digitalducktape.openride.core.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index

/**
 * One segment's result in a mini-games session (#35): a game's `segment_finished`, or the zero
 * result Kotlin records when a game doesn't report in time. A session records as one [Ride]
 * plus one row here per segment played or skipped. Added in schema version 6 ([MIGRATION_5_6]).
 *
 * Since the Games hub (schema 8, [MIGRATION_7_8]) one ride is a whole visit, which can hold
 * several plans, so each row names its own plan ([planId]). Older rows have none and read
 * their plan through [Ride.gamePlan]: queries use `COALESCE(planId, gamePlan)`.
 *
 * The enum-like columns hold the Bridge contract's wire words (docs/GAMES.md), so rows read the
 * same as the JSON the games sent.
 *
 * @param segmentIndex 0-based position in the ride: the plan's segments, continued across a
 *   visit's plans (0, 1, 2… over the whole visit).
 * @param role `warmup`, `work`, `recovery`, `cooldown` or `free` (a Just Ride).
 * @param difficulty `easy`, `standard` or `hard`.
 * @param startSec ride seconds (pauses excluded) when the segment started, intro card included.
 *   In a hub visit this is the ride clock, so it lines up with the ride's samples.
 * @param durationSec gameplay seconds actually played, intro card excluded.
 * @param won null for games without a winner.
 * @param statsJson the game's `stats` object as JSON text (`effort_avg`, `played_sec`, …).
 * @param variant the game's own variant, such as Dodge Ball's `catch` mode, or `""`. Bests and
 *   leaderboards are kept per variant. Added in schema version 7 ([MIGRATION_6_7]).
 * @param planId the plan this segment belonged to (`just-ride:…`, `circuit-20`, `custom:…`), or
 *   null for rows before schema 8, whose plan is their ride's [Ride.gamePlan].
 * @param planRun the plan's 0-based run within the ride (the visit's plan index), so two runs
 *   of one plan in a visit are two candidates for its best. 0 for older rows.
 */
@Entity(
    tableName = "game_results",
    primaryKeys = ["rideId", "segmentIndex"],
    foreignKeys = [
        ForeignKey(
            entity = Ride::class,
            parentColumns = ["id"],
            childColumns = ["rideId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("gameId")],
)
data class GameResult(
    val rideId: Long,
    val segmentIndex: Int,
    val gameId: String,
    val role: String,
    val difficulty: String,
    val startSec: Int,
    val durationSec: Int,
    val score: Double,
    val stars: Int,
    val won: Boolean?,
    val skipped: Boolean,
    val statsJson: String,
    @ColumnInfo(defaultValue = "") val variant: String = "",
    val planId: String? = null,
    @ColumnInfo(defaultValue = "0") val planRun: Int = 0,
)
