"""Kart Race music renderer (#43): the instruments. Each takes (midi or a chord, seconds, velocity,
rng, **options) and returns a mono buffer, except where noted. All synthesised; original code."""
import numpy as np
from dsp import SR, hz, secs, osc, vibrato, adsr, expdec, fade_out, lp, hp, bp, sweep_lp, drive, ks, peak_eq


# --- Drums ---

def kick(vel, rng, tone=1.0):
    n = secs(0.45)
    t = np.arange(n) / SR
    f = 46 + 110 * tone * np.exp(-t / 0.035) + 60 * np.exp(-t / 0.006)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.32)
    click = hp(rng.uniform(-1, 1, n), 2500) * np.exp(-t / 0.0025) * 0.5
    x = drive(body * 1.4 + click, 1.6)
    return x * vel


def snare(vel, rng, tight=False):
    n = secs(0.4)
    t = np.arange(n) / SR
    body = (np.sin(2 * np.pi * 182 * t) * 0.8 + np.sin(2 * np.pi * 329 * t) * 0.45) * np.exp(-t / 0.07)
    nz = bp(rng.uniform(-1, 1, n), 1400, 9000) * np.exp(-t / (0.11 if tight else 0.17))
    snap = hp(rng.uniform(-1, 1, n), 4000) * np.exp(-t / 0.01)
    x = body * 0.7 + nz * 1.2 + snap * 0.4
    return drive(x, 1.3) * vel


def ghost(vel, rng):
    return snare(vel * 0.3, rng, tight=True)[: secs(0.12)]


def clap(vel, rng):
    n = secs(0.35)
    t = np.arange(n) / SR
    env = np.zeros(n)
    for k, at in enumerate([0.0, 0.011, 0.022, 0.031]):
        s = secs(at)
        env[s:] += np.exp(-(t[: n - s]) / (0.006 if k < 3 else 0.12)) * (0.8 if k < 3 else 1.0)
    return bp(rng.uniform(-1, 1, n), 900, 5000) * env * vel


_METAL = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]


def _metal(n, rng, scale=1.0):
    t = np.arange(n) / SR
    m = sum(np.sign(np.sin(2 * np.pi * f * scale * t + rng.uniform(0, 6.28))) for f in _METAL)
    return m / 6


def hat(vel, rng, open_=False):
    n = secs(0.5 if open_ else 0.09)
    t = np.arange(n) / SR
    x = _metal(n, rng, 1.6) * 0.6 + rng.uniform(-1, 1, n) * 0.6
    x = hp(bp(x, 6500, 12000), 7000)
    return x * np.exp(-t / (0.16 if open_ else 0.022)) * vel


def shaker(vel, rng):
    n = secs(0.12)
    t = np.arange(n) / SR
    env = np.minimum(1, t / 0.012) * np.exp(-t / 0.035)
    return bp(rng.uniform(-1, 1, n), 4500, 11000) * env * vel * 0.8


def tamb(vel, rng):
    n = secs(0.25)
    t = np.arange(n) / SR
    j = sum(np.sin(2 * np.pi * rng.uniform(5500, 9500) * t) for _ in range(8)) / 8
    x = (j + rng.uniform(-1, 1, n) * 0.5) * np.exp(-t / 0.06)
    return hp(x, 4000) * vel


def sleigh(vel, rng):
    """A shake of sleigh bells: a cloud of small jingles."""
    n = secs(0.3)
    out = np.zeros(n)
    t = np.arange(secs(0.12)) / SR
    for _ in range(14):
        at = secs(rng.uniform(0, 0.06))
        f = rng.uniform(5200, 10500)
        j = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.51 * t)) * np.exp(-t / rng.uniform(0.02, 0.05))
        k = min(len(j), n - at)
        out[at:at + k] += j[:k] * rng.uniform(0.4, 1)
    return hp(out, 4500) * vel / 5


def crash(vel, rng):
    n = secs(2.2)
    t = np.arange(n) / SR
    x = _metal(n, rng, 2.3) * 0.5 + rng.uniform(-1, 1, n)
    x = hp(x, 3500)
    return x * np.exp(-t / 0.7) * np.minimum(1, t / 0.002) * vel * 0.6


