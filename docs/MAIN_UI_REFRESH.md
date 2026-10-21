# Main UI refresh

The plan for rebuilding OpenRide's main Compose UI: everything except the mini-games in `games/`
(Godot), which keep their own look. Branch `main-ui-refresh`, cut from `games-hub` at 710296f.

Guidance came from the third-party Android skill
[dpconde/claude-android-skill](https://github.com/dpconde/claude-android-skill) (MIT, © 2025
David Perez), which condenses Google's architecture guide and the Now in Android sample. It was
read as reference, not followed blindly; section 2 says what was taken and what was not. No code
was copied from it.

## 0. The bike, in numbers

| Fact | Value | Where it comes from |
| --- | --- | --- |
| Panel | 1920 × 1080 px, landscape | Peloton Gen 2 tablet |
| Density | 1.5 (240 dpi) | measured from `docs/screenshots` (a 56 dp button is 84 px) |
| App window | **1920 × 1008 px = 1280 × 672 dp** | issue #57: Android 11 keeps the hidden nav bar's 72 px (48 dp) strip out of every window, and the tablet refuses every workaround |
| System bars | hidden, immersive sticky | `MainActivity.hideSystemBars()` |
| GPU / RAM | PowerVR GX6250, ~2 GB | shared with Godot, CameraX and MediaPipe when games run |
| Viewing distance | about 1 m, while pedalling | the rider |

Rules that follow from these:

1. **Design for 1280 × 672 dp.** Never assume 720 dp of height. Nothing important goes in the
   bottom 48 dp of the *panel*, and the window already excludes it, so layouts simply fill the
   window and keep a bottom margin of at least `Spacing.lg`.
2. **Touch targets.** 64 dp minimum (96 px, about 10 mm) for anything tapped while riding, 80 dp
   for a screen's primary action. Material's 48 dp is a desk minimum, not a bike one.
3. **Text at 1 m.** 18 sp minimum for anything read while riding; 16 sp minimum anywhere; tracked
   caps labels no smaller than 14 sp; live metrics 48 sp and up.
4. **Cheap pixels.** Flat tonal surfaces, no elevation shadows, no blur, no full-screen gradients
   that redraw every frame, no infinite animations outside a ride, system font only (no bundled
   font files, no `material-icons-extended`), images through Coil at their display size.

## 1. Inventory: every screen and flow today

Navigation is two `NavHost`s with string routes (`ui/navigation/Destinations.kt`). The outer one
owns full-screen flows; `Main` hosts the tabbed section with an inner `NavHost` and a Material
`NavigationBar` along the bottom (`ui/main/MainScaffold.kt`). DI is manual: `AppContainer` plus a
`viewModelFactory { }` helper. Screens take the ViewModel itself and use `collectAsState`.

