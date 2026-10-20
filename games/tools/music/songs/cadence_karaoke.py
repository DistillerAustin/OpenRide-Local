"""Cadence Karaoke (#42, #55): "Neon Lines", bright synth-funk in A major that plays at the rider's
cadence: one beat per pedal stroke from 70 to 130 rpm, two below that (so 40-65 rpm plays at
80-130 bpm). It ships as a sample bank and a score (see sequencer.py) that
res://audio/SongSequencer.gd lays out at any tempo, so a pace change keeps the same song and
instruments. A 24-bar loop: verse, chorus, a 4-bar bridge and half a chorus back into the verse.

Bed: kick, snare and clap, hats and a shaker, crash, slap bass. Harmony: Rhodes comping, a pad,
plucked arpeggios. Lead (only while the rider is in the band): a breathy lead in the verse, a
supersaw hook with a harmony line in the chorus. Written for this repo."""
import numpy as np

from compose import parse_bars, bar_chords, voicing, bass_root, parse_chord, third_below, MAJOR
from sequencer import Score

PREFIX = "Cadence"
TITLE = "Neon Lines"
FILE = "neon_lines"
KEY = "A"
SONG = None  # not a rendered song: SEQ is

SECTIONS = [("verse", 8), ("chorus", 8), ("bridge", 4), ("chorus2", 4)]
CHORDS = dict(
    verse=["Amaj7", "F#m7", "Dmaj7", "E", "Amaj7", "F#m7", "Bm7", "E"],
    chorus=["D", "E", "C#m7", "F#m7", "D", "E", "Bm7", "E7"],
    bridge=["Bm7", "C#m7", "Dmaj7", "E7sus4"],
    chorus2=["D", "E", "C#m7 F#m7", "Bm7 E7"],
)
MELODY = dict(
    verse="E5:1 C#5:0.5 E5:0.5 A5:1 G#5:1 | F#5:1.5 E5:0.5 C#5:1 r:1 | F#5:0.5 E5:0.5 D5:0.5 C#5:0.5 D5:1 F#5:1 |"
          " E5:2 B4:1 r:1 | E5:1 C#5:0.5 E5:0.5 A5:1 B5:1 | C#6:1.5 B5:0.5 A5:1 F#5:1 |"
          " D5:0.5 F#5:0.5 A5:0.5 B5:0.5 A5:1 F#5:1 | G#5:2 E5:1 r:1",
    chorus="A5:1 F#5:0.5 A5:0.5 D6:1 C#6:1 | B5:1.5 G#5:0.5 E5:1 r:1 | G#5:0.5 A5:0.5 B5:0.5 C#6:0.5 E6:1 C#6:1 |"
           " A5:2 F#5:1 r:1 | A5:1 F#5:0.5 A5:0.5 D6:1 E6:1 | E6:1 D6:0.5 C#6:0.5 B5:1 G#5:1 |"
           " A5:0.5 B5:0.5 D6:0.5 C#6:0.5 B5:1 A5:1 | G#5:1 B5:1 D6:1 r:1",
    bridge="F#5:2 D5:2 | E5:2 G#5:2 | A5:2 F#5:1 A5:1 | B5:3 r:1",
    chorus2="A5:1 F#5:0.5 A5:0.5 D6:1 C#6:1 | B5:1.5 G#5:0.5 E5:1 r:1 | G#5:1 E5:1 F#5:1 A5:1 | B5:1 D6:1 G#5:1 E5:1",
)


