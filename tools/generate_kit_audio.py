"""Bake the kit isle's sound (docs/design/sound-round1.md) into assets/audio/kit/.

Stdlib only, deterministic (every take seeded by its name). Nothing here is a
recording: every loop and one-shot is noise, filters and sines. The loops are
seamless (their tail cross-faded into their head); scripts/kit_isle/kit_audio.gd
plays them looping and drives their gain, pitch and bus filter live.

    python3 tools/generate_kit_audio.py            # everything
    python3 tools/generate_kit_audio.py engine     # only takes whose name has "engine"

Loops: air-rush, air-whistle, air-howl, engine, wheel-rumble, skid, flutter,
wire-sing, thin-wind, cloud-hush. One-shots: thump-N, creak-N, tick-N, swish-N,
whoosh-N, sail-pop-N, sail-fold-N, grab-N, engine-start.
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets/audio/kit'
RATE = 32000
TAU = math.tau


# --- Building blocks ---------------------------------------------------------

def white(rng, n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def pink(rng, n):
    """Paul Kellet's economy pink filter over white noise."""
    b0 = b1 = b2 = 0.0
    out = [0.0] * n
    for i in range(n):
        w = rng.uniform(-1.0, 1.0)
        b0 = 0.99765 * b0 + w * 0.0990460
        b1 = 0.96300 * b1 + w * 0.2965164
        b2 = 0.57000 * b2 + w * 1.0526913
        out[i] = (b0 + b1 + b2 + w * 0.1848) * 0.2
    return out


def lowpass(x, hz):
    k = 1.0 - math.exp(-TAU * hz / RATE)
    y = 0.0
    out = [0.0] * len(x)
    for i, v in enumerate(x):
        y += (v - y) * k
        out[i] = y
    return out


def highpass(x, hz):
    low = lowpass(x, hz)
    return [a - b for a, b in zip(x, low)]


def bandpass(x, freq, q, block=64):
    """RBJ band-pass (constant peak gain); `freq` a number or a function of
    the time (s), re-read every `block` samples."""
    out = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    b0 = b2 = a1 = a2 = 0.0
    for i, v in enumerate(x):
        if i % block == 0:
            f = freq(i / RATE) if callable(freq) else freq
            f = max(20.0, min(f, RATE * 0.45))
            w = TAU * f / RATE
            alpha = math.sin(w) / (2.0 * q)
            a0 = 1.0 + alpha
            b0 = alpha / a0
            b2 = -alpha / a0
            a1 = -2.0 * math.cos(w) / a0
            a2 = (1.0 - alpha) / a0
        y = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = v
        y2 = y1
        y1 = y
        out[i] = y
    return out


def wander(rng, seconds, rate_hz, loop=None):
    """A slow random curve in -1..1: smoothed random knots `rate_hz` a second.
    With `loop` (s) the knots repeat, so the curve is seamless over it."""
    count = max(2, int(seconds * rate_hz) + 3)
    if loop is not None:
        count = max(2, int(round(loop * rate_hz)))
    knots = [rng.uniform(-1.0, 1.0) for _ in range(count)]

    def at(t):
        u = t * rate_hz
        i = int(math.floor(u))
        f = u - i
        f = f * f * (3 - 2 * f)
        a = knots[i % count]
        b = knots[(i + 1) % count]
        return a + (b - a) * f
    return at


def seamless(x, fade):
    """The first len(x)-fade samples, the tail cross-faded (equal power) into
    the head, so it loops without a seam."""
    n = len(x) - fade
    out = x[:n]
    for i in range(fade):
        g = i / fade
        out[i] = x[i] * math.sin(g * math.pi * 0.5) + x[n + i] * math.cos(g * math.pi * 0.5)
    return out


def envelope(n, attack, decay, shape=1.0):
    """Rise over `attack` s, then exponential fall at `decay` per second."""
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        rise = min(1.0, t / max(attack, 1e-4))
        out[i] = (rise ** shape) * math.exp(-max(0.0, t - attack) * decay)
    return out


