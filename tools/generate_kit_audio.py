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


# --- Round 2: the living isle (docs/design/sound-round2.md) -----------------------

def bird_note(rng, f0, f1, seconds, vibrato=0.0, vib_hz=0.0, bend=1.0, harmonic=0.12):
    """One small-bird note: a pure tone gliding f0 -> f1 (the glide's curve
    `bend`), a quick swell and fall, a touch of second harmonic, an optional
    warble (`vibrato` as a share of the pitch at `vib_hz`)."""
    n = max(1, int(seconds * RATE))
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        u = i / n
        f = f0 + (f1 - f0) * (u ** bend)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(TAU * vib_hz * i / RATE)
        ph += TAU * f / RATE
        env = min(1.0, u / 0.12) * (1.0 - u) ** 1.3
        out[i] = env * (math.sin(ph) + harmonic * math.sin(2.0 * ph))
    return out


def chirp_take(rng):
    """A chirp: one to three quick notes, rising, falling or a hooked slur."""
    parts = []
    for _ in range(rng.choice([1, 1, 2, 2, 3])):
        f0 = rng.uniform(2600, 5200)
        kind = rng.random()
        if kind < 0.4:
            f1 = f0 * rng.uniform(1.15, 1.5)
        elif kind < 0.8:
            f1 = f0 * rng.uniform(0.6, 0.85)
        else:
            f1 = f0 * rng.uniform(0.95, 1.05)
        parts.append(bird_note(rng, f0, f1, rng.uniform(0.04, 0.11), rng.uniform(0.0, 0.03), rng.uniform(40, 90), rng.uniform(0.5, 2.0)))
        parts.append([0.0] * int(rng.uniform(0.03, 0.09) * RATE))
    return [v for p in parts for v in p]


def twitter_take(rng):
    """A twitter: a run of quick notes, a little pattern repeated and drifting
    in pitch, as a small bird chatters on a perch."""
    base = rng.uniform(3000, 5600)
    pattern = [(rng.uniform(0.8, 1.2), rng.uniform(0.7, 1.3)) for _ in range(rng.randint(1, 3))]
    count = rng.randint(4, 11)
    drift = rng.uniform(-0.25, 0.2)
    out = []
    for k in range(count):
        a, b = pattern[k % len(pattern)]
        f = base * (1.0 + drift * k / count)
        out += bird_note(rng, f * a, f * b, rng.uniform(0.025, 0.06), rng.uniform(0.0, 0.04), 70.0, 1.0)
        out += [0.0] * int(rng.uniform(0.012, 0.045) * RATE)
    return out


def trill_take(rng):
    """A trill: one pitch shaken fast, a warbler's or a junco's."""
    f = rng.uniform(3200, 5800)
    seconds = rng.uniform(0.5, 1.3)
    rate = rng.uniform(14, 28)
    n = int(seconds * RATE)
    out = [0.0] * n
    ph = 0.0
    glide = rng.uniform(-0.15, 0.12)
    for i in range(n):
        u = i / n
        ff = f * (1.0 + glide * u)
        ph += TAU * ff / RATE
        pulse = max(0.0, math.sin(TAU * rate * i / RATE)) ** 1.5
        env = min(1.0, u / 0.08) * min(1.0, (1.0 - u) / 0.2)
        out[i] = env * pulse * (math.sin(ph) + 0.1 * math.sin(2 * ph))
    return out


def whistle_take(rng):
    """A clear slow whistle or two: a thrush's or a titmouse's phrase."""
    out = []
    f = rng.uniform(1800, 3600)
    for _ in range(rng.randint(1, 3)):
        g = f * rng.uniform(0.8, 1.3)
        out += bird_note(rng, f, g, rng.uniform(0.18, 0.45), rng.uniform(0.005, 0.02), rng.uniform(5, 12), rng.uniform(0.6, 1.6), 0.06)
        out += [0.0] * int(rng.uniform(0.05, 0.15) * RATE)
        f = g * rng.uniform(0.85, 1.15)
    return out


def chirps():
    """Near birds' small talk: chirps (call notes), on the listener's isle."""
    for k in range(8):
        rng = random.Random('chirp-%d' % k)
        x = chirp_take(rng) + [0.0] * int(0.05 * RATE)
        write('chirp-%d' % (k + 1), lowpass(x, 9000), 0.7)


