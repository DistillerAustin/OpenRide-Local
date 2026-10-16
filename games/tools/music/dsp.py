"""The game music renderer (#43, #55): DSP building blocks. Original code for this repo (Apache-2.0).

Everything is synthesised: oscillators from band-limited wavetables, Karplus-Strong strings,
FM electric piano and bells, additive piano, drum synthesis, convolution reverb from a
synthetic impulse response, chorus, delay, side-chain pump, bus compression and a limiter.
numpy + scipy only. Deterministic: every random draw comes from seeded generators.
"""
import numpy as np
from scipy import signal

SR = 32000
TABLE = 4096
_tables = {}


def hz(midi):
    return 440.0 * 2.0 ** ((np.asarray(midi, dtype=float) - 69.0) / 12.0)


def secs(n):
    return int(round(n * SR))


# --- Oscillators ---

def _saw_table(nh):
    if nh not in _tables:
        x = np.arange(TABLE) / TABLE
        t = np.zeros(TABLE)
        for k in range(1, nh + 1):
            t += np.sin(2 * np.pi * k * x) / k
        _tables[nh] = t * (2 / np.pi)
    return _tables[nh]


def _square_table(nh):
    key = -nh
    if key not in _tables:
        x = np.arange(TABLE) / TABLE
        t = np.zeros(TABLE)
        for k in range(1, nh + 1, 2):
            t += np.sin(2 * np.pi * k * x) / k
        _tables[key] = t * (4 / np.pi)
    return _tables[key]


def phase_of(freq, n, phase0=0.0):
    """Phase (cycles) for a constant or per-sample frequency."""
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return phase0 + np.cumsum(f) / SR


def osc(kind, freq, n, phase0=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    ph = phase_of(f, n, phase0)
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    fmax = float(f.max()) if n else 1.0
    nh = max(1, int(SR / 2 / max(fmax, 1.0)))
    nh = min(nh, 256)
    tab = _saw_table(nh) if kind == "saw" else _square_table(nh)
    idx = (ph % 1.0) * TABLE
    i0 = idx.astype(int)
    fr = idx - i0
    return tab[i0 % TABLE] * (1 - fr) + tab[(i0 + 1) % TABLE] * fr


def vibrato(n, rate=5.5, cents=12.0, delay=0.2, rng=None):
    t = np.arange(n) / SR
    ramp = np.clip((t - delay) / 0.25, 0.0, 1.0)
    ph = rng.uniform(0, 2 * np.pi) if rng is not None else 0.0
    return 2.0 ** (cents * ramp * np.sin(2 * np.pi * rate * t + ph) / 1200.0)


# --- Envelopes ---

def adsr(n, a=0.005, d=0.1, s=0.7, r=0.05, gate=None):
    """ADSR over n samples; the release starts at `gate` samples (default n - release)."""
    rs = secs(r)
    g = n - rs if gate is None else min(gate, n)
    env = np.ones(n) * s
    an, dn = secs(a), secs(d)
    t = np.arange(n)
    if an > 0:
        env[:an] = t[:an] / an
    d_end = min(g, an + dn)
    if dn > 0 and d_end > an:
        k = (t[an:d_end] - an) / dn
        env[an:d_end] = 1.0 - (1.0 - s) * k
    level = env[g - 1] if g > 0 else 0.0
    if rs > 0 and g < n:
        env[g:] = level * np.exp(-np.arange(n - g) / max(rs / 4.0, 1.0))
    return env


def expdec(n, tau, a=0.002):
    t = np.arange(n) / SR
    env = np.exp(-t / tau)
    an = secs(a)
    if an > 0:
        env[:an] *= np.arange(an) / an
    return env


def fade_out(x, ms=8):
    k = min(len(x), secs(ms / 1000))
    if k > 0:
        x[-k:] *= np.linspace(1, 0, k)
    return x


# --- Filters ---

def lp(x, f, order=2):
    f = min(f, SR * 0.45)
    b, a = signal.butter(order, f / (SR / 2), "low")
    return signal.lfilter(b, a, x, axis=-1)


def hp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), "high")
    return signal.lfilter(b, a, x, axis=-1)


def bp(x, lo, hi, order=2):
    hi = min(hi, SR * 0.45)
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x, axis=-1)


def peak_eq(x, f, gain_db, q=1.0):
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f / SR
    al = np.sin(w) / (2 * q)
    b = [1 + al * A, -2 * np.cos(w), 1 - al * A]
    a = [1 + al / A, -2 * np.cos(w), 1 - al / A]
    return signal.lfilter(b, a, x, axis=-1)


def shelf(x, f, gain_db, high=True):
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f / SR
    al = np.sin(w) / 2 * np.sqrt(2)
    c = np.cos(w)
    s = 1 if high else -1
    b0 = A * ((A + 1) + s * (A - 1) * c + 2 * np.sqrt(A) * al)
    b1 = -2 * s * A * ((A - 1) + s * (A + 1) * c)
    b2 = A * ((A + 1) + s * (A - 1) * c - 2 * np.sqrt(A) * al)
    a0 = (A + 1) - s * (A - 1) * c + 2 * np.sqrt(A) * al
    a1 = 2 * s * ((A - 1) - s * (A + 1) * c)
    a2 = (A + 1) - s * (A - 1) * c - 2 * np.sqrt(A) * al
    return signal.lfilter([b0 / a0, b1 / a0, b2 / a0], [1, a1 / a0, a2 / a0], x, axis=-1)


