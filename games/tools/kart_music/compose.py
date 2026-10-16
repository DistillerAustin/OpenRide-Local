"""Kart Race music renderer (#43): theory helpers, the arrangement (who plays what, section by
section) and the mix. Original code for this repo (Apache-2.0)."""
import numpy as np
import dsp
import instruments as ins
from dsp import SR, secs

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
QUALITY = {
    "": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
    "m9": [0, 3, 7, 10, 14], "maj9": [0, 4, 7, 11, 14], "9": [0, 4, 7, 10, 14], "sus4": [0, 5, 7],
    "7sus4": [0, 5, 7, 10], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "add9": [0, 4, 7, 14], "5": [0, 7],
    "dim": [0, 3, 6], "m7b5": [0, 3, 6, 10], "13": [0, 4, 10, 14, 21],
}
MAJOR = [0, 2, 4, 5, 7, 9, 11]
MIXO = [0, 2, 4, 5, 7, 9, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]


def pc(name):
    p = NOTE[name[0]]
    for ch in name[1:]:
        p += 1 if ch == "#" else -1 if ch == "b" else 0
    return p % 12


def note(s):
    """'F#5' -> midi."""
    i = len(s) - 1
    while s[i - 1].isdigit() or s[i - 1] == "-":
        i -= 1
    return pc(s[:i]) + 12 * (int(s[i:]) + 1)


def parse_chord(sym):
    """'F#m7' or 'E/G#' -> (root pc, intervals, bass pc)."""
    bass = None
    if "/" in sym:
        sym, b = sym.split("/")
        bass = pc(b)
    r = 1
    while r < len(sym) and sym[r] in "#b":
        r += 1
    root = pc(sym[:r])
    return root, QUALITY[sym[r:]], root if bass is None else bass


def voicing(sym, center=64, drop_root=True, top=None):
    root, ivs, _ = parse_chord(sym)
    tones = [(root + i) % 12 for i in ivs]
    if drop_root and len(tones) >= 4:
        tones = tones[1:]
    out = []
    for t in tones:
        m = t + 12 * round((center - t) / 12)
        out.append(m)
    out = sorted(set(out))
    if top:
        out = out[-top:]
    return out