def twitters():
    """Near birds chattering on a perch: twitters and trills."""
    for k in range(6):
        rng = random.Random('twitter-%d' % k)
        x = (twitter_take(rng) if k % 3 != 2 else trill_take(rng)) + [0.0] * int(0.05 * RATE)
        write('twitter-%d' % (k + 1), lowpass(x, 9000), 0.7)


def wings():
    """Small wings: a flurry of beats as birds burst off a perch (the first
    takes one bird, the last a whole flock taking off together)."""
    for k in range(4):
        rng = random.Random('wings-%d' % k)
        seconds = 0.6 + 0.25 * k
        n = int(seconds * RATE)
        x = [0.0] * n
        for bird in range(1 + 2 * k):
            t = rng.uniform(0.0, 0.12 * k)
            rate = rng.uniform(14.0, 22.0)
            centre = rng.uniform(700, 1400)
            g = rng.uniform(0.5, 1.0)
            while t < seconds - 0.05:
                m = int(0.05 * RATE)
                burst = bandpass([v * math.sin(math.pi * i / m) ** 2 for i, v in enumerate(white(rng, m))], centre * rng.uniform(0.85, 1.15), 1.4)
                add(x, burst, g * math.exp(-t * 2.2), int(t * RATE))
                t += 1.0 / rate * rng.uniform(0.85, 1.2)
                rate *= 0.97
        write('wings-%d' % (k + 1), lowpass(x, 5000), 0.75)


def bird_chorus():
    """The isle's distant birds: many small singers far off over a seamless
    loop (every phrase laid modulo its length, so it wraps cleanly), dulled
    and softened by distance, a little room on them. The dawn chorus at
    full; a thin daytime bed at a low gain."""
    seconds = 30.0
    rng = random.Random('bird-chorus')
    n = int(seconds * RATE)
    x = [0.0] * n
    makers = [chirp_take, twitter_take, trill_take, whistle_take, whistle_take, twitter_take]
    # A few singers, each repeating its own kind of phrase at its own pace.
    for singer in range(16):
        make = rng.choice(makers)
        phrase_rng = random.Random('chorus-singer-%d' % singer)
        phrases = [make(phrase_rng) for _ in range(3)]
        far = rng.uniform(0.25, 1.0)
        cut = 1800 + 4200 * far
        gain = 0.15 + 0.6 * far
        t = rng.uniform(0.0, seconds)
        gap = rng.uniform(1.6, 5.5)
        made = 0
        while made < int(seconds / gap):
            p = lowpass(phrases[made % 3], cut)
            at = int(t * RATE) % n
            for i, v in enumerate(p):
                x[(at + i) % n] += v * gain
            t += gap * rng.uniform(0.7, 1.4)
            made += 1
    # A little open air round them: a few circular echoes (wraps cleanly).
    y = x[:]
    for delay, g in [(0.071, 0.22), (0.113, 0.18), (0.167, 0.14), (0.241, 0.1)]:
        d = int(delay * RATE)
        for i in range(n):
            y[i] += g * x[(i - d) % n]
    write('bird-chorus-loop', highpass(y, 900), 0.7, edge=False)


def insect_hum():
    """Bees about the flowers: a few buzzes, each wandering in pitch and in
    nearness, soft and warm; a faint high hum of smaller flies."""
    seconds, fade = 12.0, 1.0
    rng = random.Random('insect-hum')
    total = seconds + fade
    n = int(total * RATE)
    x = [0.0] * n
    for bee in range(4):
        f = rng.uniform(170, 250)
        pw = wander(rng, total, rng.uniform(0.5, 1.2))
        near = wander(rng, total, rng.uniform(0.15, 0.4))
        ph = 0.0
        for i in range(n):
            t = i / RATE
            ph += TAU * f * (1.0 + 0.07 * pw(t)) / RATE
            # A buzz: a rich, slightly clipped wave.
            s = math.sin(ph) + 0.5 * math.sin(2 * ph + 0.3) + 0.3 * math.sin(3 * ph + 0.9) + 0.18 * math.sin(5 * ph)
            g = max(0.0, 0.35 + 0.65 * near(t)) ** 2
            x[i] += s * g * 0.3
    flies = bandpass(white(rng, n), lambda t: 620.0, 14.0)
    x = [v + 0.25 * f for v, f in zip(x, flies)]
    x = lowpass(lowpass(x, 2600), 3200)
    write('insect-hum-loop', seamless(highpass(x, 90), int(fade * RATE)), 0.6, edge=False)


