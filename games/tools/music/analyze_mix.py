"""Analyses a game's offline audio render (#55): the WAVs and events.json that
tests/render_game_audio.gd writes. Loudness (BS.1770, gated), peaks, clipping, the music and
effects levels, how far each effect cuts through the music, and the music duck.

  python analyze_mix.py DIR [--limit]     # --limit: through a -1 dBFS limiter, as Master does

Cut-through: for each sound played, over its first 0.3 s (or its length), the effects bus's level
over the music's, per band and broadband, in dB. The best band is where it reads; 6 dB or more
there reads clearly.
"""
import json
import sys

import numpy as np
from scipy import signal

BANDS = [(30, 150), (150, 500), (500, 1500), (1500, 4000), (4000, 8000), (8000, 10500)]


def load(path):
    raw = open(path, "rb").read()
    return np.frombuffer(raw[44:], dtype=np.float32).astype(float)


def k_weight(x, sr):
    # BS.1770 pre-filter (high shelf +4 dB at ~1.7 kHz) and RLB high-pass, by the bilinear
    # transform at this rate.
    f0, g, q = 1681.97, 3.99984, 0.7071752
    k = np.tan(np.pi * f0 / sr)
    vh, vb = 10 ** (g / 20), 10 ** (g / 20) ** 0.4996667
    a0 = 1 + k / q + k * k
    b = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    y = signal.lfilter(b, a, x)
    f0, q = 38.13547, 0.5003270
    k = np.tan(np.pi * f0 / sr)
    a0 = 1 + k / q + k * k
    return signal.lfilter([1, -2, 1], [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0], y)


def lufs(x, sr, momentary=False):
    y = k_weight(x, sr)
    blk, hop = int(0.4 * sr), int(0.1 * sr)
    ms = np.array([np.mean(y[i:i + blk] ** 2) for i in range(0, len(y) - blk, hop)])
    if len(ms) == 0:
        return -70.0
    l = -0.691 + 10 * np.log10(np.maximum(ms, 1e-12))
    if momentary:
        return float(l.max())
    g = ms[l > -70]
    if len(g) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(g.mean()) - 10
    g2 = ms[(l > -70) & (l > rel)]
    return float(-0.691 + 10 * np.log10(g2.mean()))


def limit(x, sr, ceiling_db=-1.0, release=0.12):
    c = 10 ** (ceiling_db / 20)
    a = np.abs(x)
    if a.max() <= c:
        return x
    from scipy.ndimage import maximum_filter1d
    pk = maximum_filter1d(a, size=int(0.002 * sr) * 2 + 1)
    need = np.minimum(1.0, c / np.maximum(pk, 1e-9))
    r = np.exp(-1 / (release * sr))
    g = 1.0 - signal.lfilter([1 - r], [1, -r], 1.0 - need)
    return np.clip(x * np.minimum(g, need), -c, c)


def db(x):
    return 10 * np.log10(np.mean(x ** 2) + 1e-12)


def band_db(x, sr):
    f, p = signal.welch(x, sr, nperseg=min(len(x), 1024))
    return [10 * np.log10(p[(f >= lo) & (f < hi)].sum() + 1e-14) for lo, hi in BANDS]


def main():
    d = sys.argv[1]
    lim = "--limit" in sys.argv
    meta = json.load(open(d + "/events.json"))
    sr = meta["sr"]
    music, sfx = load(d + "/music.wav"), load(d + "/sfx.wav")
    mix = music + sfx
    pre_peak = 20 * np.log10(np.abs(mix).max() + 1e-12)
    clipped = int(np.sum(np.abs(mix) >= 1.0))
    if lim:
        mix = limit(mix, sr)
    tp = 20 * np.log10(np.abs(signal.resample_poly(mix, 4, 1)).max() + 1e-12)
    print(f"mix: {lufs(mix, sr):.1f} LUFS integrated, max momentary {lufs(mix, sr, True):.1f}, "
          f"peak {pre_peak:+.1f} dBFS before any limiter, clipped samples {clipped}, true peak {tp:+.1f} dBTP"
          + (" (after the -1 dB limiter)" if lim else ""))
    print(f"music: {lufs(music, sr):.1f} LUFS, peak {20 * np.log10(np.abs(music).max() + 1e-12):+.1f}; "
          f"effects: {lufs(sfx, sr):.1f} LUFS, peak {20 * np.log10(np.abs(sfx).max() + 1e-12):+.1f}")
    print("music bands dB", [round(v, 1) for v in band_db(music, sr)])
    per = {}
    for e in meta["events"]:
        if e["sound"].startswith("("):
            print(f"  {e['sound']} at {e['t']:.2f} s, from {e.get('from', 0):.2f} s into the new loop")
            continue
        a = int(e["t"] * sr)
        n = int(min(max(e["len"] / max(e["pitch"], 0.1), 0.05), 0.3) * sr)
        if a + n > len(sfx):
            continue
        cue, rest = sfx[a:a + n], music[a:a + n]
        cb, rb = band_db(cue, sr), band_db(rest, sr)
        best = max(c - r for c, r in zip(cb, rb))
        per.setdefault(e["sound"], []).append((best, db(cue) - db(rest), db(cue)))
    print("cut-through over the music, median dB (best band / broadband), the sound's own level dBFS rms:")
    for k in sorted(per):
        v = np.array(per[k])
        print(f"  {k:16s} n={len(v):3d}  best {np.median(v[:, 0]):6.1f}  broad {np.median(v[:, 1]):6.1f}  "
              f"worst-best {v[:, 0].min():6.1f}  level {np.median(v[:, 2]):6.1f}")
    st = meta["states"]
    ducks = [s["duck"] for s in st]
    print(f"duck: {sum(1 for x in ducks if x < -0.5)} of {len(ducks)} samples ducked, deepest {min(ducks):.1f} dB")
    lv = {}
    for s in st:
        for k, v in s["stems"].items():
            lv.setdefault(k, []).append(v)
    print("stems up (share of time):", {k: round(float(np.mean(np.array(v) > 0.5)), 2) for k, v in lv.items()})


if __name__ == "__main__":
    main()