def bass_root(sym, lo=31):
    _, _, b = parse_chord(sym)
    m = b + 12 * ((lo - b) // 12 + 1)
    return m if m - 12 < lo else m - 12


def parse_bars(text, shift=0):
    """'r:0.5 D5:0.5 ... | ...' -> list of bars of (beat, dur, midi or None)."""
    bars = []
    for bar in text.split("|"):
        b, out = 0.0, []
        for tok in bar.split():
            n, d = tok.split(":")
            d = float(d)
            if n != "r":
                out.append((b, d, note(n) + shift))
            b += d
        assert abs(b - 4) < 1e-6, f"bar sums to {b}: {bar}"
        bars.append(out)
    return bars


def bar_chords(bar_text):
    """'Em7 A7' -> [(0, 'Em7', 2), (2, 'A7', 2)]."""
    syms = bar_text.split()
    d = 4 / len(syms)
    return [(i * d, s, d) for i, s in enumerate(syms)]


def transpose_sym(sym, k):
    names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
    def tr(part):
        r = 1
        while r < len(part) and part[r] in "#b":
            r += 1
        return names[(pc(part[:r]) + k) % 12] + part[r:]
    if "/" in sym:
        a, b = sym.split("/")
        return tr(a) + "/" + tr(b)
    return tr(sym)


def third_below(m, key_pc, scale):
    """The diatonic third below a melody note (for the harmony line)."""
    pcs = [(key_pc + s) % 12 for s in scale]
    rel = m % 12
    if rel not in pcs:
        return m - 3
    i = pcs.index(rel)
    j = (i - 2) % 7
    d = (rel - pcs[j]) % 12
    return m - d


# --- The song: buses, scheduling, the mix ---

BUSES = ["kick", "snare", "hats", "perc", "cym", "bass", "gtr", "gtr2", "keys", "brass", "lead", "lead2", "pad", "fx"]


class Song:
    def __init__(self, bpm, bars, seed):
        self.bpm = bpm
        self.spb = 60.0 / bpm
        self.n = secs(bars * 4 * self.spb + 4.0)
        self.bus = {b: np.zeros((2, self.n)) for b in BUSES}
        self.rng = np.random.default_rng(seed)
        self.kicks = []
        self._cache = {}

    def at(self, beat):
        return secs(beat * self.spb)

    def put(self, bus, beat, x, pan=0.0, human=0.004):
        at = self.at(beat) + (int(self.rng.normal(0, human * SR)) if human else 0)
        if x.ndim == 1:
            x = dsp.pan(x, pan)
        dsp.add(self.bus[bus], x, at)

    def hit(self, kind, beat, vel, bus, pan=0.0, **kw):
        """A drum hit from a small cache of variants (round robin), scaled by velocity."""
        key = (kind, tuple(sorted(kw.items())))
        if key not in self._cache:
            fn = getattr(ins, kind)
            self._cache[key] = [fn(1.0, np.random.default_rng(hash(key) % 1000 + i), **kw) for i in range(4)]
        v = self._cache[key][self.rng.integers(4)]
        vel *= self.rng.uniform(0.92, 1.05)
        self.put(bus, beat, v * vel, pan, human=0.003 if kind != "kick" else 0.0)
        if kind == "kick":
            self.kicks.append(self.at(beat))

    def mix(self, targets, sends, sidechain, master_lufs=-18.0, verb_sec=1.7):
        """Balances each bus to its target RMS (dB, over the whole render, so the balance holds
        from theme to theme while each bus keeps its own section dynamics), adds chorus to the
        keys, pads and second lead, reverb/delay sends and a kick-keyed pump on the listed buses,
        then glue compression, a limiter at -1 dBTP and loudness to master_lufs."""
        duck = np.zeros(self.n)  # 1 right after each kick, gone in ~0.3 s
        for k in self.kicks:
            m = min(self.n - k, secs(0.4))
            t = np.arange(m) / SR
            duck[k:k + m] = np.maximum(duck[k:k + m], np.minimum(1, t / 0.004) * np.exp(-t / 0.1))
        out = np.zeros((2, self.n))
        verb_in = np.zeros((2, self.n))
        room_in = np.zeros((2, self.n))
        dly_in = np.zeros((2, self.n))
        report = []
        for b in BUSES:
            x = self.bus[b]
            if not np.any(x):
                continue
            rms = 10 * np.log10(np.mean(x ** 2) + 1e-12)
            gain = float(np.clip(targets.get(b, -30.0) - rms, -30, 30))
            report.append(f"{b} {rms:.1f}{gain:+.1f}")
            x = x * 10 ** (gain / 20)
            if b in ("keys", "pad", "lead2"):
                x = dsp.chorus(x, rate=0.6 if b != "keys" else 3.5, depth_ms=2.5 if b != "keys" else 1.2, mix=0.5)
            if b in sidechain:
                x = x * (1 - sidechain[b] * duck)
            out += x
            s = sends.get(b, {})
            verb_in += x * s.get("verb", 0.0)
            room_in += x * s.get("room", 0.0)
            dly_in += x * s.get("delay", 0.0)
        out += dsp.convolve(dsp.hp(verb_in, 250), dsp.reverb_ir(verb_sec, 0.025, 5500, seed=3)) * 0.5
        out += dsp.convolve(room_in, dsp.reverb_ir(0.55, 0.008, 7000, seed=4, width=0.8)) * 0.6
        out += dsp.delay_wet(dsp.hp(dly_in, 300), self.spb * 0.75, 0.35) * 0.6
        if __import__("os").environ.get("KART_MUSIC_DEBUG"):
            print("   bus rms dB:", ", ".join(report))
        out = dsp.hp(out, 30)
        out = dsp.compress(out, threshold_db=-14, ratio=2.0, attack=0.02, release=0.2, makeup_db=0)
        g = 10 ** ((master_lufs - dsp.lufs(out)) / 20)
        out = dsp.limit(out * g, -1.6)
        return out