def fall_roar():
    """A waterfall's body heard from near: a broad, deep, steady roar with a
    slow surge, the spray's hiss over it."""
    seconds, fade = 12.0, 1.0
    rng = random.Random('fall-roar')
    n = int((seconds + fade) * RATE)
    noise = pink(rng, n)
    body = lowpass(lowpass(noise, 900), 1100)
    mid = bandpass(noise, 520.0, 0.8)
    spray = highpass(lowpass(white(rng, n), 7000), 2500)
    surge = wander(rng, seconds + fade, 0.35)
    flick = wander(rng, seconds + fade, 3.0)
    x = [(1.0 * b + 0.6 * m) * (0.82 + 0.18 * surge(i / RATE)) + 0.12 * s * (0.75 + 0.25 * flick(i / RATE))
         for i, (b, m, s) in enumerate(zip(body, mid, spray))]
    write('fall-roar-loop', seamless(highpass(x, 40), int(fade * RATE)), 0.75, edge=False)


def fall_spill():
    """A thin spill or channel falling into a pool: a splashy patter and
    gurgle, brighter and lighter than a fall's roar."""
    seconds, fade = 10.0, 0.8
    rng = random.Random('fall-spill')
    n = int((seconds + fade) * RATE)
    noise = pink(rng, n)
    patter = bandpass(noise, lambda t: 1500.0, 0.7)
    lev = wander(rng, seconds + fade, 4.0)
    x = [p * (0.7 + 0.3 * lev(i / RATE)) for i, p in enumerate(patter)]
    # Bubbles: little rising tones where drops plunge in.
    t = 0.0
    while t < seconds + fade - 0.1:
        f = rng.uniform(350, 1100)
        m = int(rng.uniform(0.02, 0.06) * RATE)
        bub = [math.sin(TAU * f * (1.0 + 2.0 * i / m) * i / RATE) * math.exp(-i / m * 3.0) for i in range(m)]
        add(x, bub, rng.uniform(0.05, 0.18), int(t * RATE))
        t += rng.uniform(0.01, 0.08)
    write('fall-spill-loop', seamless(highpass(lowpass(x, 6000), 120), int(fade * RATE)), 0.7, edge=False)


def rope_creaks():
    """A rope under a body's weight: a fibrous, low stick-slip groan where it
    runs over its iron ring, and the strands' rasp."""
    for k in range(4):
        rng = random.Random('rope-creak-%d' % k)
        seconds = rng.uniform(0.4, 0.75)
        n = int(seconds * RATE)
        pulses = [0.0] * n
        r0 = rng.uniform(22.0, 40.0)
        r1 = r0 * rng.uniform(0.7, 1.5)
        t = 0.0
        while t < seconds:
            u = t / seconds
            at = int(t * RATE)
            if at < n:
                pulses[at] += rng.uniform(0.4, 1.0) * math.sin(math.pi * u) ** 0.8
            t += 1.0 / (r0 + (r1 - r0) * u) * rng.uniform(0.8, 1.2)
        x = [0.0] * n
        for f, q, g in [(rng.uniform(220, 280), 5.0, 1.0), (rng.uniform(520, 640), 6.0, 0.55), (rng.uniform(1100, 1300), 7.0, 0.25)]:
            add(x, bandpass(pulses, f, q), g)
        rasp = bandpass(white(rng, n), 2200.0, 1.2)
        env = [math.sin(math.pi * i / n) ** 1.5 for i in range(n)]
        add(x, mul(rasp, env), 0.05)
        write('rope-creak-%d' % (k + 1), lowpass(x, 3500), 0.8)


def rope_whips():
    """A rope let go: a quick whip-crack of the slack end and the line's
    low thrum as it swings free."""
    for k in range(3):
        rng = random.Random('rope-whip-%d' % k)
        n = int(0.55 * RATE)
        crack = bandpass([v * e for v, e in zip(white(rng, n), envelope(n, 0.003, 55.0))], lambda t: 3200.0 - 2000.0 * min(1.0, t / 0.06), 1.3)
        thrum = [0.0] * n
        f = rng.uniform(85, 115)
        for i in range(n):
            t = i / RATE
            thrum[i] = math.sin(TAU * f * t + 0.4 * math.sin(TAU * 7.0 * t)) * min(1.0, t / 0.01) * math.exp(-t * 7.0)
        swish = bandpass([v * math.sin(math.pi * min(1.0, i / (0.2 * RATE))) ** 2 if i < 0.2 * RATE else 0.0 for i, v in enumerate(pink(rng, n))], 900.0, 1.2)
        x = [1.0 * c + 0.35 * th + 0.5 * s for c, th, s in zip(crack, thrum, swish)]
        write('rope-whip-%d' % (k + 1), soft(x, 1.3), 0.8)