def write(name, x, peak=0.85, edge=True):
    top = max(1e-6, max(abs(v) for v in x))
    n = len(x)
    data = bytearray()
    for i, v in enumerate(x):
        v = v / top * peak
        if edge:
            # One-shots: a tiny swell in and a fade to nothing at the end.
            v *= min(1.0, i / (0.002 * RATE), (n - 1 - i) / (0.01 * RATE))
        data.extend(struct.pack('<h', int(max(-1.0, min(1.0, v)) * 32767)))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(bytes(data))
    print('wrote', name, '%.2fs' % (n / RATE))


def add(a, b, gain=1.0, at=0):
    for i, v in enumerate(b):
        j = at + i
        if j >= len(a):
            break
        a[j] += v * gain
    return a


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def soft(x, drive=1.2):
    t = math.tanh(drive)
    return [math.tanh(v * drive) / t for v in x]


# --- Loops ---------------------------------------------------------------------

def air_rush():
    """Broad breathy rush: pink noise breathing slowly (gusty), its top left
    open (the bus low-pass closes it live with speed)."""
    seconds, fade = 8.0, 0.5
    rng = random.Random('air-rush')
    n = int((seconds + fade) * RATE)
    noise = pink(rng, n)
    curve = wander(rng, seconds + fade, 0.9, loop=None)
    body = lowpass(noise, 5200)
    x = [v * (0.78 + 0.22 * curve(i / RATE)) for i, v in enumerate(body)]
    x = highpass(x, 70)
    write('air-rush-loop', seamless(x, int(fade * RATE)), 0.8, edge=False)


def air_whistle():
    """The wind singing past wires and edges: two narrow wavering bands."""
    seconds, fade = 8.0, 0.6
    rng = random.Random('air-whistle')
    n = int((seconds + fade) * RATE)
    noise = white(rng, n)
    w1 = wander(rng, seconds + fade, 0.7)
    w2 = wander(rng, seconds + fade, 0.5)
    a = bandpass(noise, lambda t: 880.0 * (1.0 + 0.05 * w1(t)), 28.0)
    b = bandpass(noise, lambda t: 1430.0 * (1.0 + 0.06 * w2(t)), 34.0)
    lev = wander(rng, seconds + fade, 0.6)
    x = [(0.9 * p + 0.55 * q) * (0.65 + 0.35 * lev(i / RATE)) for i, (p, q) in enumerate(zip(a, b))]
    write('air-whistle-loop', seamless(x, int(fade * RATE)), 0.7, edge=False)


def air_howl():
    """Air pouring through a gap: a hollow, wavering low band over breath."""
    seconds, fade = 8.0, 0.6
    rng = random.Random('air-howl')
    n = int((seconds + fade) * RATE)
    noise = pink(rng, n)
    w = wander(rng, seconds + fade, 0.45)
    hollow = bandpass(noise, lambda t: 300.0 * (1.0 + 0.12 * w(t)), 7.0)
    upper = bandpass(noise, lambda t: 640.0 * (1.0 + 0.1 * w(t + 3.0)), 9.0)
    breath = lowpass(noise, 1400)
    x = [1.0 * h + 0.45 * u + 0.25 * b for h, u, b in zip(hollow, upper, breath)]
    write('air-howl-loop', seamless(x, int(fade * RATE)), 0.75, edge=False)