def sweep_lp(x, f0, f1, env):
    """A filter envelope as a crossfade between two static low-passes (env 1 = f1)."""
    return lp(x, f0) * (1 - env) + lp(x, f1) * env


def drive(x, amount):
    return np.tanh(x * amount) / np.tanh(amount)


# --- Karplus-Strong strings ---

def ks(freq, dur, rng, bright=0.6, damp=0.996, pick=0.0, mute=False):
    """A plucked string: a noise burst through a delay line with an averaging loss, rendered
    block by block (vectorised per period), then resampled to the exact pitch."""
    n = secs(dur)
    L = max(2, int(SR / freq))
    actual = SR / (L + 0.5)
    exc = rng.uniform(-1, 1, L)
    if bright < 0.99:
        exc = lp(exc, 400 + 9000 * bright, order=1)
    if pick > 0:
        exc[: max(1, L // 6)] += pick
    total = n + L + 4
    y = np.zeros(total + L + 2)
    y[1:L + 1] = exc
    g = 0.5 * damp
    pos = L + 1
    while pos < total:
        end = min(pos + L, total)
        k = end - pos
        y[pos:end] = g * (y[pos - L:pos - L + k] + y[pos - L - 1:pos - L - 1 + k])
        pos = end
    y = y[1:total]
    # to the exact pitch
    ratio = freq / actual
    m = min(n, int((len(y) - 2) / ratio))
    idx = np.arange(m) * ratio
    out = np.interp(idx, np.arange(len(y)), y)
    out = np.pad(out, (0, n - m))
    if mute:
        out *= np.exp(-np.arange(n) / (0.05 * SR))
    return out


# --- Stereo and mixing ---

def pan(x, p):
    """Constant-power pan: p -1 (left) .. +1 (right). x mono -> (2, n)."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)]) * np.sqrt(2) * 0.7071


def add(buf, x, at):
    """Adds x (mono or stereo) into stereo buf at sample `at` (clipped to the buffer)."""
    if x.ndim == 1:
        x = np.stack([x, x])
    n = x.shape[1]
    if at < 0:
        x = x[:, -at:]
        n = x.shape[1]
        at = 0
    end = min(buf.shape[1], at + n)
    if end > at:
        buf[:, at:end] += x[:, :end - at]


def chorus(x, rate=0.8, depth_ms=3.0, base_ms=12.0, mix=0.5, stereo=True):
    """Stereo chorus on a mono or stereo signal."""
    if x.ndim == 1:
        x = np.stack([x, x])
    n = x.shape[1]
    t = np.arange(n) / SR
    out = np.empty_like(x)
    for ch in range(2):
        ph = 0 if ch == 0 or not stereo else np.pi / 2
        d = (base_ms + depth_ms * np.sin(2 * np.pi * rate * t + ph)) * SR / 1000
        idx = np.arange(n) - d
        wet = np.interp(idx, np.arange(n), x[ch], left=0.0)
        out[ch] = x[ch] * (1 - mix * 0.5) + wet * mix
    return out


def delay(x, sec, feedback=0.35, mix=0.3, pingpong=True, lowpass=4000):
    if x.ndim == 1:
        x = np.stack([x, x])
    d = secs(sec)
    n = x.shape[1]
    wet = np.zeros_like(x)
    tap = lp(x.mean(axis=0), lowpass)
    g = 1.0
    for i in range(1, 7):
        g *= feedback if i > 1 else 1.0
        if d * i >= n or g < 0.02:
            break
        ch = (i % 2) if pingpong else None
        seg = tap[: n - d * i] * g
        if ch is None:
            wet[:, d * i:] += seg
        else:
            wet[ch, d * i:] += seg
    return x + wet * mix


def delay_wet(x, sec, feedback=0.35, lowpass=4000):
    """Only the echoes (ping-pong), for a send."""
    return delay(x, sec, feedback, 1.0, True, lowpass) - (x if x.ndim == 2 else np.stack([x, x]))


def reverb_ir(seconds=1.8, predelay=0.02, damp_hz=5000, seed=1, width=1.0):
    rng = np.random.default_rng(seed)
    n = secs(seconds)
    t = np.arange(n) / SR
    ir = np.zeros((2, n + secs(predelay)))
    for ch in range(2):
        noise = rng.standard_normal(n)
        lo = lp(noise, damp_hz)
        hi = noise - lo
        # highs die faster than lows
        body = lo * np.exp(-t * 6.9 / seconds) + hi * np.exp(-t * 6.9 / (seconds * 0.45))
        # early reflections
        for k in range(8):
            at = secs(rng.uniform(0.004, 0.06))
            body[at] += rng.uniform(0.3, 0.8) * (1 if rng.random() > 0.5 else -1)
        ir[ch, secs(predelay):] = body
    mid = ir.mean(axis=0)
    ir = mid + (ir - mid) * width
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


def convolve(x, ir):
    if x.ndim == 1:
        x = np.stack([x, x])
    out = np.stack([signal.oaconvolve(x[ch], ir[ch])[: x.shape[1]] for ch in range(2)])
    return out


# --- Dynamics ---

def env_follow(x, attack=0.003, release=0.08):
    m = np.abs(x).max(axis=0) if x.ndim == 2 else np.abs(x)
    a = np.exp(-1 / (attack * SR))
    r = np.exp(-1 / (release * SR))
    # attack-release follower: release smoothing via lfilter on the max-filtered level
    win = max(1, secs(attack))
    peak = signal.lfilter([1 - r], [1, -r], np.maximum.accumulate(m.reshape(1, -1), axis=0)[0])
    peak = np.maximum(peak, _max_filter(m, win))
    return peak


def _max_filter(x, w):
    from scipy.ndimage import maximum_filter1d
    return maximum_filter1d(x, size=w * 2 + 1, origin=0)


def compress(x, threshold_db=-18, ratio=3.0, attack=0.01, release=0.15, makeup_db=0.0):
    return x * compress_gain(x, threshold_db, ratio, attack, release, makeup_db)


def compress_gain(x, threshold_db=-18, ratio=3.0, attack=0.01, release=0.15, makeup_db=0.0):
    """The compressor's gain curve for x (apply it to x, or to stems that sum to x)."""
    m = np.abs(x).max(axis=0) if x.ndim == 2 else np.abs(x)
    rms = np.sqrt(signal.lfilter([1 - np.exp(-1 / (0.01 * SR))], [1, -np.exp(-1 / (0.01 * SR))], m ** 2))
    lvl = 20 * np.log10(np.maximum(rms, 1e-6))
    over = np.maximum(0.0, lvl - threshold_db)
    gr = over * (1 - 1 / ratio)
    # smooth the gain reduction: fast attack, slow release
    a = np.exp(-1 / (attack * SR))
    r = np.exp(-1 / (release * SR))
    g = _smooth_gr(gr, a, r)
    return 10 ** ((makeup_db - g) / 20)


def _smooth_gr(gr, a, r):
    # one-pole with separate attack/release: approximate by taking the max of a fast and slow
    fast = signal.lfilter([1 - a], [1, -a], gr)
    slow = signal.lfilter([1 - r], [1, -r], gr)
    return np.maximum(fast, slow)


def limit(x, ceiling_db=-1.0, lookahead=0.003, release=0.06):
    c = 10 ** (ceiling_db / 20)
    return np.clip(x * limit_gain(x, ceiling_db, lookahead, release), -c, c)


def limit_gain(x, ceiling_db=-1.0, lookahead=0.003, release=0.06):
    """The limiter's gain curve for x (apply it to x, or to stems that sum to x)."""
    c = 10 ** (ceiling_db / 20)
    m = np.abs(x).max(axis=0) if x.ndim == 2 else np.abs(x)
    w = secs(lookahead)
    pk = _max_filter(m, w)
    need = np.minimum(1.0, c / np.maximum(pk, 1e-9))
    r = np.exp(-1 / (release * SR))
    # gain: drop at once, recover with the release
    g = 1.0 - signal.lfilter([1 - r], [1, -r], 1.0 - need)
    g = np.minimum(g, need)
    # look-ahead: smooth the steps with a short window so drops start before the peak
    k = np.ones(w * 2 + 1) / (w * 2 + 1)
    g = np.minimum(np.convolve(g, k, mode="same"), 1.0)
    return np.minimum(g, _min_filter(need, w))


def _min_filter(x, w):
    from scipy.ndimage import minimum_filter1d
    return minimum_filter1d(x, size=w * 2 + 1)


def lufs(x):
    """Integrated loudness (BS.1770 K-weighting, gated), for a stereo or mono buffer."""
    if x.ndim == 1:
        x = np.stack([x, x]) * 0.7071
    y = shelf(x, 1500, 4.0, high=True)
    y = hp(y, 38, order=2)
    blk, hop = secs(0.4), secs(0.1)
    ms = []
    for i in range(0, y.shape[1] - blk, hop):
        ms.append(np.mean(y[:, i:i + blk] ** 2, axis=1).sum())
    ms = np.array(ms)
    if len(ms) == 0:
        return -70.0
    l = -0.691 + 10 * np.log10(np.maximum(ms, 1e-12))
    g = ms[l > -70]
    if len(g) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(g.mean()) - 10
    g2 = ms[(l > -70) & (l > rel)]
    return float(-0.691 + 10 * np.log10(g2.mean()))


def true_peak_db(x):
    up = signal.resample_poly(x, 4, 1, axis=-1)
    return float(20 * np.log10(np.abs(up).max() + 1e-12))