def ride(vel, rng):
    n = secs(0.9)
    t = np.arange(n) / SR
    ping = sum(np.sin(2 * np.pi * f * t) for f in [3100, 4520, 5810]) / 3
    x = hp(_metal(n, rng, 3.1) * 0.4 + rng.uniform(-1, 1, n) * 0.3, 5000) + ping * 0.5
    return x * np.exp(-t / 0.35) * vel * 0.5


def tom(vel, rng, pitch=1.0):
    n = secs(0.5)
    t = np.arange(n) / SR
    f = (100 + 80 * np.exp(-t / 0.05)) * pitch
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22)
    x += bp(rng.uniform(-1, 1, n), 300, 3000) * np.exp(-t / 0.03) * 0.3
    return drive(x, 1.2) * vel


def riser(seconds, rng):
    n = secs(seconds)
    t = np.arange(n) / SR
    k = t / seconds
    nz = rng.uniform(-1, 1, n)
    x = bp(nz, 800, 10000) * k ** 2 * 0.5
    x += osc("saw", 200 * 2 ** (2.5 * k), n) * 0.12 * k ** 3
    return hp(x, 300)


# --- Bass ---

def slap_bass(m, dur, vel, rng, art="thumb"):
    f = hz(m)
    pop = art == "pop"
    x = ks(f, dur + 0.05, rng, bright=0.95 if pop else 0.75, damp=0.993, pick=0.6 if pop else 0.3)
    t = np.arange(len(x)) / SR
    sub = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.6) * 0.6
    thump = lp(rng.uniform(-1, 1, len(x)), 900) * np.exp(-t / 0.006) * (0.4 if not pop else 0.2)
    y = x + sub + thump
    if art == "ghost":
        y = lp(y, 1200) * np.exp(-t / 0.03) * 0.5
    y = drive(lp(y, 4500 if pop else 3000), 1.5)
    y *= adsr(len(y), a=0.001, d=0.05, s=0.9, r=0.03, gate=secs(dur))
    return fade_out(y) * vel


def pick_bass(m, dur, vel, rng):
    f = hz(m)
    x = ks(f, dur + 0.05, rng, bright=0.45, damp=0.995, pick=0.4)
    t = np.arange(len(x)) / SR
    y = x * 0.9 + np.sin(2 * np.pi * f * t) * 0.7 * np.exp(-t / 0.9)
    y = drive(lp(y, 2400), 1.8)
    y *= adsr(len(y), a=0.002, d=0.08, s=0.85, r=0.03, gate=secs(dur))
    return fade_out(y) * vel


def synth_bass(m, dur, vel, rng):
    f = hz(m)
    n = secs(dur + 0.04)
    x = osc("saw", f, n) * 0.6 + osc("square", f * 0.5, n) * 0.4
    env = expdec(n, 0.08)
    y = sweep_lp(x, 300, 2400, env)
    y = drive(y, 1.5) * adsr(n, a=0.003, d=0.1, s=0.8, r=0.03, gate=secs(dur))
    return fade_out(y) * vel


# --- Guitars ---

def guitar_chop(chord, dur, vel, rng, mute=True, down=True):
    """A strummed chord on a clean electric guitar: 6 ms between strings."""
    notes = sorted(chord) if down else sorted(chord, reverse=True)
    n = secs(dur + 0.15)
    out = np.zeros(n)
    for i, m in enumerate(notes):
        at = secs(0.006 * i)
        s = ks(hz(m), dur + 0.15, rng, bright=0.8, damp=0.985 if mute else 0.997, pick=0.3)
        out[at:] += s[: n - at] * (0.9 ** i)
    out = hp(out, 180)
    out = peak_eq(out, 2500, 4, 1.0)
    out *= adsr(n, a=0.001, d=0.03, s=0.9, r=0.04, gate=secs(dur))
    return fade_out(out) * vel / len(notes) * 1.8


def scratch(vel, rng):
    """A muted strum: the funk scratch."""
    n = secs(0.05)
    t = np.arange(n) / SR
    return bp(rng.uniform(-1, 1, n), 800, 4000) * np.exp(-t / 0.012) * vel * 0.6


def power_chord(m, dur, vel, rng, mute=True):
    n = secs(dur + 0.1)
    out = np.zeros(n)
    for k, iv in enumerate([0, 7, 12]):
        s = ks(hz(m + iv), dur + 0.1, rng, bright=0.7, damp=0.98 if mute else 0.996, pick=0.4)
        out += s[:n]
    out = drive(hp(out, 90) * 3.0, 4.0)
    out = lp(out, 3600)
    out = peak_eq(out, 1800, 3, 0.8)
    out *= adsr(n, a=0.002, d=0.05, s=0.9, r=0.04, gate=secs(dur))
    return fade_out(out) * vel * 0.5


