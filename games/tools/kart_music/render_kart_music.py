"""Renders Kart Race's music (#43) to OGG Vorbis: per track a race theme (intro, then a looping
verse-chorus-verse-bridge-chorus) and a final-lap version (a key change up, double-time hats, an
extra lead), plus a results loop and a podium sting. Writes the files Godot plays and the index
KartAudio reads (`KartMusicIndex.gd`: paths, loop points, tempo, keys).

  python3 -m venv /tmp/venv && /tmp/venv/bin/pip install numpy scipy soundfile
  /tmp/venv/bin/python games/tools/kart_music/render_kart_music.py [--only meadow_ring] [--wav DIR]

Deterministic (seeded). Everything is synthesised by this code; no samples, no third-party
material. See README.md here for the design.
"""
import argparse
import os
import sys
import time

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
import dsp  # noqa: E402
import instruments as ins  # noqa: E402
from arrange import drums, bass, comp, line, counter  # noqa: E402
from compose import Song, parse_bars, transpose_sym, pc, MAJOR  # noqa: E402
from themes import THEMES, RESULTS, PODIUM  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "games", "kart_race", "music")
INDEX = os.path.join(ROOT, "games", "kart_race", "audio", "KartMusicIndex.gd")
MUSIC_LUFS = -15.0  # the files' loudness; the Music bus (0.8) puts them near -17 in game
OGG_QUALITY = 0.86  # libsndfile's Vorbis compression level (0 best .. 1 smallest): ~78 kbps here

## Each bus's RMS (dB) in the mix, before the master: the balance (see Song.mix).
TARGETS = {"kick": -19, "snare": -21, "hats": -29, "perc": -31, "cym": -32, "bass": -19, "gtr": -24,
           "gtr2": -27, "keys": -24, "brass": -25, "lead": -19.5, "lead2": -25, "pad": -27, "fx": -33}
LEVELS = TARGETS
SENDS = {"snare": {"room": 0.5, "verb": 0.12}, "perc": {"room": 0.3}, "cym": {"verb": 0.1},
         "gtr": {"verb": 0.12, "room": 0.2}, "gtr2": {"room": 0.2}, "keys": {"verb": 0.25},
         "brass": {"verb": 0.25}, "lead": {"verb": 0.22, "delay": 0.18}, "lead2": {"verb": 0.3, "delay": 0.1},
         "pad": {"verb": 0.4}, "fx": {"verb": 0.4}}
SIDECHAIN = {"pad": 0.6, "bass": 0.25, "keys": 0.3, "gtr2": 0.3, "lead2": 0.2}


def section_plan(variant):
    if variant == "main":
        return [("intro", 4)], [("verse", 8), ("chorus", 8), ("verse2", 8), ("bridge", 8), ("chorus2", 8)]
    return [("pickup", 2)], [("fchorus", 8), ("fchorus2", 8)]


