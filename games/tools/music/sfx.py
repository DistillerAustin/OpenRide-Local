"""The game music renderer (#55): building blocks for game effects. Each returns mono audio at
dsp.SR. Original code for this repo (Apache-2.0); synthesised, no samples."""
import numpy as np

import dsp
import instruments as ins
from dsp import SR, secs, hz, osc, lp, hp, bp, drive, expdec


def silence(sec):
    return np.zeros(secs(sec))


def mix(*parts):
    """Sums (offset_seconds, audio) pairs into one buffer."""
    n = max(secs(o) + len(x if x.ndim == 1 else x[0]) for o, x in parts)
    out = np.zeros(n)
    for o, x in parts:
        if x.ndim == 2:
            x = x.mean(axis=0)
        a = secs(o)
        out[a:a + len(x)] += x
    return out


def whoosh(sec=0.45, lo=600, hi=5000, up=True, rng=None, peak_at=0.6):
    """Air rushing past: noise through a band that sweeps, swelling to `peak_at` of the way."""
    n = secs(sec)
    t = np.arange(n) / n
    nz = rng.uniform(-1, 1, n)
    env = np.where(t < peak_at, (t / peak_at) ** 1.5, ((1 - t) / (1 - peak_at)) ** 2)
    k = t if up else 1 - t
    centers = lo * (hi / lo) ** k
    # a moving band-pass, as a crossfade through a few fixed bands
    edges = np.geomspace(min(lo, hi), max(lo, hi), 6)
    out = np.zeros(n)
    for i in range(len(edges) - 1):
        band = bp(nz, edges[i], edges[i + 1])
        c = np.sqrt(edges[i] * edges[i + 1])
        w = np.exp(-(np.log(centers / c) ** 2) / 0.3)
        out += band * w
    return out * env


def thud(sec=0.35, f0=70, drop=60, rng=None, knock=0.5):
    n = secs(sec)
    t = np.arange(n) / SR
    f = f0 + drop * np.exp(-t / 0.03)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (sec * 0.35))
    k = bp(rng.uniform(-1, 1, n), 150, 1500) * np.exp(-t / 0.02) * knock
    return drive(body + k, 1.5)


def tick(freq=3200, sec=0.06, rng=None):
    n = secs(sec)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.01)
    x += hp(rng.uniform(-1, 1, n), 5000) * np.exp(-t / 0.003) * 0.5
    return x


def arp(notes, step, instr, dur=None, vel=1.0, rng=None, decay=1.0):
    """Notes one after another, `step` seconds apart, on an instrument from arrange.LEADS."""
    from arrange import LEADS
    fn = LEADS[instr]
    parts = []
    for i, m in enumerate(notes):
        parts.append((i * step, fn(m, dur or step * 1.2, vel * decay ** i, rng)))
    return mix(*parts)


def chord(notes, sec, instr, vel=1.0, rng=None, spread=0.0):
    from arrange import LEADS
    fn = LEADS[instr]
    return mix(*[(i * spread, fn(m, sec, vel, rng)) for i, m in enumerate(notes)])


def zap(sec=0.35, f0=1800, f1=200, rng=None):
    """An electric zap: a buzzy FM sweep down with crackle."""
    n = secs(sec)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / (sec * 0.3))
    ph = np.cumsum(f) / SR
    x = np.sign(np.sin(2 * np.pi * ph + 3 * np.sin(2 * np.pi * ph * 2.7)))
    x = lp(x, 6000) * 0.6
    crackle = (rng.random(n) > 0.985) * rng.uniform(-1, 1, n)
    x += hp(crackle, 2000) * 1.5
    return x * np.exp(-t / (sec * 0.35))


def sweep(sec, f0, f1, wave="sine", vib=0.0):
    n = secs(sec)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / sec)
    if vib:
        f = f * (1 + vib * np.sin(2 * np.pi * 9 * t))
    ph = np.cumsum(f) / SR
    if wave == "sine":
        return np.sin(2 * np.pi * ph)
    return osc(wave, f, n)


