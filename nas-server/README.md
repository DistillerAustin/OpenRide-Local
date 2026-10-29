# OpenRide Local - Synology NAS library (starter v0.1)

This is the Synology server component for **OpenRide Local**. The Android fork
connects to its `/api/v1/classes` catalog and plays local classes while preserving
OpenRide ride-recording and YouTube support. The server itself is read-only and
does not store ride history; the Android app records rides on the bike.

## Exact NAS paths

- Your existing media path: `/volume1/Media/Videos/peloton`
- Recommended Docker project: `/volume1/docker/openride-local/nas-server`
- Media is mounted **read-only** at `/videos` in the container.
- Thumbnail cache is a separate Docker volume, not mixed into your video folders.
- Default **host** port is `8766` because Speedtest Tracker uses `8765` on SoapyEight. The container listens on `8765`.

Put cycling videos in any number of subdirectories, for example:

```text
/volume1/Media/Videos/peloton/
  Peloton-style/
    20 Minute Rides/
      20 Minute Low Impact Ride.mp4
    45 Minute Rides/
      Endurance Ride.mkv
  DVDs/
    Spinning Workout Collection/
      Disc 1 - Ride.mp4
```

The server picks up new files and directory changes on the next refresh.
Supported extensions: `.mp4`, `.m4v`, `.mkv`, `.mov`, `.webm`, `.avi`, `.ts`.
**Compatibility with the Peloton Android video decoder is format-dependent.**
H.264 video + AAC audio in `.mp4` is the safest starting point. This server
intentionally does **not** transcode video; that avoids unnecessary NAS CPU load.

## Deploy using SSH / terminal on Synology

1. Create `/volume1/docker/openride-local/nas-server` if needed.
2. Copy `compose.yaml`, `Dockerfile`, and `server.py` into that folder.
3. From an SSH terminal on the NAS:

   ```sh
   cd /volume1/docker/openride-local/nas-server
   sudo docker compose up -d --build
   ```

   On older Docker versions, `docker-compose up -d --build` may be needed.
   Alternatively, create a **Project** in Synology Container Manager and point
   it to this folder, with the supplied Compose configuration.

4. Open `http://192.168.1.73:8766/` in Firefox on your computer or phone. This
   is a browser preview to confirm the server sees your class folders.
5. The machine-readable catalog is at
   `http://192.168.1.73:8766/api/v1/classes`.
6. To inspect startup / permission problems:

   ```sh
   sudo docker logs --tail 100 openride-local-nas
   ```

The `Dockerfile` runs as a non-root user. It must be able to read your Synology
media share. If the catalog is empty despite files existing, inspect the
Synology shared-folder and directory ACLs. Do not blindly change the permissions
of your whole media library. The path is case sensitive.

## Metadata and posters (optional)

Folder names become collections. Filenames become class titles, with underscores
made readable. There is no need to manually enter metadata to begin.

For a file named `30 Minute Ride.mp4`, you can optionally create
`30 Minute Ride.mp4.json` beside it (or `30 Minute Ride.json`). Example
at `examples/video.mp4.json`.

Optional title, instructor, difficulty, tags, description, duration_seconds
are displayed in the NAS catalog and are exposed to the Android app API.

For custom artwork, place `30 Minute Ride.jpg` next to the video, or put
`cover.jpg` / `poster.jpg` in the same directory. Otherwise the server creates
and caches a JPEG thumbnail using FFmpeg, on the first thumbnail request.
The server uses FFprobe to detect duration if the sidecar has none.

## API contract for the OpenRide fork

- `GET /healthz` - server health and mount visibility
- `GET /api/v1/classes` - all local videos, recursive subfolder catalog
- `GET /api/v1/groups` - folder groups and class counts
- `GET /api/v1/classes/<id>/video` - direct file streaming with byte-range seek
- `HEAD /api/v1/classes/<id>/video` - video metadata for native player
- `GET /api/v1/classes/<id>/thumbnail` - artwork or generated thumbnail

An item includes `source: "local"`, stable-in-place video ID, title,
collection, category, duration_seconds, `playback_url`, `thumbnail_url`, etc.
The URLs are relative to the configured NAS base URL. No user-supplied file path
is accepted by the stream endpoint.

The fork integrates the catalog into the Classes tab as `NAS / <collection>` rows,
without removing YouTube content. Local classes start the original OpenRide ride
recorder, share its live metrics and save in its existing Room database.

## Network/security

This is a private **LAN-only** proof-of-concept service and has **no login**.
Do **not** open/forward port `8765` on your router, publish it via Synology
reverse proxy, or expose it directly on the public internet. If remote access
is desired later, use a VPN and introduce proper auth. Keep `/videos` mounted
read-only. Treat exported ride history as personal information; v0.1 has no
ride-upload or ride-backup endpoint.

## Verify locally (on a development computer)

The unit tests use only Python's standard library:

```sh
cd nas-server
python3 -m unittest discover -s tests -v
```

The tests cover nested directories, sidecar metadata, live folder refresh,
video streaming, HTTP 206 byte ranges, HEAD and invalid request handling.
