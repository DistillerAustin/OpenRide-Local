"""The game music renderer (#55): songs that play at any tempo. For Cadence Karaoke, whose music
follows the rider's cadence, a song can't be one rendered file. Instead it ships as a **sample
bank** (every note it plays, rendered here once, at the length the slowest tempo needs, in one
OGG) and a **score** (per track, each note's beat, sample and gate). At runtime
`res://audio/SongSequencer.gd` lays the notes out at the requested tempo by slicing the decoded
bank (native copies, a short fade where a note is cut), one monophonic track at a time, and
mixes each stem's tracks natively (AudioStreamSynchronized through mix_audio). Nothing is
time-stretched: every note is played as rendered, so the instruments sound the same at every
tempo.

Track rules (the runtime's, mirrored by `preview` here):
- A track plays one note at a time. A note plays from its onset until the next note on its
  track, its gate plus the track's release (for gated notes), or its sample's end, whichever is
  first; when cut short it fades out over the release. Drum hits on one track at the same beat
  are merged into one sample here.
- Every track is the loop's length exactly, so the stems stay in sync and loop seamlessly.

Original code for this repo (Apache-2.0).
"""
import os
import zlib

import numpy as np
import soundfile as sf

import dsp
import instruments as ins
from dsp import SR

DRUMS = {"kick", "snare", "clap", "hat", "shaker", "tamb", "crash", "ride", "tom", "ghost", "rim", "snap", "sleigh"}


class Score:
    def __init__(self, bars, tempo_min, tempo_max):
        self.bars = bars
        self.tempo_min = tempo_min
        self.tempo_max = tempo_max
        self.spb_slow = 60.0 / tempo_min
        self.events = []  # (track, beat, key)
        self.tracks = {}  # name -> {stem, release, target}

    def track(self, name, stem, release=0.03, target=-30.0):
        self.tracks[name] = {"stem": stem, "release": release, "target": target}

    def drum(self, track, beat, kind, vel, pan=0.0, **kw):
        self.events.append((track, float(beat), ("drum", kind, round(vel, 2), round(pan, 2), tuple(sorted(kw.items())))))

    def note(self, track, beat, inst, pitch, gate, vel=1.0, pan=0.0):
        p = tuple(pitch) if isinstance(pitch, (list, tuple)) else pitch
        self.events.append((track, float(beat), ("note", inst, p, round(gate, 3), round(vel, 2), round(pan, 2))))


def _render_key(key, spb_slow):
    rng = np.random.default_rng(zlib.crc32(repr(key).encode()))
    if key[0] == "combo":
        parts = [_render_key(k, spb_slow) for k in key[1]]
        n = max(p.shape[1] for p in parts)
        out = np.zeros((2, n))
        for p in parts:
            out[:, :p.shape[1]] += p
        return out
    if key[0] == "drum":
        _, kind, vel, pan, kw = key
        x = getattr(ins, kind)(vel, rng, **dict(kw))
        return dsp.pan(x, pan)
    _, inst, pitch, gate, vel, pan = key
    sec = gate * spb_slow
    from arrange import LEADS
    if inst == "pad":
        x = ins.pad(list(pitch), sec, vel, rng)
    elif inst == "epiano":
        x = ins.epiano(list(pitch), sec, vel, rng)
    elif inst == "slap":
        x = ins.slap_bass(pitch, sec, vel, rng)
    elif inst == "slap_pop":
        x = ins.slap_bass(pitch, sec, vel, rng, "pop")
    elif inst == "synth_bass":
        x = ins.synth_bass(pitch, sec, vel, rng)
    else:
        x = LEADS[inst](pitch, sec, vel, rng)
    if x.ndim == 1:
        x = dsp.pan(x, pan)
    return x