def engine():
    """A small radial engine heard from behind and a little off: soft firing
    pulses at 44 Hz through a low body resonance, a blade beat, a breath of
    exhaust. 4 s holds a whole number of firings, so the beat loops too."""
    seconds, fade = 4.0, 0.25
    rng = random.Random('engine')
    fire = 44.0
    n = int((seconds + fade) * RATE)
    # Each cylinder (seven) fires a little differently, every cycle the same.
    cyl = [rng.uniform(0.75, 1.0) for _ in range(7)]
    pulses = [0.0] * n
    period = RATE / fire
    k = 0
    while True:
        at = int(k * period + rng.uniform(-0.6, 0.6))
        if at >= n:
            break
        g = cyl[k % 7]
        for j in range(int(0.012 * RATE)):
            if at + j >= n:
                break
            t = j / RATE
            pulses[at + j] += g * math.exp(-t * 420.0) * (1.0 if j else 0.5)
        k += 1
    body = bandpass(pulses, 130.0, 2.2)
    chest = bandpass(pulses, 310.0, 3.0)
    noise = pink(rng, n)
    exhaust = bandpass(noise, 520.0, 1.2)
    blade = [0.0] * n
    for i in range(n):
        t = i / RATE
        # Two blades at a quarter of the firing rate turn the sound over.
        blade[i] = 0.82 + 0.18 * math.sin(TAU * fire * 0.25 * t)
    x = [(1.0 * b + 0.35 * c + 0.05 * e) * bl for b, c, e, bl in zip(body, chest, exhaust, blade)]
    x = soft(lowpass(lowpass(x, 1800), 2400), 1.5)
    write('engine-loop', seamless(x, int(fade * RATE)), 0.8, edge=False)


def engine_start():
    """The engine coughing awake: a few uneven catches, then running at idle."""
    rng = random.Random('engine-start')
    seconds = 2.6
    n = int(seconds * RATE)
    pulses = [0.0] * n
    # Coughs: (time, firings, rate).
    t = 0.12
    for count, rate in [(3, 18.0), (2, 22.0), (5, 26.0)]:
        for k in range(count):
            at = int((t + k / rate + rng.uniform(-0.004, 0.004)) * RATE)
            g = rng.uniform(0.6, 1.0)
            for j in range(int(0.016 * RATE)):
                if at + j < n:
                    pulses[at + j] += g * math.exp(-j / RATE * 300.0)
        t += count / rate + rng.uniform(0.18, 0.3)
    # Then it catches, firing quicker and quicker up to idle.
    rate = 26.0
    while t < seconds:
        at = int(t * RATE)
        for j in range(int(0.012 * RATE)):
            if at + j < n:
                pulses[at + j] += rng.uniform(0.7, 1.0) * math.exp(-j / RATE * 380.0)
        rate = min(36.0, rate + 0.8)
        t += 1.0 / rate
    body = bandpass(pulses, 120.0, 2.0)
    chest = bandpass(pulses, 300.0, 3.0)
    noise = pink(rng, n)
    puff = bandpass(noise, 450.0, 1.0)
    env = [min(1.0, i / (0.05 * RATE)) for i in range(n)]
    x = [(b + 0.4 * c) + 0.04 * p * e for b, c, p, e in zip(body, chest, puff, env)]
    # The tail fades out under the running loop, which swells in over it.
    tail = int(0.6 * RATE)
    for i in range(tail):
        x[n - tail + i] *= math.cos(i / tail * math.pi * 0.5)
    x = soft(lowpass(x, 1800), 1.5)
    write('engine-start', x, 0.8)


def wheel_rumble():
    """Wheels rolling on turf: a low rumble, small bumps and a hiss of grass."""
    seconds, fade = 4.0, 0.3
    rng = random.Random('wheel-rumble')
    n = int((seconds + fade) * RATE)
    noise = pink(rng, n)
    low = lowpass(lowpass(noise, 220), 260)
    bumps = [0.0] * n
    t = 0.0
    while t < seconds + fade:
        at = int(t * RATE)
        g = rng.uniform(0.3, 1.0)
        for j in range(int(0.05 * RATE)):
            if at + j < n:
                bumps[at + j] += g * math.exp(-j / RATE * 60.0) * math.sin(TAU * 70.0 * j / RATE)
        t += rng.uniform(0.06, 0.25)
    hiss = bandpass(white(rng, n), 2600.0, 0.8)
    lev = wander(rng, seconds + fade, 3.0)
    x = [2.4 * l + 0.35 * b + 0.05 * h * (0.6 + 0.4 * lev(i / RATE)) for i, (l, b, h) in enumerate(zip(low, bumps, hiss))]
    write('wheel-rumble-loop', seamless(x, int(fade * RATE)), 0.8, edge=False)