def render_theme(spec, variant, seed):
    shift = spec["final_shift"] if variant == "final" else 0
    key_pc = (pc(spec["key"]) + shift) % 12
    head, body = section_plan(variant)
    plan = head + body + body  # the body twice: the second pass starts with the first's tails
    total = sum(b for _, b in plan)
    song = Song(spec["bpm"], total, seed)
    rng = np.random.default_rng(seed + 1)
    mel = {k: parse_bars(v, shift) for k, v in spec["melody"].items()}
    chords = {k: [" ".join(transpose_sym(s, shift) for s in bar.split()) for bar in v] for k, v in spec["chords"].items()}
    bar0 = 0
    for si, (name, n) in enumerate(plan):
        # Re-seed per section, the same for both passes of the body: the passes are then
        # identical, so the loop point is seamless (the file ends where the second pass ends).
        k = si if si < len(head) else len(head) + (si - len(head)) % len(body)
        song.rng = np.random.default_rng(seed * 100 + k)
        rng = np.random.default_rng(seed * 100 + 50 + k)
        base = {"verse2": "verse", "chorus2": "chorus", "fchorus": "chorus", "fchorus2": "chorus"}.get(name, name)
        role = {"verse2": "verse", "chorus2": "chorus", "fchorus": "final", "fchorus2": "final"}.get(name, name)
        ch = chords[base][:n]
        drums(song, bar0, n, spec["drums"], role, double=variant == "final")
        bass(song, bar0, ch, spec["bass"], role, rng)
        parts = spec["parts"].get({"fchorus": "chorus", "fchorus2": "chorus2"}.get(name, name), [])
        if name == "pickup":
            parts = [("comp", "pad", 0.8)]
            song.put("fx", bar0 * 4, ins.riser(n * 4 * song.spb, rng), human=0)
        for p in parts:
            kind = p[0]
            if kind == "comp" and p[2] > 0:
                comp(song, bar0, ch, p[1], role, rng, p[2])
            elif kind == "lead":
                harm = (key_pc, spec["scale"]) if (len(p) > 6 and p[6]) or name == "fchorus2" else None
                line(song, bar0, mel[p[1]][:n], p[2], p[3], rng, shift=p[4], vel=p[5], harmony=harm)
            elif kind == "counter":
                line(song, bar0, counter(ch), p[1], p[2], rng, vel=p[3])
        if name in ("fchorus", "fchorus2"):  # the final lap's extra lead: the hook an octave up
            line(song, bar0, mel["chorus"][:n], "supersaw", "lead2", rng, shift=12, vel=0.45, pan=0.3)
        if name in ("intro", "bridge"):  # a riser into the next section
            song.put("fx", (bar0 + n - 1) * 4, ins.riser(4 * song.spb, rng), human=0)
        bar0 += n
    audio = song.mix(LEVELS, SENDS, SIDECHAIN, MUSIC_LUFS)
    head_n = song.at(sum(b for _, b in head) * 4)
    body_n = song.at(sum(b for _, b in body) * 4)
    out = np.concatenate([audio[:, :head_n], audio[:, head_n + body_n: head_n + 2 * body_n]], axis=1)
    return out, head_n / dsp.SR, key_pc


def render_results(seed):
    s = RESULTS
    song = Song(s["bpm"], 16, seed)
    rng = np.random.default_rng(seed)
    for pass_ in range(2):
        b0 = pass_ * 8
        for i in range(8):
            b = (b0 + i) * 4
            song.hit("kick", b, 0.7, "kick")
            song.hit("kick", b + 2.5, 0.5, "kick")
            song.hit("snare", b + 2, 0.5, "snare")
            for t in np.arange(0, 4, 0.5):
                song.hit("hat", b + t, 0.35, "hats", pan=0.25)
            for t in np.arange(0, 4, 0.25):
                song.hit("shaker", b + t, 0.3, "perc", pan=-0.4)
        bass(song, b0, s["chords"], "pick8", "intro", rng)
        comp(song, b0, s["chords"], "ep", "verse", rng, 0.8)
        comp(song, b0, s["chords"], "pad", "verse", rng, 0.5)
        line(song, b0, parse_bars(s["melody"]), "ep", "lead", rng, vel=0.7)
    audio = song.mix(LEVELS, SENDS, SIDECHAIN, MUSIC_LUFS - 2)
    n = song.at(32)
    return audio[:, n:2 * n]