def twang(m, dur, vel, rng):
    """A bright single-coil lead with vibrato toward the end of long notes."""
    f = hz(m)
    n = secs(dur + 0.2)
    x = ks(f, dur + 0.4, rng, bright=0.95, damp=0.998, pick=0.5)
    # vibrato by re-reading the string at a wobbling rate
    v = vibrato(n, rate=5.2, cents=18 if dur > 0.4 else 0, delay=0.18, rng=rng)
    pos = np.cumsum(v)
    pos = pos[pos < len(x) - 1]
    y = np.interp(pos, np.arange(len(x)), x)
    y = np.pad(y, (0, n - len(y)))
    y = peak_eq(hp(y, 200), 3000, 5, 1.2)
    y = drive(y * 1.5, 1.6)
    y *= adsr(n, a=0.001, d=0.05, s=0.95, r=0.08, gate=secs(dur))
    return fade_out(y) * vel


def pluck(m, dur, vel, rng):
    x = ks(hz(m), dur + 0.3, rng, bright=0.85, damp=0.995, pick=0.2)
    x = hp(x, 250) * adsr(len(x), a=0.001, d=0.05, s=1.0, r=0.15, gate=secs(dur))
    return fade_out(x) * vel


# --- Keys ---

def epiano(chord, dur, vel, rng):
    """FM electric piano (a tine and its bark)."""
    notes = chord if isinstance(chord, (list, tuple)) else [chord]
    n = secs(dur + 0.6)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for m in notes:
        f = hz(m)
        idx = (1.2 + 1.5 * vel) * np.exp(-t / 0.35)
        mod = np.sin(2 * np.pi * f * t)
        body = np.sin(2 * np.pi * f * t + idx * mod)
        tine = np.sin(2 * np.pi * f * 14.0 * t) * np.exp(-t / 0.02) * 0.25 * vel
        out += (body + tine) * np.exp(-t / 1.6)
    out *= adsr(n, a=0.002, d=0.0, s=1.0, r=0.25, gate=secs(dur))
    return fade_out(lp(out, 6000)) * vel / max(1, len(notes)) ** 0.6


def piano(chord, dur, vel, rng):
    notes = chord if isinstance(chord, (list, tuple)) else [chord]
    n = secs(dur + 0.8)
    t = np.arange(n) / SR
    out = np.zeros(n)
    B = 0.0004
    for m in notes:
        f0 = hz(m)
        for det in (-0.6, 0.6):
            f = f0 * 2 ** (det / 1200)
            for k in range(1, 12):
                fk = f * k * np.sqrt(1 + B * k * k)
                if fk > SR * 0.45:
                    break
                amp = (1 / k ** 1.1) * (0.4 + 0.6 * vel) ** (k * 0.25)
                out += amp * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * np.exp(-t * (0.6 + 0.35 * k) * (f0 / 400) ** 0.3)
        out += hp(rng.uniform(-1, 1, n), 1500) * np.exp(-t / 0.004) * 0.15 * vel
    out *= adsr(n, a=0.001, d=0.0, s=1.0, r=0.2, gate=secs(dur))
    return fade_out(out) * vel * 0.35 / max(1, len(notes)) ** 0.6


def bells(m, dur, vel, rng):
    """Glockenspiel: bright inharmonic partials, quick decay."""
    f = hz(m)
    n = secs(max(dur, 0.2) + 0.9)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a, tau in [(1.0, 1.0, 0.9), (2.76, 0.45, 0.35), (5.40, 0.25, 0.15), (8.93, 0.12, 0.07)]:
        if f * r < SR * 0.45:
            out += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / tau)
    out += hp(rng.uniform(-1, 1, n), 5000) * np.exp(-t / 0.003) * 0.2
    return fade_out(out) * vel * 0.6


def organ(chord, dur, vel, rng):
    notes = chord if isinstance(chord, (list, tuple)) else [chord]
    n = secs(dur + 0.05)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for m in notes:
        f = hz(m)
        for r, a in [(0.5, 0.5), (1, 1), (2, 0.6), (3, 0.35), (4, 0.2)]:
            out += a * np.sin(2 * np.pi * f * r * t)
    out *= adsr(n, a=0.005, d=0.0, s=1.0, r=0.04, gate=secs(dur))
    return fade_out(out) * vel * 0.25 / max(1, len(notes)) ** 0.7