def skid():
    """Tyres dragged sideways over turf: a torn-grass hiss, juddering, grit."""
    seconds, fade = 3.0, 0.3
    rng = random.Random('skid')
    n = int((seconds + fade) * RATE)
    noise = white(rng, n)
    band = bandpass(noise, 1300.0, 0.9)
    low = lowpass(pink(rng, n), 400)
    judder = wander(rng, seconds + fade, 18.0)
    x = [(0.7 * b + 0.8 * l) * (0.7 + 0.3 * judder(i / RATE)) for i, (b, l) in enumerate(zip(band, low))]
    # Grit: little ticks scattered through.
    for _ in range(int(60 * (seconds + fade))):
        at = rng.randrange(n)
        f = rng.uniform(1200, 2600)
        g = rng.uniform(0.05, 0.15)
        for j in range(int(0.006 * RATE)):
            if at + j < n:
                x[at + j] += g * math.exp(-j / RATE * 900.0) * math.sin(TAU * f * j / RATE)
    x = lowpass(x, 4500)
    write('skid-loop', seamless(x, int(fade * RATE)), 0.75, edge=False)


def flutter():
    """Cloth in a strong airflow: the sail's (and a falling coat's) flutter,
    beating quick and uneven over a soft rush."""
    seconds, fade = 4.0, 0.3
    rng = random.Random('flutter')
    n = int((seconds + fade) * RATE)
    noise = pink(rng, n)
    cloth = bandpass(noise, 700.0, 1.1)
    rush = lowpass(noise, 900)
    rate = wander(rng, seconds + fade, 1.5)
    phase = 0.0
    x = [0.0] * n
    for i in range(n):
        t = i / RATE
        phase += TAU * (13.0 + 4.0 * rate(t)) / RATE
        beat = max(0.0, math.sin(phase)) ** 3
        x[i] = cloth[i] * (0.25 + 0.95 * beat) + 0.35 * rush[i]
    write('flutter-loop', seamless(x, int(fade * RATE)), 0.75, edge=False)


def wire_sing():
    """The bracing wires singing under load (the knife edge, a hard turn): a
    breathy tone with partials, its pitch trembling."""
    seconds, fade = 4.0, 0.4
    rng = random.Random('wire-sing')
    n = int((seconds + fade) * RATE)
    noise = white(rng, n)
    w = wander(rng, seconds + fade, 4.0)
    lev = wander(rng, seconds + fade, 1.3)
    a = bandpass(noise, lambda t: 620.0 * (1.0 + 0.012 * w(t)), 60.0)
    b = bandpass(noise, lambda t: 1250.0 * (1.0 + 0.012 * w(t)), 70.0)
    c = bandpass(noise, lambda t: 1870.0 * (1.0 + 0.012 * w(t)), 80.0)
    x = [(1.0 * p + 0.5 * q + 0.25 * r) * (0.7 + 0.3 * lev(i / RATE)) for i, (p, q, r) in enumerate(zip(a, b, c))]
    write('wire-sing-loop', seamless(x, int(fade * RATE)), 0.6, edge=False)


def thin_wind():
    """High open sky: a thin, cold, airy wind, a faint whistle far off."""
    seconds, fade = 10.0, 1.0
    rng = random.Random('thin-wind')
    n = int((seconds + fade) * RATE)
    noise = pink(rng, n)
    air = bandpass(noise, 2400.0, 0.6)
    w = wander(rng, seconds + fade, 0.25)
    tone = bandpass(white(rng, n), lambda t: 2100.0 * (1.0 + 0.08 * w(t)), 40.0)
    swell = wander(rng, seconds + fade, 0.2)
    x = [(0.6 * a + 0.12 * b) * (0.6 + 0.4 * swell(i / RATE)) for i, (a, b) in enumerate(zip(air, tone))]
    write('thin-wind-loop', seamless(x, int(fade * RATE)), 0.6, edge=False)


def cloud_hush():
    """Inside the cloud sea: a soft, close, deep hush, slowly breathing."""
    seconds, fade = 10.0, 1.0
    rng = random.Random('cloud-hush')
    n = int((seconds + fade) * RATE)
    noise = pink(rng, n)
    low = lowpass(lowpass(noise, 280), 320)
    swell = wander(rng, seconds + fade, 0.15)
    x = [v * (0.7 + 0.3 * swell(i / RATE)) for i, v in enumerate(low)]
    write('cloud-hush-loop', seamless(x, int(fade * RATE)), 0.7, edge=False)