def render_podium(seed):
    s = PODIUM
    song = Song(s["bpm"], 4, seed)
    rng = np.random.default_rng(seed)
    song.hit("crash", 0, 1.0, "cym")
    song.hit("crash", 12, 1.0, "cym")
    for b in range(4):
        for t in (0, 2) if b < 3 else (0,):
            song.hit("tom", b * 4 + t, 0.9, "kick", pitch=0.7)
    for k, t in enumerate(np.arange(10, 12, 0.25)):
        song.hit("snare", t, 0.35 + 0.06 * k, "snare")
    comp(song, 0, s["chords"], "stabs_hold", "chorus", rng, 1.0)
    comp(song, 0, s["chords"], "pad", "chorus", rng, 0.8)
    bass(song, 0, s["chords"], "pick8", "intro", rng)
    mel = parse_bars(s["melody"])
    line(song, 0, mel, "brass", "lead", rng, vel=1.0)
    line(song, 0, mel, "supersaw", "lead2", rng, shift=12, vel=0.5)
    audio = song.mix(LEVELS, SENDS, {}, MUSIC_LUFS + 1)
    n = song.at(16) + dsp.secs(2.5)
    out = audio[:, :n]
    out[:, -dsp.secs(1.0):] *= np.linspace(1, 0, dsp.secs(1.0))
    return out


def write(name, audio, wav_dir):
    path = os.path.join(OUT_DIR, name + ".ogg")
    sf.write(path, audio.T.astype(np.float32), dsp.SR, format="OGG", subtype="VORBIS", compression_level=OGG_QUALITY)
    if wav_dir:
        sf.write(os.path.join(wav_dir, name + ".wav"), audio.T.astype(np.float32), dsp.SR, subtype="FLOAT")
    print(f"  {name}: {audio.shape[1] / dsp.SR:.1f} s, {dsp.lufs(audio):.1f} LUFS, "
          f"TP {dsp.true_peak_db(audio):.1f} dBTP, {os.path.getsize(path) / 1024:.0f} KB")


def write_index(index):
    lines = ["class_name KartMusicIndex", "extends RefCounted",
             "## Kart Race's rendered music (#43): written by games/tools/kart_music/render_kart_music.py; don't",
             "## edit by hand. Per track: the race theme and the final lap's version (paths, the second the loop",
             "## restarts at, the tempo, the key's pitch class), plus the results loop and the podium sting.",
             "", "const DIR := \"res://games/kart_race/music\"", "", "const THEMES := {"]
    for tid, e in index["themes"].items():
        lines.append(f"\t\"{tid}\": {{\"title\": \"{e['title']}\", \"bpm\": {e['bpm']:.1f}, \"key\": {e['key']}, "
                     f"\"final_key\": {e['final_key']}, \"main\": \"{tid}.ogg\", \"main_loop\": {e['main_loop']:.4f}, "
                     f"\"final\": \"{tid}_final.ogg\", \"final_loop\": {e['final_loop']:.4f}}},")
    lines += ["}", "const RESULTS := \"results.ogg\"", "const PODIUM := \"podium.ogg\"", ""]
    with open(INDEX, "w") as f:
        f.write("\n".join(lines))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--wav", default="")
    a = ap.parse_args()
    os.makedirs(OUT_DIR, exist_ok=True)
    index = {"themes": {}}
    for i, (tid, spec) in enumerate(THEMES.items()):
        if a.only and a.only not in tid and a.only not in ("results", "podium"):
            continue
        if a.only in ("results", "podium"):
            break
        t0 = time.time()
        main_audio, main_loop, key = render_theme(spec, "main", 100 + i)
        write(tid, main_audio, a.wav)
        fin, fin_loop, fkey = render_theme(spec, "final", 200 + i)
        write(tid + "_final", fin, a.wav)
        index["themes"][tid] = dict(title=spec["title"], bpm=spec["bpm"], key=key, final_key=fkey,
                                    main_loop=main_loop, final_loop=fin_loop)
        print(f"{tid} rendered in {time.time() - t0:.1f} s")
    if not a.only or a.only == "results":
        write("results", render_results(7), a.wav)
    if not a.only or a.only == "podium":
        write("podium", render_podium(8), a.wav)
    if not a.only:
        write_index(index)
    total = sum(os.path.getsize(os.path.join(OUT_DIR, f)) for f in os.listdir(OUT_DIR) if f.endswith(".ogg"))
    print(f"music total {total / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