# --- Synths and horns ---

def supersaw(m, dur, vel, rng, voices=7, spread=18.0, cutoff=5500, attack=0.006, release=0.12, vib=True):
    """Detuned saw stack, returned stereo (2, n)."""
    f = hz(m)
    n = secs(dur + release + 0.05)
    out = np.zeros((2, n))
    v = vibrato(n, 5.6, 10, 0.25, rng) if vib and dur > 0.35 else 1.0
    for i in range(voices):
        d = spread * (i / (voices - 1) * 2 - 1) if voices > 1 else 0
        s = osc("saw", f * 2 ** (d / 1200) * v, n, rng.uniform(0, 1))
        p = (i / (voices - 1) * 2 - 1) if voices > 1 else 0
        out[0] += s * np.cos((p + 1) * np.pi / 4)
        out[1] += s * np.sin((p + 1) * np.pi / 4)
    out /= voices ** 0.6
    out = lp(out, cutoff)
    env = adsr(n, a=attack, d=0.15, s=0.8, r=release, gate=secs(dur))
    return out * env * vel


def brass(m, dur, vel, rng, stab=False):
    """Synth brass section: detuned saws, a blatty filter swell, a fall on stabs."""
    f = hz(m)
    n = secs(dur + 0.15)
    t = np.arange(n) / SR
    v = vibrato(n, 5.0, 8, 0.3, rng) if dur > 0.5 else 1.0
    fall = 1.0 if not stab else 2 ** (-np.clip((t - dur * 0.6) / 0.15, 0, 1) * 1.5 / 12)
    x = sum(osc("saw", f * 2 ** (c / 1200) * v * fall, n, rng.uniform(0, 1)) for c in (-9, 0, 8)) / 3
    swell = np.clip(t / 0.05, 0, 1) * np.exp(-t / (0.12 if stab else 0.5)) * 0.7 + 0.3
    y = sweep_lp(x, 900, 4200 * (0.7 + 0.3 * vel), swell)
    y = peak_eq(y, 1200, 3, 0.8)
    env = adsr(n, a=0.025 if not stab else 0.008, d=0.1, s=0.85, r=0.08, gate=secs(dur))
    return fade_out(y * env) * vel


def flute_lead(m, dur, vel, rng):
    """A breathy, whistly FM lead for verses."""
    f = hz(m)
    n = secs(dur + 0.12)
    t = np.arange(n) / SR
    v = vibrato(n, 5.4, 14, 0.22, rng)
    ph = np.cumsum(f * v) / SR
    x = np.sin(2 * np.pi * ph + 0.6 * np.exp(-t / 0.08) * np.sin(4 * np.pi * ph))
    x += 0.15 * np.sin(4 * np.pi * ph)
    breath = bp(rng.uniform(-1, 1, n), f, min(f * 4, 12000)) * 0.12
    y = (x + breath) * adsr(n, a=0.03, d=0.1, s=0.85, r=0.09, gate=secs(dur))
    return fade_out(y) * vel


def sax(m, dur, vel, rng):
    """A reedy lead: a saw-square blend through two formants, breath and vibrato."""
    f = hz(m)
    n = secs(dur + 0.12)
    v = vibrato(n, 5.0, 16, 0.25, rng)
    x = osc("saw", f * v, n) * 0.6 + osc("square", f * v, n) * 0.4
    y = bp(x, 450, 1100) * 1.4 + bp(x, 1400, 2800) * 0.9 + lp(x, 400) * 0.4
    y += bp(rng.uniform(-1, 1, n), 1500, 6000) * 0.05
    y = drive(y * 1.5, 1.4)
    y *= adsr(n, a=0.02, d=0.1, s=0.8, r=0.08, gate=secs(dur))
    return fade_out(y) * vel


def pad(chord, dur, vel, rng, cutoff=2400):
    """Warm string-synth pad (stereo)."""
    n = secs(dur + 0.55)
    out = np.zeros((2, n))
    for m in chord:
        s = supersaw(m, dur, 1.0, rng, voices=5, spread=12, cutoff=cutoff, attack=0.25, release=0.5, vib=False)
        k = min(n, s.shape[1])
        out[:, :k] += s[:, :k]
    return out * vel / max(1, len(chord)) ** 0.7
