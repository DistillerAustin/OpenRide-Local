# Kart Race: the module contract

Kart Race (#43) is a Grand Prix of 3-lap races against seven bots. The rider pedals to drive,
leans in front of the camera to steer, and taps to use items. This file freezes the contracts
the Phase 1 walking skeleton set up, so the Phase 2 agents can build in parallel against
them. **Change an interface below only with a matching change here** (and say so in your
report). Additions are fine; renames and removals are not.

Everything is original: the game, racers, items and tracks have our own names. Assets must be
original, procedural, CC0 or OFL, each listed in `games/assets/SOURCES.md` in the same commit.
Every new `class_name` starts with `Kart` (they share the project's global namespace).

## Layout and ownership

| Path | What | Phase 2 owner |
| --- | --- | --- |
| `KartRace.tscn`, `KartRace.gd` | The `Game`: lifecycle, the GP flow, the fixed step, wiring | shared: each agent edits only its own `_build_*` function plus a few lines of wiring |
| `logic/KartTrackModel.gd`, `KartTrackPoint.gd` | Track space | world |
| `logic/KartPhysics.gd`, `KartState.gd`, `KartInput.gd` | Handling | handling |
| `logic/KartRaceLogic.gd`, `KartRaceEvents.gd`, `KartGrandPrix.gd` | Race rules, events, the GP | frozen (changes go through the integrator) |
| `logic/KartBotDriver.gd`, `KartScoring.gd`, `KartItemLogic.gd` (new) | Bots, scoring, items | race-systems |
| `tracks/` | `KartTrackDef`, `KartTracks` (the cup), one script per track | world |
| `world/KartWorld.gd` (+ new builders, shaders) | The track's look | world |
| `world/KartView.gd` | One kart on screen | racers |
| `world/KartChaseCamera.gd` | The camera | handling |
| `world/KartItemViews.gd` (new), `world/KartFx.gd` (new) | Item views; effects | race-systems; presentation |
| `racers/KartRoster.gd` (+ models) | The eight racers | racers |
| `ui/` | `KartStatus`, `KartRaceBoard` (placeholders) and the rest of the HUD | presentation |
| `audio/` | Effects and music | presentation |

## Scene tree

```
KartRace (Node2D, KartRace.gd: extends Game)
├─ View3D (SubViewport, 0.62 × 1080p, no MSAA, UPDATE_ALWAYS)
│  └─ World (KartWorld: environment, sun, road, barriers, ground, trees)
│     ├─ ChaseCamera (KartChaseCamera, current)
│     └─ Kart_<racer> × 8 (KartView: Body, axles, shadow, anchors)
├─ View3DImage (TextureRect: the viewport scaled to 1920×1080 under the HUD)
└─ KartRaceBoard (CanvasLayer 9: results and standings, placeholder)
(the framework's Hud, CanvasLayer 10, holds KartStatus in its top-centre slot)
```

The 3D view renders into the SubViewport at `RENDER_SCALE` (Dodge Ball's pattern; never set
`Viewport.scaling_3d_scale` below 1: it hung the tablet). The HUD stays sharp over it.

## Data flow

Logic never touches nodes; nodes only read logic and listen to `KartRaceEvents`.

```
InputBus ──► KartRace._read_rider() ─┐
KartBotDriver.think() × 7 ───────────┴─► inputs[] ─► KartRaceLogic.step(1/60)
                                                         │  KartPhysics.step() per kart
                                                         │  laps, places, finish
                                                         ▼
                                              KartState × 8  +  KartRaceEvents signals
                                                         │             │
                     KartView.sync / KartChaseCamera.follow ◄──┘       ├─► KartScoring ─► Game.award()
                     KartStatus.set_state (HUD) ◄─────────────────────┤
                                                                       └─► KartRace (GP flow), HUD, audio, fx
```

- **The fixed step.** `_on_frame(delta)` adds delta to an accumulator and runs `_tick(1/60)`
  while it holds a tick (at most `MAX_TICKS` = 8 a frame), then syncs the views once. The
  framework stops `_on_frame` while paused, so pausing freezes the race, the bots and the
  clocks.
- **Per race**, `_begin_race()` builds a fresh `KartRaceLogic` (with its own `events`),
  rebuilds the world only when the track or direction changes, and emits
  `race_began(race)`. **Hook a race's events in a `race_began` handler** connected from your
  builder; don't edit `_begin_race`.
- `sim_time` counts simulated seconds; `test_input` (a `KartInput`) replaces the rider's input
  in tests.

## Track space

- `s`: metres along the centre line from the start/finish line, in the driving direction,
  `0..length`, wrapping. `d`: metres across, horizontal, **+ = the driver's right**.
- The surface at (s, d) is the centre point + d × the horizontal right, raised by `d·tan(bank)`
  (+ banking = the right edge higher).
- Curvature: **+ turns left**. Lean: **+1 = right**. Yaw (`heading`, `yaw_at`): Godot's
  `rotation.y`, 0 faces −Z, + turns left; forward = `(-sin yaw, 0, -cos yaw)`.
- Surfaces across the road: ROAD up to the half-width, KERB for `KERB_WIDTH` (0.8 m) beyond,
  OFFROAD to `half_width + verge`, WALL beyond.
- Reversed mode drives the same loop backwards: the start line stays put, s runs the other
  way, d, curvature, grade, banking and zone `d` flip sign, and zone spans are mirrored.
- A def's zone `s0`/`s1` are metres from `points[0]` driving forward; the model re-bases them
  on the start line. A zone with `s1 < s0` wraps past the line.

## Interfaces (frozen)

```gdscript
class_name KartTrackDef extends Resource
@export var id: String
@export var title: String
@export var theme: String                   # "meadow" | "canyon" | "harbor" | "frost"
@export var points: PackedVector3Array      # closed loop control points, metres, y up
@export var half_widths: PackedFloat32Array # per control point (interpolated), road half-width
@export var banking: PackedFloat32Array     # per control point, radians, + = right edge higher
@export var verge: float = 4.0              # off-road band beyond the road before the wall
@export var zones: Array[Dictionary]        # {type: "climb"|"boost"|"items"|"start", s0, s1, d?, w?}
@export var start_s: float = 0.0

class_name KartTrackPoint extends RefCounted
var s: float; var d: float; var position: Vector3; var height: float
var tangent: Vector3; var right: Vector3; var normal: Vector3

class_name KartTrackModel extends RefCounted
enum Surface { ROAD, KERB, OFFROAD, WALL }
const KERB_WIDTH := 0.8
var length: float
var def: KartTrackDef; var reversed: bool; var verge: float
var zones: Array[Dictionary]                       # re-based on the start line (and mirrored)
var curve: Curve3D                                 # the centre line, for views (its offsets aren't s)
func _init(def: KartTrackDef, reversed := false) -> void
func sample(s: float) -> KartTrackPoint            # centre line at s (d = 0)
func position_at(s: float, d: float) -> Vector3
func project(pos: Vector3, hint_s := -1.0) -> KartTrackPoint  # windowed (±25 m) near hint_s when given
func half_width(s: float) -> float
func surface(s: float, d: float) -> int
func curvature(s: float) -> float                  # signed 1/m, + = turning left
func grade(s: float) -> float                      # dy/ds
func racing_line(s: float) -> float                # target d: inside of corners, smoothed, ≥ 1.5 m inside the edge
func yaw_at(s: float) -> float                     # the driving direction as a yaw
func banking(s: float) -> float
func zones_at(s: float) -> Array[Dictionary]
static func in_span(s: float, s0: float, s1: float) -> bool
func wrap(s: float) -> float
func delta(from_s: float, to_s: float) -> float    # signed shortest distance along the loop

class_name KartTracks extends RefCounted           # the cup
const CUP := ["meadow_ring"]                       # GP order; the world agent adds the other three
const SCRIPTS := {"meadow_ring": "res://games/kart_race/tracks/meadow_ring.gd"}
static func build(track_id: String) -> KartTrackDef   # each track script has `static func build() -> KartTrackDef`
static func length_of(track_id: String) -> float      # cached
static func average_length() -> float

class_name KartInput extends RefCounted
var power_w := 0.0; var cadence := 0.0; var lean := 0.0   # -1 left .. +1 right
var resistance := 0.0; var standing := false; var use_item := false  # use_item is an edge

class_name KartState extends RefCounted
var id: int; var racer_id: String; var weight := 1.0          # 0.85 light .. 1.15 heavy
var pos: Vector3; var heading := 0.0                          # yaw, radians
var speed := 0.0                                               # kart m/s (world)
var v_bike := 0.0                                              # virtual bike m/s
var s := 0.0; var d := 0.0; var lap := 0; var surface := 0
var normal := Vector3.UP                                       # road normal under the kart (views)
var steer := 0.0                                               # -1..1, + = right, for visuals
var drift_dir := 0; var drift_charge := 0.0; var drift_tier := 0; var knob_boosting := false
var boost_time := 0.0; var spin_time := 0.0; var shield_time := 0.0
var hop := 0.0                                                 # visual hop height
var item := ""; var roulette_time := 0.0
var finished := false; var finish_time := 0.0; var place := 0
var draft := 0.0                                               # 0..1 this tick
func forward() -> Vector3

class_name KartPhysics extends RefCounted
const SPEED_SCALE := 2.4
const SPIN_SEC := 1.0; const KART_RADIUS := 0.95; const DEAD_ZONE := 0.06   # (and the tuning constants)
var assist := 1.0        # 0 off, 0.5 low, 1 high (curvature feed-forward and alignment share)
var drift_resistance := 40.0
var events: KartRaceEvents = null                  # set by KartRaceLogic; emit drift/boost events here
static func steady_bike_speed(power_w: float, grade: float, draft := 0.0) -> float   # m/s
static func bike_resistance(v: float, grade: float, draft := 0.0, crr_mult := 1.0) -> float
static func shape_lean(lean: float) -> float
static func lean_for_steer(steer: float) -> float
static func max_yaw_rate(speed: float) -> float
func lean_for_yaw_rate(k: KartState, track: KartTrackModel, yaw_rate: float) -> float
func assist_yaw_rate(k: KartState, track: KartTrackModel) -> float
func step(k: KartState, inp: KartInput, track: KartTrackModel, dt: float) -> void
func apply_boost(k: KartState, seconds: float) -> void
func apply_spinout(k: KartState) -> bool          # false when a shield absorbed it
static func resolve_contacts(karts: Array) -> Array   # [[a_id, b_id, strength], ...]
# Phase 2 hook: func _update_drift(k, inp, track, dt) -> float (extra yaw rate, + = left)

class_name KartRaceEvents extends RefCounted      # see "Signal map"

class_name KartRaceLogic extends RefCounted
enum Phase { GRID, COUNTDOWN, RACING, FINISHED }
const RIDER := 0
var events := KartRaceEvents.new(); var physics := KartPhysics.new()
var track: KartTrackModel; var karts: Array = []     # Array[KartState]; index == id; 0 is the rider
var laps := 3; var phase := Phase.GRID; var time := 0.0; var countdown := 0.0
func setup(track: KartTrackModel, racers: Array, laps: int) -> void   # racers: [{racer_id, weight, grid?}]
func start_countdown(seconds := 3.0) -> void
func step(dt: float, inputs: Array) -> void          # inputs: Array[KartInput], one per kart
func order() -> Array                               # kart ids by race position
func place_of(kart_id: int) -> int                   # 1-based
func progress(kart_id: int) -> float                 # lap * length + s
func race_length() -> float

class_name KartGrandPrix extends RefCounted
const POINTS := [15, 12, 10, 8, 6, 4, 2, 1]
const RACE_OVERHEAD_SEC := 25.0
var results: Array                                    # each race's order
func _init(duration_sec: float, track_ids: Array, racer_count := 8) -> void   # -1 = open-ended
static func estimate_lap_sec(track_length: float, ftp_w: float) -> float     # at 0.6 FTP, flat
func next_race(time_left_sec: float, est_lap_sec: float) -> Dictionary       # {track_id, reversed, laps, is_final, index}
func record(order: Array) -> void
func races_run() -> int
func standings() -> Array                            # [{kart_id, points, wins, best_place_last}] sorted
func champion() -> int
func place_of(kart_id: int) -> int

class_name KartView extends Node3D
const ANCHORS := ["exhaust_l","exhaust_r","wheel_fl","wheel_fr","wheel_rl","wheel_rr","driver_head","item_hold","shadow"]
func setup(racer: Dictionary) -> void                # a KartRoster entry
func sync(k: KartState, dt: float) -> void
func anchor(name: String) -> Node3D
# Phase 2 (racers) additions: var slide, boost_glow (fx), look_target: Vector3 + look_weight 0-1
# (a glance), func bone_pose(bone) -> Transform3D, static model_mesh(racer), head_mesh(racer).
# Models: racers/KartModels (one mesh a kart, rigged in the vertex shader), KartPortraits.

class_name KartBotDriver extends RefCounted
func _init(profile: Dictionary, ftp_w: float, rng_seed: int) -> void   # {power_pct, line_offset, drift_skill, item_skill, aggression}
func think(k: KartState, race: KartRaceLogic, dt: float) -> KartInput  # may return the same instance each call

class_name KartScoring extends RefCounted
signal awarded(points: float, reason: String)        # KartRace passes it to Game.award()
var rider_id := 0
func begin_race(race: KartRaceLogic) -> void
func step(dt: float, power_w: float) -> void
func stats(gp: KartGrandPrix) -> Dictionary          # the result's stats (below)

class_name KartRoster extends RefCounted
const RACERS := [{id, name, species, color, accent, weight}, ...]   # eight, kart id order = lineup()
static func ids() -> Array; static func names() -> Array
static func racer(racer_id: String) -> Dictionary
static func lineup(rider_racer_id: String, count := 8) -> Array      # the rider's pick first
# Phase 2 additions: entries also carry suit, eyes, helmet?, kart ("light"|"medium"|"heavy"),
# number, horn, tagline; static option_labels(), kart_class(r), horn_preset(id) -> SfxPreset.

class_name KartWorld extends Node3D
var tuning := {}                                     # dev switches: road, walls, ground, scenery
func build(track: KartTrackModel) -> void            # (re)build for a track or direction

class_name KartChaseCamera extends Camera3D
var mode := "chase"                                  # "chase" | "close"
func snap(k: KartState) -> void
func follow(k: KartState, dt: float) -> void

class_name KartStatus extends PanelContainer         # placeholder HUD widget
func set_state(place: int, racers: int, lap: int, laps: int, race_text: String) -> void
static func ordinal(n: int) -> String

class_name KartRaceBoard extends CanvasLayer         # placeholder boards
func show_board(title: String, rows: Array) -> void  # rows: [{name, detail}]
func hide_board() -> void
```

`KartRace.gd` (the `Game`): `signal race_began(race)`, `enum Flow { IDLE, COUNTDOWN, RACING,
RESULTS, PODIUM, DONE }`, and the members `race`, `gp`, `scoring`, `track`, `world`, `camera`,
`views`, `bots`, `lineup`, `flow`, `current`, `ftp_w`, `sim_time`, `test_input`. Builders:
`_build_world()`, `_build_camera()`, `_build_racers()`, `_build_items()`, `_build_hud()`,
`_build_audio()`, `_build_fx()`.

## Signal map

All on the race's `KartRaceEvents` (`race.events`). Kart ids index `race.karts`; places are
1-based.

| Signal | Emitted by | Listened to by (now / Phase 2) |
| --- | --- | --- |
| `race_started()` | KartRaceLogic, when the countdown ends | KartRace (flow → RACING, "GO!") / audio, camera |
| `lap_completed(kart_id, lap, lap_time)` | KartRaceLogic, the first time a kart completes `lap` | KartScoring (+30, best lap) / HUD lap banner, audio |
| `final_lap(kart_id)` | KartRaceLogic, when a kart starts its last lap | KartRace ("Final lap!") / HUD banner, music variation |
| `kart_finished(kart_id, place, time)` | KartRaceLogic (karts still running when the rider finishes get projected times) | / HUD, audio |
| `race_finished(order)` | KartRaceLogic, once, when the rider finishes | KartRace (GP record, results board), KartScoring (points × 20) |
| `position_changed(kart_id, old, new)` | KartRaceLogic, once per change of place | KartScoring (overtakes) / HUD pop, racer list |
| `drift_started(kart_id, dir)` | KartPhysics (Phase 2) | / fx, audio, camera |
| `drift_tier(kart_id, tier)` | KartPhysics (Phase 2) | / fx sparks, audio pings, drift meter |
| `boost_started(kart_id, kind, tier)` | KartPhysics, items (Phase 2); kind `drift`/`pad`/`item`/`start` | KartScoring (mini-turbo awards, boosts) / fx, audio, camera |
| `item_picked(kart_id, item)` | KartItemLogic (Phase 2) | / item button, audio |
| `item_used(kart_id, item)` | KartItemLogic (Phase 2) | / item views, audio |
| `kart_hit(kart_id, by_id, item)` | KartItemLogic (Phase 2) | KartScoring (+25 when by the rider) / fx, camera shake |
| `shield_blocked(kart_id)` | KartItemLogic (Phase 2) | / fx, audio |
| `wall_bump(kart_id, strength)` | KartPhysics, on hitting the barrier (not while grinding along it) | / camera shake, audio |
| `kart_bump(a_id, b_id, strength)` | KartRaceLogic, from `resolve_contacts` | / audio, fx |

## The race and the Grand Prix

- **Grid**: staggered slots, alternately left and right of the centre (±2.5 m), 6 m behind the
  line then 4.5 m apart. By default the bots fill it in id order (kart 1 on pole, the
  strongest) and the rider starts last.
- **Countdown**: inputs are ignored (A1's rocket start reads the input then). **Laps**: `lap`
  counts start-line crossings (0 on the grid, 1 on lap 1, laps + 1 at the finish), down on a
  backward wrap, so `progress = lap × length + s` is continuous. Lap events fire only for a lap
  never reached before.
- **Finish**: the race ends when the rider finishes; karts still running are placed by
  progress. Karts drive on through the results board.
- **GP**: `next_race(time_left, est_lap)` before each race. Timed: the final race is the one
  that starts with under 1.5 × (3 laps + 25 s) left, with `clamp(round(time_left / est_lap), 1,
  5)` laps. Open-ended: 3-lap races until the rider ends. The cup goes in order, reversed the
  second time round (a one-track cup alternates). The estimate uses the cup's average length at
  0.6 × FTP on the flat.
- **`request_finish`** (Kotlin's 1.5× hard stop, or End): the race in progress counts as it
  stands, and the game ends at once.

## Kotlin, options and the result

- `GameCatalog.KART_RACE` mirrors `info()`: `minutes` and `open`, 300-3600 s, no roles, camera
  on, effort in Just Rides, `timedEndMode = GAME` (`GameInfo.timed_end_mode = "game"`).
- `params`: `ftp_watts` (default 150), `bot_pcts` (seven ascending FTP shares: easy
  0.35→0.60, standard 0.45→0.75, hard 0.55→0.90; the bots' power wanders ±4% over time),
  `drift_resistance` (35 / 40 / 45).
- **Tracker mode `lean_stand`.** The head tracker reports `standing` in every camera mode
  (`HeadTrackingEngine` runs `StandingDetector` whatever the mode; 0.5 s to stand, 1.5 s to sit),
  so `InputBus.standing` works here; the simulator toggles it with Space. Calibration is the
  `lean_x` one.
- Options (`GameOptions`, per rider): `driver` (the roster), `assist` (off / low / high, default
  high), `camera` (chase / close), `auto_items` (off / on; race-systems wires it).
- Result `stats`: `position` (GP standing), `races`, `wins`, `podiums`, `best_lap` (s),
  `race_time` (s), `boosts`, `items_hit`, `avg_power` (W), `ghost_trace` (the rider's distance
  in metres every `ghost_interval` s, at most 3,600 points), plus the framework's
  `effort_avg` and `played_sec`. `won` is true when the rider is the GP champion.

## Tablet budget

- 3D in the SubViewport at 0.62; no MSAA. Road and terrain unshaded (hand-made light and fog);
  scenery lit per vertex, repeats through MultiMesh; blob shadows; at most 120 draw calls,
  ~250k triangles, ~3k triangles and 1-2 materials per kart and driver.
- The skeleton draws about 4 calls for the world and 5 per kart (8 karts: ~45 in 3D).
- Allocate nothing per tick in the hot path: `KartTrackModel` queries use scratch fields
  (`_locate`), bots return a reused `KartInput`, the input list is reused.
- HUD labels change only when their value changes.
- `DEV_TUNING` in `KartRace.gd` (off in every build): reads `user://kart_tuning.cfg`
  (`[render] scale=0.62 msaa=0`, `[world] road=false walls=false ground=false scenery=false`)
  and logs `OPENRIDE_GAMES kart_race perf game_ms=… process_ms=… fps=… draw_calls=… objects=…
  primitives=… karts=…` every 5 s.

### Measured on the tablet (Phase 1 skeleton)

2026-10-13, mock build (`installDebug`), a 20-minute standard Just Ride of Meadow Ring, 8 box
karts, `DEV_TUNING` on, 20 perf lines (100 s) of racing. **The camera was off**: nobody was on
the bike, so calibration found no face twice and ended unavailable (tracker 0). Re-measure with
a rider and the camera tracking.

| fps | game_ms (the whole `_on_frame`) | process_ms (frame time) | draw calls (3D + HUD) | primitives |
| --- | --- | --- | --- | --- |
| 59-61, avg 60.4 | 1.2-2.5, avg 2.1 | 16.1-18.5 (one 40 at the start) | 58-88, avg 74 | ~17.9k |

`game_ms` covers the fixed step (8 karts with bots: ~0.12 ms a tick on the Mac), the view sync
and the HUD. Keep the hot path allocation-free, and watch it as Phase 2 adds drift, items and
smarter bots.

## Tests

- `tests/unit/kart_track_model_test`, `kart_physics_test`, `kart_race_logic_test`,
  `kart_grand_prix_test`, `kart_race_scene_test` (GdUnit4). Shared tracks:
  `preload("res://tests/kart_fixtures.gd")` (circle, oval, meadow).
- `tests/sim_kart_check.gd`: a 5-minute local GP at 4× with the keys; must end on the finish
  line and show the summary (`PASS sim kart`).
- `tests/capture_kart.gd`: windowed screenshots per track, forward and reversed;
  `--play=SECONDS` for a recording.
- Run the full unit suite, `sim_demo_check` and `sim_kart_check` before every commit.

## GDScript gotchas met so far

- A method can't be called `_set`, `_input`, `_get` or other `Object`/`Node` virtuals (a test
  suite is a Node): `_input(...)` in a test failed to parse.
- Inside a class, calling a method named like a global function (`wrap`) resolves to the global:
  `KartTrackModel` keeps `wrap()` public but uses `_wrap()` inside.
- Type inference from a Variant is an error in this project (`var x := dict.key` fails): type it.
- `Array(typed_array)` returns the same array, not a copy: appending to it mutates the source.
- A `-s` script compiles before the autoloads exist: keep it untyped where it touches them.