| # | Screen / flow | File(s) | What it does, all of which must survive |
| --- | --- | --- | --- |
| 1 | **Rider select** (start destination) | `ui/profile/ProfileSelectScreen.kt`, `ProfileSelectViewModel` | Wordmark, a row of 180 dp avatars (photo or emoji on colour), tap to pick → Main; "Add rider" → Profile create |
| 2 | **Profile create / edit** | `ui/profile/ProfileEditorScreen.kt`, `ProfileEditorViewModel`, `AvatarOptions.kt` | Name, weight (lb), FTP; avatar colour/emoji pickers; camera photo with the CAMERA-permission dance; Save/Cancel. Create → Main; edit → back. Also the target of the games' FTP nudge (`VisitDestination.EditProfile`) |
| 3 | **Main shell** | `ui/main/MainScaffold.kt` | Five tabs: Home, Classes, Games (🎮), History, Profile; state saved per tab |
| 4 | **Home** tab | `ui/home/HomeScreen.kt`, `HomeViewModel`, `GoalDialog.kt` | Update banner (Update / Dismiss); greeting + avatar chip → Profile tab; Quick Start hero → `RideSessionManager.start` → In-ride; goal summary + goal dialog (none / minutes / kJ); Games BETA card → `launchGames` |
| 5 | **Classes** tab | `ui/classes/*` | Per-creator shelves or a filtered grid; category chips, sort and length dropdowns, "Hide completed"; loading / empty / refresh-failed states; Taken / Unavailable / duration badges; tap a class → Video ride; tap a creator → Creator page |
| 6 | **Creator page** | `ui/creator/*` | LATEST shelf plus one shelf per playlist; back |
| 7 | **Games** tab | `ui/games/GamesLauncherScreen.kt` | One "Enter Games" launcher (from games-hub); "saving your last games ride" notice. The hub itself is Godot and out of scope |
| 8 | **History** tab | `ui/history/*` | Lifetime stats band, records band, month calendar with ride dots, ride list (game badge for game rides), Export CSV of all rides, tap → Ride summary |
| 9 | **Profile** tab (settings) | `ui/profile/ProfileTabScreen.kt`, `SettingsShortcuts.kt` | Avatar, name, weight, FTP; Edit profile; Switch rider (confirm); Wi-Fi and device settings; HR strap; App updates; Content sources; GPX route load/change/clear; Back up / Restore (confirm, then back to rider select); auto-backup path note |
| 10 | **HR strap pairing** | `ui/profile/HrPairingScreen.kt`, `HrPairingViewModel` | BLE permission flow, scan list, pick, forget, open settings |
| 11 | **App updates** | `ui/update/*` | Check → Download → Install, each an explicit tap |
| 12 | **Content sources** | `ui/sources/*` | Look up a creator or playlist, classify Workout / Scenic, hide built-ins |
| 13 | **In-ride** (Just Ride) | `ui/ride/InRideScreen.kt`, `RideMetricsBar.kt`, `InRideViewModel` | Timer, goal hairline + label, zone-coloured output hero + zone chip, sensor-failure and auto-pause banners, GPX route progress, Pause/Resume, End (confirm) → Ride summary; keep-screen-on lives in `MainActivity` |
| 14 | **The in-ride metrics bar** | `ui/ride/RideMetricsBar.kt` | Primary row: cadence / output / resistance with AVG (trend arrow) and BEST flanks; secondary strip: speed, distance, total kJ, heart rate when paired; solid or translucent over video; "--" when sensors are down, never a fake zero |
| 15 | **Video ride** | `ui/ride/VideoRideScreen.kt`, `YouTubeEmbed.kt` | YouTube embed in a WebView, top scrim with timer and controls, metrics bar overlay that can be tucked away (ToS: YouTube's controls stay reachable), video pauses with the ride, ends the ride at video end |
| 16 | **Ride summary** (post-ride and history detail) | `ui/ride/RideSummaryScreen.kt`, `MetricGraph.kt`, `RideSummaryViewModel` | Metric tabs, graph, TOTAL/AVG/MAX band, game results list, Export TCX / CSV, FTP suggestion ("Update my FTP"), Done |
| 17 | **Cross-cutting** | `MainActivity`, `OpenRideNavHost` | Kiosk mode re-hide on inset changes; games visit end on resume; `VisitNavigator` routes a finished games visit to its summary or to Edit profile |

Today's design language: near-black background, `#E8442D` red-orange accent, white text, Material
3 defaults for most controls, sizes chosen per screen (17 raw `fontSize` literals, 22 default
`OutlinedButton`s at 40 dp tall, tracked-caps labels at 11–13 sp).

## 2. What the skill recommends, and what we take

| Recommendation | Verdict | Why |
| --- | --- | --- |
| Three layers (UI → optional domain → data), unidirectional data flow, `Flow` everywhere | **Already true; keep** | Repositories expose `Flow`s; screens only render state and send events |
| Route / Screen split: a `…Route` composable owns the ViewModel, a stateless `…Screen` takes `uiState` and lambdas | **Adopt, screen by screen** | Makes every screen previewable and testable without `AppContainer` |
| One `UiState` per screen (sealed interface or data class) built with `stateIn(WhileSubscribed(5_000))` | **Adopt** | Replaces several `collectAsState(initial = …)` calls per screen with one value; `WhileSubscribed` stops upstream work when a screen is off-screen, which helps the 2 GB tablet |
| `collectAsStateWithLifecycle` | **Adopt** | `lifecycle-runtime-compose` is already a dependency; stops collection while the Godot activity is in front |
| `core:designsystem`: theme, tokens, icons object, stateless prefixed components | **Adopt as a package now** (`ui/designsystem`), module later if wanted | This is the heart of the refresh |
| Previews with shared annotations | **Adopt** | One `@BikePreview` at 1280 × 672 dp, density 1.5; `ui-tooling-preview` is already on the classpath |
| Multi-module `feature:*:api/impl` + `core:*` + `build-logic` convention plugins | **Reject for now** | One app, one maintainer, ~19 k lines; the skill itself warns against over-modularising. The app module carries the Godot export task and AIDL. A split costs build time and disk we don't have tonight. Package boundaries mirror the modules so a later split is mechanical |
| Hilt | **Reject** | `AppContainer` is small, explicit and shared with `GameHostActivity`. Hilt adds an annotation processor, generated code and APK size for no rider-visible gain |
| Dynamic colour, light/dark themes | **Reject** | Android 11 has no dynamic colour; the bike is always dark |
| Type-safe navigation (`@Serializable` routes, Navigation 2.8) | **Adopt late (phase 8)** | `navigation-compose` 2.8.2 and the serialization plugin are already here, but the string routes work and `VisitNavigator` depends on them; low value per risk until the screens settle |
| Adaptive layout: navigation rail on wide screens | **Adopt** | Landscape 672 dp is the scarce axis; the bottom bar costs 81 dp of it. A left rail costs width, which we have |
| Test doubles, no mocking library | **Already true; keep** | `FakeBikeDataSource`, in-memory Room under Robolectric |
| Roborazzi screenshot tests | **Defer** | Worth it once the design settles, if disk allows; not tonight |
| Offline-first sync with WorkManager | **Not applicable** | The only remote data is the classes feed, already cached |
| `scripts/generate_feature.py` | **Not run** | It only generates files, but they assume Hilt and the module layout we rejected |

## 3. Target design

**Name and voice.** "OpenRide" in a plain tracked wordmark, no logo marks borrowed from anyone.
No other brand's names, colours used as trade dress, icons, sounds or imagery.

**Palette ("Night Road").** Blue-black instead of pure black, and a lime "signal" accent instead
of red, so the app no longer reads as red-on-black. All pairs meet WCAG AA (≥ 4.5 : 1) for body
text, checked by a unit test.

| Token | Hex | Use |
| --- | --- | --- |
| `Background` | `#0F1216` | screen |
| `Surface` | `#181C22` | cards, rail |
| `SurfaceRaised` | `#222831` | selected rail item, chips, inputs |
| `Outline` | `#343C48` | hairlines, secondary-button border |
| `OnBackground` | `#F2F5F8` | text |
| `OnSurfaceMuted` | `#A7B0BC` | secondary text |
| `Accent` | `#C6F24E` | primary actions, selected state; dark text on it |
| `OnAccent` | `#0F1216` | text on accent |
| `Info` | `#6CC6FF` | links, informational banners |
| `Warning` | `#FFB648` | BETA badge, auto-pause, saving |
| `Danger` | `#FF6A5C` | End ride, destructive confirms |
| `Success` | `#4CD68E` | done, paired |

Power-zone colours stay as they are: a standard training-zone ramp, not a brand palette.

**Type.** The system sans (Roboto on the tablet). A bike scale on top of Material's: display
numerals 56–112 sp, `title` 28 sp, `body` 20 sp, `label` 18 sp, tracked-caps `eyebrow` 14 sp.

**Shape and space.** Corner radii 12 / 20 / 28 dp. Spacing on a 4 dp grid with named steps
(`xs 4`, `sm 8`, `md 16`, `lg 24`, `xl 32`, `xxl 48`). Screen gutters 32 dp.

**Shell.** A 120 dp left navigation rail replaces the bottom bar: five 104 dp-tall items, each
with an icon and an 18 sp label, the selected one on `SurfaceRaised` with an accent bar. Content
gets the full 672 dp of height.

**Components** (`ui/designsystem/component`): `OrPrimaryButton` (80 dp), `OrSecondaryButton`
(64 dp, outlined), `OrDangerButton`, `OrTile` (tappable card), `OrEyebrow`, `OrBetaBadge`,
`OrBanner` (info / warning), `OrNavRail`, `OrSettingsRow` (64 dp+ rows with title, value and
chevron), `OrStat` (label + big number + unit). Every component is stateless and previewed.

**Screens.**
- *Rider select*: wordmark top-left, avatars centred in a row (they already work well), an
  `OrSecondaryButton` "Add rider".
- *Home*: two columns. Left, the Just Ride tile: a full-width 80 dp **Start ride** and the goal
  as a large tappable row. Right, the Games BETA tile. The update banner spans the top.
- *Profile → Settings*: grouped `OrSettingsRow` lists (Rider, Ride, Device, Data) in two columns
  instead of one long centred stack of small buttons.
- *History, Classes, Creator, Sources, Summary, Updates, HR*: same structure, re-skinned with the
  components and the bike type scale.
- *In-ride and the metrics bar*: same layout (it tested well on the bike); the labels go from
  11–12 sp to 14 sp, Pause / End become 64 dp buttons, End uses `Danger`.

## 4. Phased migration

Every phase is a few small commits; each commit compiles, passes all unit tests, and leaves the
app usable. No Room schema, migration, BLE or sensor code changes in any phase.

| Phase | Scope | Risk | Status |
| --- | --- | --- | --- |
| 0 | This document | none | **done** |
| 1 | Design system: tokens (colour, type, spacing, sizes, shapes), contrast and touch-size tests, `OpenRideTheme` on the new palette, `OrIcons`, core components, `@BikePreview` | low: theme colours change app-wide, layouts don't | **done** |
| 2 | Shell: `TopLevelDestination` model + `OrNavRail` replacing the bottom bar | low–medium: every tab's width shrinks by 120 dp | **done** |
| 3 | Home: `HomeUiState`, `HomeRoute`/`HomeScreen` split, `collectAsStateWithLifecycle`, new two-column layout on the components | low | **done** |
| 4 | Rider select and Games launcher on the components; Route/Screen split for rider select | low | **done** |
| 5 | Profile tab as grouped settings; Profile editor, HR pairing, App updates, Content sources | medium (many actions to keep) | Profile tab **done**; the other four next |
| 6 | History, Classes, Creator, Ride summary | medium | |
| 7 | In-ride, metrics bar, video ride: sizes and buttons only, tested on the bike before merge | **high** (the core screen) | |
| 8 | Type-safe navigation routes; optionally `:core:designsystem` as a module; Roborazzi screenshots | medium | |

**Parity checklist per screen** (from section 1): every action, dialog, banner, empty / loading /
error state and navigation edge above still exists after the screen moves.

**How each phase is verified:** `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
(baseline 789 tests); new logic gets unit tests (UiState mapping, tokens, destinations). Visual
checks are Compose previews on the dev machine and, for phases 2, 3 and 7, a ride on the bike.

## 5. Implementation notes

Decisions taken while building phases 1–5a, for whoever picks up phase 5b:

- **Two type systems for a while.** `MaterialTheme.typography` is still Material's default, so
  screens not yet rebuilt keep the layouts they were tuned for. Rebuilt screens use `OrType`.
  Switch the Material scale to the bike scale only after phase 7, when nothing depends on it.
- **`OpenRideColors` is a facade.** Its names now point at `OrColors`, which re-skinned every
  screen at once. Rebuilt code uses `OrColors`; delete the facade when nothing refers to it.
- **The accent is the rider's avatar colour** (`riderAccent`), End ride included (rider,
  2026-10-21). `Danger` is kept for destructive confirms like Restore; it is a fill with white
  text only (red text fails contrast on the dark ground), so Material's `error` colour, used
  for error *text*, stays amber.
- **Colours checked by test.** `OrColorPairs` lists every foreground/background pair;
  `OrColorsTest` fails if one drops below WCAG AA. Add new pairs there.
- **Home fills the window.** The two tiles take a minimum height worked out from the 672 dp
  window, so Start ride sits low near the rider's hand; the column still scrolls if a large font
  scale needs it.
- **Rider select waits for the database** (`null` while loading) so "Add your first rider" never
  flashes past a rider who exists.
- **Not touched:** the games host's XML window colours (`res/values/themes.xml`) and its native
  loading screen belong to the games and keep the old near-black; the Godot hub is out of scope.
  Room, BLE and sensor code are untouched.
- **Compose UI tests** need `ui-test-junit4` and `ui-test-manifest`; they were left out tonight
  to keep the build small. New logic was pulled into pure functions (`HomeUiState`,
  `ProfileTabLabels`, `TopLevelDestination`, the token and contrast checks) and tested there.

## 6. Open questions for the rider

1. **Accent colour.** Lime "signal" (`#C6F24E`) moves us clearly away from red-on-black. Happy
   with it, or prefer another (for example a cyan)? It is one token in `OrColors`.
2. **Navigation rail.** A left rail frees 81 dp of height on every tab. Keep it, or go back to
   a (taller, 96 dp) bottom bar?
3. **Density.** 1.5 is inferred from the README screenshots. Worth confirming with
   `adb shell wm density` next time the tablet is free.
4. **In-ride type sizes.** Bigger labels mean slightly less room for the AVG / BEST flanks.
   Try it on the bike before phase 7 lands?
