# OpenRide Local — Synology cycling classes

This fork **adds** a read-only NAS class catalog and native class playback to OpenRide.
It does not remove YouTube sources, games, ride history, or original sensor logic.

## Your NAS settings

| Item | Value |
| --- | --- |
| NAS | SoapyEight — `192.168.1.73` |
| Videos on NAS | `/volume1/Media/Videos/peloton` |
| Docker host port | `8766` (`8765` is taken by Speedtest Tracker) |
| Library | `http://192.168.1.73:8766/` |
| Catalog API | `http://192.168.1.73:8766/api/v1/classes` |

The `nas-server/` directory is a copy of the lightweight server you deployed. It now
ships with a Compose mapping of `8766:8765`. The service still listens on 8765
**inside** the container.

## How it works

1. In **Classes**, OpenRide fetches its usual YouTube channels **and** the optional NAS
   endpoint. Each NAS subfolder becomes a shelf named `NAS / <folder>`.
2. Tap a NAS class. OpenRide records a session using the **same** ride manager,
   sensor feed, metrics overlay, end-ride summary, and history database as YouTube classes.
3. A native Android `VideoView` streams and seeks the video directly over HTTP. No
   Jellyfin/Plex required. The player attempts to pause/resume with the ride and saves
   the workout on end or video completion.
4. NAS class history is associated with a stable ID `local:<24hex>`. This keeps it
   distinct from YouTube IDs, and the existing "Taken" / "Hide completed" filters work.
5. Tap **NAS settings** in the Classes filter bar to change the server URL. Blank turns
   off NAS classes only. If NAS is offline, YouTube keeps working and an error banner
   appears; previously loaded NAS class rows remain visible for the current session.

Server data is not copied to the bike. The media root stays read-only. No separate
user account or subscription is required for NAS classes.

## Android build and installation

The fork's **debugReal** build connects to live Peloton sensor services; plain `debug`
uses mocked bike metrics. This fork changes `debugReal`'s package ID to
`dev.digitalducktape.openride.local` so it can coexist with upstream's
`dev.digitalducktape.openride.real`. The updater checks this fork's releases,
not upstream releases, so installing an upstream APK isn't offered accidentally.

Build on a development PC with Android SDK 34, JDK 17, Gradle wrapper access and
Godot editor matching the version in `gradle/libs.versions.toml` (currently
`4.7.2.stable`) for the mini-games pack:

```sh
export GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64
./gradlew :app:assembleDebugReal
```

Install the resulting `app/build/outputs/apk/debugReal/*.apk` through OpenPelo,
or with `adb install -r <apk>` after connecting the bike. Start the app by tapping
its launcher icon or use:

```sh
adb shell am start -n dev.digitalducktape.openride.local/dev.digitalducktape.openride.MainActivity
```

**Signing/data caveat:** A new package starts with its own profile/ride database.
OpenRide's backup-and-restore tools can migrate data from an existing installation.
Do **not** uninstall an existing OpenRide before making an external backup. Use a
consistent signing key for future updates; GitHub Actions' auto-generated debug
keystore is not stable across runs, so a test APK built in separate workflow runs
may not be installable with `adb install -r` without first configuring repeatable
signing. Uninstalling an app removes its local data.

### Video formats

MP4/H.264/AAC is the most reliable choice on older Peloton Android tablets.
Other video files such as MKV, AVI, HEVC or DVD MPEG-2 may show in the catalog
but may not play in the built-in Android decoder. This initial integration has
no transcoder. If a file fails, try remuxing/re-encoding just that file, without
replacing your original on NAS. Confirm the tablet Android version before relying
on the fork as your only exercise app.

### Android network security

The fork enables Android cleartext HTTP so it can reach a configurable local
NAS address without HTTPS. **The Docker service has no authentication** and should
be restricted to the trusted LAN: don't forward port 8766 or publish it via a
public reverse proxy. For off-LAN access, add proper TLS/auth and use a VPN.

## Development and upstream maintenance

Keep the fork's `main` synchronized with `digitalducktape/OpenRide` and apply this
patch on `feature/local-library`. The application integration is deliberately
isolated to `LocalLibraryRepository`, `LocalVideoIds`, a few Classes UI and navigation
wires, and a native player branch in `VideoRideScreen`.

No Room schema migration is needed: `Ride.videoId` is already a string. Existing
YouTube ride IDs and history stay unchanged.

Future, not yet implemented: automatic **ride-data backup to the NAS**, an
in-app server health checker, offline downloads, transcoding and more detailed
catalog metadata (instructor search, difficulty). The original app's backup
features still work separately.

### Checks

NAS server tests (passed in preparation):

```sh
python3 -m unittest discover -s nas-server/tests -v
```

Android unit tests, on a PC with Android SDK/Gradle dependencies:

```sh
./gradlew :app:testDebugUnitTest
```

A GitHub Actions test-APK workflow is included at
`.github/workflows/openride-local-apk.yml`. It runs when you push the
`feature/local-library` branch, and can also be started manually once
available on the fork's default branch. Its build has not been verified here.
The workflow's temporary signing key is **not** suitable for repeatable
upgrades without configuring durable signing.

The full Android build has not been run in the current authoring environment:
Gradle distribution, Android SDK and pinned Godot editor are unavailable there.
The Kotlin change is source-level and needs a real compiler/build pass followed
by on-bike validation before it's considered release-ready.