def score():
    s = Score(sum(n for _, n in SECTIONS), tempo_min=70.0, tempo_max=130.0)
    s.track("kick", "bed", target=-19)
    s.track("snare", "bed", target=-21)
    s.track("hats", "bed", target=-28)
    s.track("crash", "bed", release=0.08, target=-33)
    s.track("bass", "bed", release=0.02, target=-19)
    s.track("keys", "harmony", release=0.06, target=-24)
    s.track("pad_a", "harmony", release=0.15, target=-28)
    s.track("pad_b", "harmony", release=0.15, target=-28)
    s.track("arp_a", "harmony", release=0.05, target=-30)
    s.track("arp_b", "harmony", release=0.05, target=-30)
    s.track("lead_a", "lead", release=0.05, target=-24)
    s.track("lead_b", "lead", release=0.05, target=-24)
    s.track("lead2", "lead", release=0.05, target=-30)
    bar0 = 0
    pad_flip = 0
    for name, n in SECTIONS:
        big = name.startswith("chorus")
        for i in range(n):
            b = (bar0 + i) * 4
            text = CHORDS[name][i]
            _drums(s, b, name, i, n, big)
            _bass(s, b, text, name)
            for beat0, sym, dur in bar_chords(text):
                if name == "verse":
                    for t, g, v in ((0, 1.6, 0.75), (1.75, 0.6, 0.6), (2.5, 1.4, 0.7)):
                        if t < dur:
                            s.note("keys", b + beat0 + t, "epiano", voicing(sym, 62), g, v, -0.3)
                s.note("pad_a" if pad_flip % 2 == 0 else "pad_b", b + beat0, "pad", voicing(sym, 60, drop_root=False),
                       dur * 0.95, 0.45 if name == "verse" else 0.7)
                pad_flip += 1
                if big:
                    tones = voicing(sym, 70, drop_root=False)
                    for k, t in enumerate(np.arange(0, dur, 0.5)):
                        m = tones[k % len(tones)] if (k // len(tones)) % 2 == 0 else tones[::-1][k % len(tones)]
                        s.note("arp_a" if k % 2 == 0 else "arp_b", b + beat0 + t, "pluck", m, 0.45, 0.65, -0.5 if k % 2 == 0 else 0.5)
                elif name == "bridge":
                    s.note("keys", b + beat0, "epiano", voicing(sym, 62), dur * 0.95, 0.6, -0.3)
        _lead(s, bar0, name, n)
        bar0 += n
    return s


def _drums(s, b, name, i, n, big):
    if i == 0 and name in ("verse", "chorus", "chorus2"):
        s.drum("crash", b, "crash", 0.75, 0.3)
    last = i == n - 1
    if name == "bridge":
        s.drum("kick", b, "kick", 0.9)
        s.drum("snare", b + 2, "snare", 0.8)
        for t in (0, 1, 2, 3):
            s.drum("hats", b + t, "hat", 0.45, 0.25)
        if last:
            for k, t in enumerate(np.arange(2.5, 4, 0.25)):
                s.drum("snare", b + t, "snare", 0.3 + 0.08 * k)
        return
    kicks = [0, 1, 2, 3] if big else ([0, 0.75, 2.5] if i % 2 == 0 else [0, 1.75, 2.5])
    for k in kicks:
        s.drum("kick", b + k, "kick", 1.0 if k == 0 else 0.85)
    for t in (1, 3):
        s.drum("snare", b + t, "snare", 0.95)
        s.drum("snare", b + t, "clap", 0.55 if big else 0.4, -0.1)
    if not big and i % 2 == 1:
        s.drum("snare", b + 3.75, "ghost", 0.9, 0.1)
    for t in np.arange(0, 4, 0.5):
        off = (t * 2) % 2 == 1
        if (big and off) or (not big and t == 3.5):
            s.drum("hats", b + t, "hat", 0.55, 0.25, open_=True)
        else:
            s.drum("hats", b + t, "hat", 0.5 if off else 0.72, 0.25)
    if big:
        for t in np.arange(0.25, 4, 0.5):
            s.drum("hats", b + t, "shaker", 0.55, -0.4)
    if last and name == "verse":
        for k, t in enumerate(np.arange(3, 4, 0.25)):
            s.drum("snare", b + t, "snare", 0.4 + 0.1 * k)


def _bass(s, b, text, name):
    pattern = {
        "verse": [(0, "r", 0.45, "slap"), (0.75, "o", 0.2, "slap_pop"), (1.5, "r", 0.4, "slap"), (2.0, "5", 0.4, "slap"),
                  (2.5, "o", 0.2, "slap_pop"), (3.0, "r", 0.4, "slap"), (3.5, "5", 0.2, "slap")],
        "bridge": [(0, "r", 1.8, "slap"), (2.5, "r", 1.2, "slap")],
    }.get(name, [(t, "r" if t % 1 == 0 else "o", 0.4, "slap" if t % 1 == 0 else "slap_pop") for t in np.arange(0, 4, 0.5)])
    for beat0, sym, dur in bar_chords(text):
        r = bass_root(sym, lo=28)
        _, ivs, _ = parse_chord(sym)
        for t, w, g, inst in pattern:
            if t >= dur:
                continue
            m = {"r": r, "o": r + 12, "5": r + 7}[w]
            s.note("bass", b + beat0 + t, inst, m, g, 0.95 if t == 0 else 0.85)


def _lead(s, bar0, name, n):
    bars = parse_bars(MELODY[name])[:n]
    inst = "flute" if name == "verse" else "supersaw" if name != "bridge" else "flute"
    flip = 0
    for i, notes in enumerate(bars):
        b = (bar0 + i) * 4
        for t, d, m in notes:
            v = 0.9 if t % 1 == 0 else 0.8
            s.note("lead_a" if flip % 2 == 0 else "lead_b", b + t, inst, m, d * 0.95, v)
            flip += 1
            if name.startswith("chorus"):
                s.note("lead2", b + t, "strings", third_below(m, 9, MAJOR), d * 0.95, 0.55, 0.3)


SEQ = score


def beat_tick(rng):
    # The metronome: a dry woodblock-like click, high so it sits over the drums.
    import instruments as ins
    import sfx as fx
    return fx.mix((0, ins.rim(1.0, rng)), (0, fx.tick(2400, 0.04, rng) * 0.5))


def streak_up(rng):
    # A streak step: a quick sparkle up the A major triad (the game raises its pitch per step).
    import sfx as fx
    from compose import note
    notes = [note(n) for n in ("A5", "C#6", "E6")]
    return fx.mix((0, fx.arp(notes, 0.05, "bells", 0.25, 1.0, rng)), (0, fx.arp(notes, 0.05, "pluck", 0.2, 0.6, rng)))


def band_exit(rng):
    # Out of the band: a soft falling "bwow" and a dull pluck.
    import sfx as fx
    from compose import note
    down = fx.env(fx.lp(fx.sweep(0.35, 700, 260, "saw"), 1600) * 0.5, 0.01, 0.2)
    return fx.mix((0, down), (0, fx.arp([note("E5"), note("D#5")], 0.09, "pluck", 0.25, 0.7, rng)))


def ease_off_chime(rng):
    # Too much power: a gentle falling two-tone chime.
    import sfx as fx
    from compose import note
    return fx.arp([note("E6"), note("C#6"), note("E6"), note("C#6")], 0.16, "bells", 0.3, 0.9, rng, decay=0.85)


SFX = {"beat_tick": beat_tick, "streak_up": streak_up, "band_exit": band_exit, "ease_off_chime": ease_off_chime}