def build(score):
    """Merges simultaneous drum hits, renders every distinct sample once, and returns
    (bank audio, [(offset, length)], {track: [(beat, sample, gate)]})."""
    # One sample per note (instrument, pitch, velocity, pan), rendered at the longest gate it's
    # played with: shorter gates are the runtime's cut and fade.
    longest = {}
    for track, beat, key in score.events:
        if key[0] == "note":
            base = key[:3] + key[4:]
            longest[base] = max(longest.get(base, 0.0), key[3])
    by = {}
    for track, beat, key in score.events:
        by.setdefault((track, beat), []).append(key)
    keys, index, tracks = [], {}, {name: [] for name in score.tracks}
    for (track, beat), ks in sorted(by.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        gate = -1.0
        if len(ks) > 1:
            assert all(k[0] == "drum" for k in ks), f"two notes at beat {beat} on track {track}"
            key = ("combo", tuple(sorted(ks)))
        else:
            key = ks[0]
            if key[0] == "note":
                gate = key[3]
                base = key[:3] + key[4:]
                key = key[:3] + (longest[base],) + key[4:]
        if key not in index:
            index[key] = len(keys)
            keys.append(key)
        tracks[track].append((beat, index[key], gate))
    pad = 256
    audio, spans, at = [], [], 0
    for key in keys:
        x = _render_key(key, score.spb_slow)
        x = dsp.fade_out(x.copy(), 3) if x.ndim == 1 else np.stack([dsp.fade_out(c.copy(), 3) for c in x])
        audio.append(x)
        audio.append(np.zeros((2, pad)))
        spans.append((at, x.shape[1]))
        at += x.shape[1] + pad
    return np.concatenate(audio, axis=1), spans, tracks


def track_audio(bank, spans, events, release, bpm, total):
    """One track at a tempo, as the runtime builds it."""
    spb = 60.0 / bpm
    out = np.zeros((2, total))
    rel = int(release * SR)
    for i, (beat, s, gate) in enumerate(events):
        onset = int(round(beat * spb * SR))
        nxt = int(round(events[i + 1][0] * spb * SR)) if i + 1 < len(events) else total
        off, length = spans[s]
        n = min(length, nxt - onset)
        fade = 0
        if gate >= 0 and int(gate * spb * SR) + rel < n:
            n = int(gate * spb * SR) + rel
            fade = rel
        elif n < length:
            fade = min(rel, n)
        seg = bank[:, off:off + n].copy()
        if fade:
            seg[:, n - fade:] *= np.linspace(1, 0, fade)
        out[:, onset:onset + n] = seg
    return out


def music_tempo(score, rpm):
    bpm = float(rpm)
    if bpm < score.tempo_min:
        bpm *= 2
    if bpm > score.tempo_max:
        bpm /= 2
    return bpm


def preview(score, bank, spans, tracks, gains, bpm):
    """The stems at a tempo, as the runtime mixes them: {stem: stereo audio}."""
    total = int(round(score.bars * 4 * 60.0 / bpm * SR))
    stems = {}
    for name, t in score.tracks.items():
        x = track_audio(bank, spans, tracks[name], t["release"], bpm, total) * 10 ** (gains.get(name, 0.0) / 20)
        stems[t["stem"]] = stems.get(t["stem"], 0) + x
    return stems


def balance(score, bank, spans, tracks, lufs, ref_bpm=100.0):
    """Per-track gains (dB): each track to its target RMS at the reference tempo, then the whole
    to `lufs`, with the peak kept under -1.5 dBFS at every tempo the song plays at."""
    gains = {}
    total = int(round(score.bars * 4 * 60.0 / ref_bpm * SR))
    for name, t in score.tracks.items():
        x = track_audio(bank, spans, tracks[name], t["release"], ref_bpm, total)
        rms = 10 * np.log10(np.mean(x ** 2) + 1e-12)
        gains[name] = float(np.clip(t["target"] - rms, -30, 30)) if rms > -100 else 0.0
    full = sum(preview(score, bank, spans, tracks, gains, ref_bpm).values())
    shift = lufs - dsp.lufs(full)
    worst = -99.0
    for bpm in (score.tempo_min, (score.tempo_min + score.tempo_max) / 2, score.tempo_max):
        full = sum(preview(score, bank, spans, tracks, gains, bpm).values())
        worst = max(worst, 20 * np.log10(np.abs(full).max() + 1e-9) + shift)
    shift -= max(0.0, worst + 1.5)
    return {k: v + shift for k, v in gains.items()}


def write(score, name, bank, spans, tracks, gains, music_dir, res_dir, index_path, title, key_pc, wav_dir=None):
    path = os.path.join(music_dir, name + "_bank.ogg")
    # libvorbis can crash on long runs of exact digital silence: a whisper of noise (-110 dBFS).
    data = (bank + np.random.default_rng(0).uniform(-3e-6, 3e-6, bank.shape)).T.astype(np.float32)
    with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=0.9) as f:
        for i in range(0, len(data), SR * 4):
            f.write(data[i:i + SR * 4])
    lines = ["extends RefCounted",
             f"## {title}: Cadence Karaoke's song (#55), a sample bank and a score that",
             "## res://audio/SongSequencer.gd plays at the rider's cadence. Written by",
             "## games/tools/music/render_music.py (songs/cadence_karaoke.py, sequencer.py); don't edit by hand.",
             "",
             f"const TITLE := \"{title}\"",
             f"const KEY := {key_pc}",
             "const SONG := {",
             f"\t\"bank\": \"{res_dir}/{name}_bank.ogg\",",
             f"\t\"sr\": {SR},",
             f"\t\"bank_frames\": {bank.shape[1]},",
             f"\t\"bars\": {score.bars},",
             f"\t\"tempo_min\": {float(score.tempo_min)},",
             f"\t\"tempo_max\": {float(score.tempo_max)},",
             "\t## [offset, frames] per sample, in the bank",
             "\t\"samples\": [" + ", ".join(f"[{o}, {n}]" for o, n in spans) + "],",
             "\t## per track: its stem, gain (dB), release (s) and notes as flat [beat, sample, gate beats (-1: none), ...]",
             "\t\"tracks\": ["]
    for tname, t in score.tracks.items():
        flat = ", ".join(f"{b:g}, {s}, {g:g}" for b, s, g in tracks[tname])
        lines.append(f"\t\t{{\"name\": \"{tname}\", \"stem\": \"{t['stem']}\", \"gain_db\": {gains[tname]:.2f}, "
                     f"\"release\": {t['release']}, \"notes\": [{flat}]}},")
    lines += ["\t],", "}", ""]
    with open(index_path, "w") as f:
        f.write("\n".join(lines))
    if wav_dir:
        for bpm in (70, 100, 130):
            st = preview(score, bank, spans, tracks, gains, bpm)
            full = sum(st.values())
            sf.write(os.path.join(wav_dir, f"{name}_{bpm}.wav"), full.T.astype(np.float32), SR, subtype="FLOAT")
            for k, v in st.items():
                sf.write(os.path.join(wav_dir, f"{name}_{bpm}_{k}.wav"), v.T.astype(np.float32), SR, subtype="FLOAT")
    return os.path.getsize(path)