# --- One-shots -----------------------------------------------------------------

def thumps():
    """The wheels meeting the turf: a soft low drop, the frame's knock and a
    little rattle of struts."""
    for k in range(3):
        rng = random.Random('thump-%d' % k)
        n = int(0.6 * RATE)
        x = [0.0] * n
        f0 = rng.uniform(70.0, 85.0)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            phase += TAU * f0 * (1.0 - 0.45 * min(1.0, t * 8.0)) / RATE
            x[i] = math.sin(phase) * min(1.0, t / 0.003) * math.exp(-t * 14.0)
        knock = bandpass([v * e for v, e in zip(white(rng, n), envelope(n, 0.002, 45.0))], rng.uniform(240.0, 300.0), 3.0)
        add(x, knock, 1.6)
        for _ in range(rng.randint(3, 5)):
            at = int(rng.uniform(0.02, 0.14) * RATE)
            f = rng.uniform(380.0, 700.0)
            for j in range(int(0.04 * RATE)):
                if at + j < n:
                    t = j / RATE
                    x[at + j] += 0.12 * rng.uniform(0.5, 1.0) * math.exp(-t * 90.0) * math.sin(TAU * f * t)
        write('thump-%d' % (k + 1), soft(lowpass(x, 2500), 1.3), 0.85)


def creaks():
    """Wood under load: stick-slip pulses whose rate (the creak's pitch)
    glides, rung through the frame's resonances."""
    for k in range(6):
        rng = random.Random('creak-%d' % k)
        seconds = rng.uniform(0.35, 0.8)
        n = int(seconds * RATE)
        pulses = [0.0] * n
        r0 = rng.uniform(35.0, 70.0)
        r1 = r0 * rng.uniform(0.6, 1.6)
        t = 0.0
        while t < seconds:
            u = t / seconds
            at = int(t * RATE)
            if at < n:
                pulses[at] += rng.uniform(0.5, 1.0) * math.sin(math.pi * u) ** 0.7
            t += 1.0 / (r0 + (r1 - r0) * u) * rng.uniform(0.85, 1.15)
        x = [0.0] * n
        for f, q, g in [(rng.uniform(380, 480), 9.0, 1.0), (rng.uniform(850, 1050), 12.0, 0.6), (rng.uniform(1600, 1900), 14.0, 0.3)]:
            add(x, bandpass(pulses, f, q), g)
        write('creak-%d' % (k + 1), lowpass(x, 3000), 0.8)


def ticks():
    """A cooling engine's metal ticking: one small bright tick each."""
    for k in range(6):
        rng = random.Random('tick-%d' % k)
        n = int(0.09 * RATE)
        x = [0.0] * n
        for f, g, d in [(rng.uniform(2600, 3400), 1.0, 160.0), (rng.uniform(4300, 5400), 0.5, 220.0), (rng.uniform(900, 1300), 0.3, 120.0)]:
            for i in range(n):
                t = i / RATE
                x[i] += g * math.exp(-t * d) * math.sin(TAU * f * t)
        click = [v * math.exp(-i / RATE * 900.0) for i, v in enumerate(white(rng, n))]
        add(x, click, 0.4)
        write('tick-%d' % (k + 1), x, 0.7)


def swishes():
    """A body whirling through air (the twirl, a wall kick): a band of breath
    sweeping up and back down."""
    for k in range(4):
        rng = random.Random('swish-%d' % k)
        seconds = rng.uniform(0.28, 0.42)
        n = int(seconds * RATE)
        lo = rng.uniform(450, 650)
        hi = rng.uniform(1800, 2600)
        noise = pink(rng, n)
        band = bandpass(noise, lambda t: lo + (hi - lo) * math.sin(math.pi * min(1.0, t / seconds)) ** 1.5, 1.6)
        env = [math.sin(math.pi * min(1.0, i / n)) ** 1.8 for i in range(n)]
        write('swish-%d' % (k + 1), mul(band, env), 0.8)