def resonant_lowpass(x, freq, q):
    """RBJ low-pass with resonance `q`."""
    w = TAU * freq / RATE
    alpha = math.sin(w) / (2.0 * q)
    cw = math.cos(w)
    a0 = 1.0 + alpha
    b0 = (1.0 - cw) / 2.0 / a0
    b1 = (1.0 - cw) / a0
    b2 = b0
    a1 = -2.0 * cw / a0
    a2 = (1.0 - alpha) / a0
    out = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, y
        out[i] = y
    return out


# The Electron Zenscape's crickets (zenscape/audio.js tickCrickets): a sine
# at about 4.5 kHz gated into 3 or 4 pulses 0.055 s apart, each opening over
# 8 ms and closing from 28 ms with an 8 ms time constant. Cold stretches the
# pulse period (and the gap, which kit_audio.gd schedules) by 1 + 1.6 cold;
# a take for each pulse count at each of these stretches. The voice's own
# pitch (4100 to 5000 Hz) is its player's pitch_scale over CRICKET_HZ.
CRICKET_HZ = 4500.0
CRICKET_SLOW = [1.0, 1.5, 2.0, 2.6]


def crickets():
    for si, slow in enumerate(CRICKET_SLOW):
        for pulses in (3, 4):
            period = 0.055 * slow
            n = int((pulses * period + 0.08) * RATE)
            x = [0.0] * n
            for i in range(n):
                t = i / RATE
                k = int(t / period)
                if k >= pulses:
                    pt = t - (pulses - 1) * period
                else:
                    pt = t - k * period
                if pt < 0.008:
                    g = pt / 0.008
                elif pt < 0.028:
                    g = 1.0
                else:
                    g = math.exp(-(pt - 0.028) / 0.008)
                x[i] = g * math.sin(TAU * CRICKET_HZ * t)
            write('cricket-%d-%d' % (pulses, si + 1), x, 0.8)


# Its frogs (audio.js tickFrogs): a low sawtooth through a resonant low-pass
# (480 Hz, Q 3), gated in a ratchet of 6 to 10 pulses 0.042 to 0.052 s apart
# (opening over 6 ms, closing from 20 ms, tau 8 ms), the pitch climbing 1.3x
# through it. Six frogs, each its own base pitch (85 to 155 Hz).
def frog_croaks():
    for k in range(6):
        rng = random.Random('frog-croak-%d' % k)
        base = 85.0 + 70.0 * k / 5.0 + rng.uniform(-5, 5)
        pulses = rng.randint(6, 10)
        period = rng.uniform(0.042, 0.052)
        length = pulses * period
        n = int((length + 0.08) * RATE)
        saw = [0.0] * n
        gate = [0.0] * n
        ph = 0.0
        for i in range(n):
            t = i / RATE
            f = base * (1.0 + 0.3 * min(1.0, t / length))
            ph = (ph + f / RATE) % 1.0
            saw[i] = 2.0 * ph - 1.0
            j = min(int(t / period), pulses - 1)
            pt = t - j * period
            if pt < 0.006:
                g = pt / 0.006
            elif pt < 0.02:
                g = 1.0
            else:
                g = math.exp(-(pt - 0.02) / 0.008)
            gate[i] = g
        x = mul(resonant_lowpass(saw, 480.0, 3.0), gate)
        write('frog-%d' % (k + 1), highpass(x, 50), 0.8)


TAKES = [air_rush, air_whistle, air_howl, engine, engine_start, wheel_rumble, skid, flutter,
         wire_sing, thin_wind, cloud_hush, thumps, creaks, ticks, swishes, whooshes,
         sail_pops, sail_folds, grabs,
         chirps, twitters, wings, bird_chorus, insect_hum, fall_roar, fall_spill, rope_creaks, rope_whips, crickets, frog_croaks]

if __name__ == '__main__':
    only = sys.argv[1] if len(sys.argv) > 1 else ''
    for take in TAKES:
        if only in take.__name__ or only in take.__name__.replace('_', '-'):
            take()