def env(x, a=0.005, r=0.1):
    n = len(x)
    e = np.ones(n)
    an, rn = min(n, secs(a)), min(n, secs(r))
    if an:
        e[:an] = np.linspace(0, 1, an)
    if rn:
        e[-rn:] *= np.linspace(1, 0, rn)
    return x * e


def splash(sec=1.2, rng=None):
    """Water: a broadband burst, then bubbling droplets."""
    n = secs(sec)
    t = np.arange(n) / SR
    burst = lp(rng.uniform(-1, 1, n), 5000) * np.exp(-t / 0.18) * np.minimum(1, t / 0.01)
    body = lp(rng.uniform(-1, 1, n), 700) * np.exp(-t / 0.3) * 0.8
    drops = np.zeros(n)
    for _ in range(26):
        at = secs(rng.uniform(0.05, sec * 0.8))
        d = secs(0.03)
        tt = np.arange(d) / SR
        f = rng.uniform(600, 2200) * (1 + 1.5 * tt / 0.03)
        b = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.01) * rng.uniform(0.2, 0.6)
        k = min(d, n - at)
        drops[at:at + k] += b[:k] * np.exp(-at / SR / (sec * 0.5))
    return burst + body + drops


def crowd(sec=2.0, rng=None, swell=True):
    """A crowd cheering: many voices as formant-filtered noise with pitched shouts."""
    n = secs(sec)
    t = np.arange(n) / SR
    nz = rng.uniform(-1, 1, n)
    x = bp(nz, 300, 900) * 0.8 + bp(nz, 1000, 2600) * 0.5 + bp(nz, 2600, 5000) * 0.2
    for _ in range(18):
        at = rng.uniform(0, sec * 0.7)
        d = rng.uniform(0.25, 0.6)
        m = rng.uniform(56, 72)
        a, k = secs(at), secs(d)
        tt = np.arange(k) / SR
        f = hz(m) * (1 + 0.15 * tt / d)
        v = osc("saw", f, k) * np.sin(np.pi * tt / d) ** 2
        v = bp(v, 400, 3000)
        k2 = min(k, n - a)
        x[a:a + k2] += v[:k2] * rng.uniform(0.1, 0.3)
    shape = np.minimum(1, t / (sec * 0.35)) ** 1.5 * np.minimum(1, (sec - t) / (sec * 0.4)) if swell else np.exp(-t / sec)
    return x * shape


def creak(sec=0.5, f0=140, rng=None):
    """Rope or wood under load: a slow stick-slip (a train of grain clicks through a body)."""
    n = secs(sec)
    t = np.arange(n) / SR
    rate = f0 * (1 + 0.4 * np.sin(2 * np.pi * 2.5 * t / sec))
    ph = np.cumsum(rate) / SR
    pulses = (np.diff(np.floor(ph), prepend=0) > 0).astype(float) * rng.uniform(0.5, 1, n)
    x = bp(pulses, 300, 2500) + bp(pulses, 900, 1300) * 2
    return x * np.sin(np.pi * t / sec) ** 0.7


def drumroll(sec, rng, crescendo=True):
    n = secs(sec)
    out = np.zeros(n)
    step = 0.045
    k = 0
    for at in np.arange(0, sec - 0.05, step):
        v = (0.3 + 0.7 * at / sec) if crescendo else 0.7
        s = ins.snare(v * (0.85 + 0.15 * (k % 2)), rng, tight=True)[: secs(0.12)]
        a = secs(at)
        m = min(len(s), n - a)
        out[a:a + m] += s[:m]
        k += 1
    return out


def fanfare(notes, beat, instr="brass", rng=None, hold=2.0, vel=1.0):
    """A short brass call: notes on a beat grid ((beat, dur_beats, midi) triples), the last held."""
    from arrange import LEADS
    fn = LEADS[instr]
    parts = []
    for b, d, m in notes:
        parts.append((b * beat, fn(m, d * beat, vel, rng)))
    return mix(*parts)