def whooshes():
    """Rock rushing past: a swelling, falling rush with a dropping band (a
    Doppler-ish pass), soft in and long out."""
    for k in range(4):
        rng = random.Random('whoosh-%d' % k)
        seconds = rng.uniform(0.9, 1.3)
        n = int(seconds * RATE)
        peak = rng.uniform(0.38, 0.5)
        noise = pink(rng, n)
        f_hi = rng.uniform(1500, 2100)
        f_lo = rng.uniform(380, 520)
        band = bandpass(noise, lambda t: f_hi if t < peak * seconds else f_hi + (f_lo - f_hi) * min(1.0, (t - peak * seconds) / (0.4 * seconds)), 0.9)
        low = lowpass(noise, 500)
        env = [0.0] * n
        for i in range(n):
            u = i / n
            env[i] = (u / peak) ** 2.2 if u < peak else math.exp(-(u - peak) * 6.0)
        x = [(b + 0.6 * l) * e for b, l, e in zip(band, low, env)]
        write('whoosh-%d' % (k + 1), x, 0.8)


def sail_pops():
    """The pocket sail snapping open: a sharp cloth crack and the canopy's
    soft whump filling."""
    for k in range(3):
        rng = random.Random('sail-pop-%d' % k)
        n = int(0.5 * RATE)
        crack = bandpass([v * e for v, e in zip(white(rng, n), envelope(n, 0.001, 70.0))], rng.uniform(1700, 2300), 1.2)
        whump = [0.0] * n
        f = rng.uniform(95, 125)
        for i in range(n):
            t = i / RATE - 0.02
            if t > 0:
                whump[i] = math.sin(TAU * f * t) * min(1.0, t / 0.01) * math.exp(-t * 16.0)
        fill = bandpass([v * e for v, e in zip(pink(rng, n), envelope(n, 0.03, 9.0))], 600.0, 1.0)
        x = [1.0 * c + 0.7 * w + 0.6 * fl for c, w, fl in zip(crack, whump, fill)]
        write('sail-pop-%d' % (k + 1), soft(x, 1.2), 0.8)


def sail_folds():
    """The sail folding away: a rustle of cloth gathered in."""
    for k in range(2):
        rng = random.Random('sail-fold-%d' % k)
        seconds = 0.45
        n = int(seconds * RATE)
        noise = pink(rng, n)
        cloth = bandpass(noise, lambda t: 1400 - 700 * t / seconds, 1.0)
        rate = wander(rng, seconds, 20.0)
        env = [math.sin(math.pi * i / n) ** 1.2 * (0.6 + 0.4 * abs(rate(i / RATE))) for i in range(n)]
        write('sail-fold-%d' % (k + 1), mul(cloth, env), 0.8)


def grabs():
    """A gloved hand slapping onto stone: a dull pat and a scuff."""
    for k in range(4):
        rng = random.Random('grab-%d' % k)
        n = int(0.18 * RATE)
        noise = white(rng, n)
        pat = lowpass([v * e for v, e in zip(noise, envelope(n, 0.002, 60.0))], 1500)
        scuff = bandpass([v * e for v, e in zip(noise, envelope(n, 0.015, 30.0))], 2400.0, 1.0)
        thud = [math.sin(TAU * rng.uniform(140, 180) * i / RATE) * math.exp(-i / RATE * 45.0) for i in range(n)]
        x = [1.2 * p + 0.25 * s + 0.4 * t for p, s, t in zip(pat, scuff, thud)]
        write('grab-%d' % (k + 1), x, 0.8)


TAKES = [air_rush, air_whistle, air_howl, engine, engine_start, wheel_rumble, skid, flutter,
         wire_sing, thin_wind, cloud_hush, thumps, creaks, ticks, swishes, whooshes,
         sail_pops, sail_folds, grabs]

if __name__ == '__main__':
    only = sys.argv[1] if len(sys.argv) > 1 else ''
    for take in TAKES:
        if only in take.__name__ or only in take.__name__.replace('_', '-'):
            take()
