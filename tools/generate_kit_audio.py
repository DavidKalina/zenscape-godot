"""Bake the kit isle's sound (docs/design/sound-round1.md) into assets/audio/kit/.

Stdlib only, deterministic (every take seeded by its name). Nothing here is a
recording: every loop and one-shot is noise, filters and sines. The loops are
seamless (their tail cross-faded into their head); scripts/kit_isle/kit_audio.gd
plays them looping and drives their gain, pitch and bus filter live.

    python3 tools/generate_kit_audio.py            # everything
    python3 tools/generate_kit_audio.py engine     # only takes whose name has "engine"

Loops: air-rush, air-whistle, air-howl, engine, wheel-rumble, skid, flutter,
wire-sing, thin-wind, cloud-hush. One-shots: thump-N, creak-N, tick-N, swish-N,
whoosh-N, sail-pop-N, sail-fold-N, grab-N, engine-start. Round 3's beasts
(docs/design/sound-round3.md): dragon-beat/up/call/slam/inhale/exhale,
dragon-growl, stone-grind, rock-debris, gale-howl, buffet, wind-slam,
serpent-scales/hum/breath (`python3 tools/generate_kit_audio.py dragon`
bakes the dragon_* takes, `serpent` the serpent's). The rival race's beats:
race-count, race-go, race-win, race-lose (`race_cues`).
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


# --- Round 3: the beasts (docs/design/sound-round3.md) -------------------------
# The sky dragon (scripts/sky_dragon.gd) and the rune serpent
# (scripts/rune_serpent.gd), played by scripts/kit_isle/kit_audio_beasts.gd.
# Big, slow and old: deep and soft-edged, nothing sharp or snarling.

def pulse_train(rng, n, f0, jitter=0.02, width=0.004, rough=0.0):
    """A throat's buzz: a decaying click each period of `f0(t)` (Hz), the
    period jittered, every other pulse weaker by `rough` (a growl's
    subharmonic)."""
    out = [0.0] * n
    k = 0
    decay = 1.0 / max(width, 1e-4)
    shape = [math.exp(-j / RATE * decay) for j in range(int(width * 6 * RATE))]
    i = 0
    while i < n:
        t = i / RATE
        period = RATE / max(f0(t), 5.0) * (1.0 + rng.uniform(-jitter, jitter))
        g = (1.0 - (rough if k % 2 else 0.0)) * rng.uniform(0.85, 1.0)
        for j in range(min(len(shape), n - i)):
            out[i + j] += g * shape[j]
        i += max(1, int(period))
        k += 1
    return out


def dragon_wingbeats():
    """The dragon's downstroke: a vast, slow whump of air pressed down, the
    membrane drawn taut with a deep soft boom, a sub drop under it all. Its
    peak sits about 0.35 s in (kit_audio_beasts.gd fires it ahead of the
    stroke's middle)."""
    for k in range(4):
        rng = random.Random('dragon-beat-%d' % k)
        seconds = 1.6
        n = int(seconds * RATE)
        peak = rng.uniform(0.32, 0.38)
        f0 = rng.uniform(34.0, 44.0)
        x = [0.0] * n
        ph = 0.0
        for i in range(n):
            t = i / RATE
            ph += TAU * f0 * (1.0 - 0.3 * min(1.0, max(0.0, t - peak) * 2.0)) / RATE
            rise = min(1.0, t / peak) ** 2.0
            x[i] = math.sin(ph) * rise * math.exp(-max(0.0, t - peak) * 4.5)
        noise = pink(rng, n)
        push = lowpass(lowpass(noise, 420), 700)
        env = [(min(1.0, (i / RATE) / peak) ** 2.5) * math.exp(-max(0.0, i / RATE - peak) * 3.2) for i in range(n)]
        add(x, mul(push, env), 2.6)
        boom = [0.0] * n
        fb = rng.uniform(95.0, 125.0)
        for i in range(n):
            t = i / RATE - peak + 0.03
            if t > 0:
                boom[i] = math.sin(TAU * fb * t) * min(1.0, t / 0.02) * math.exp(-t * 11.0)
        add(x, boom, 0.45)
        # The air spilling off the trailing edge, a little higher.
        spill = bandpass(noise, lambda t: 380.0 + 200.0 * max(0.0, t - peak), 1.3)
        env2 = [math.sin(math.pi * min(1.0, max(0.0, i / RATE - peak * 0.6) / 0.9)) ** 2 for i in range(n)]
        add(x, mul(spill, env2), 0.5)
        # What small speakers hear: the leather catching the air, a hard
        # swell of low-mid whoosh snapping off at the peak, and a thump an
        # octave and a half over the sub so the beat reads as a beat.
        catch = bandpass(noise, lambda t: 140.0 + 260.0 * min(1.0, t / peak), 1.1)
        env3 = [(min(1.0, (i / RATE) / peak) ** 4.0) * math.exp(-max(0.0, i / RATE - peak) * 9.0) for i in range(n)]
        add(x, mul(catch, env3), 3.2)
        thump = [0.0] * n
        ft = f0 * 2.0
        for i in range(n):
            t = i / RATE - peak + 0.02
            if t > 0:
                thump[i] = math.sin(TAU * ft * (1.0 - 0.25 * min(1.0, t * 4.0)) * t) * min(1.0, t / 0.008) * math.exp(-t * 7.0)
        add(x, thump, 0.9)
        write('dragon-beat-%d' % (k + 1), soft(highpass(x, 22), 2.0), 0.9)


def dragon_upstrokes():
    """The upstroke: the wings drawn up and folded at the wrist, the
    membrane rustling and fluttering, lighter and airier than the beat."""
    for k in range(3):
        rng = random.Random('dragon-up-%d' % k)
        seconds = rng.uniform(0.9, 1.2)
        n = int(seconds * RATE)
        noise = pink(rng, n)
        lo = rng.uniform(380, 520)
        hi = rng.uniform(900, 1300)
        band = bandpass(noise, lambda t: lo + (hi - lo) * math.sin(math.pi * min(1.0, t / seconds)), 1.2)
        rate = rng.uniform(11.0, 16.0)
        wob = wander(rng, seconds, 6.0)
        env = [math.sin(math.pi * i / n) ** 1.6 * (0.55 + 0.45 * abs(math.sin(math.pi * rate * i / RATE + 0.6 * wob(i / RATE)))) for i in range(n)]
        x = mul(band, env)
        low = lowpass(noise, 260)
        add(x, [v * math.sin(math.pi * i / n) ** 2 for i, v in enumerate(low)], 1.2)
        write('dragon-up-%d' % (k + 1), lowpass(x, 3500), 0.75)


def dragon_calls():
    """Its call: long and low, a horn-like voice over a rough throat, rising
    into the call and sinking away, as old as the rock. Not a snarl: no
    rasping top, no bite. About 3.3 s, played as the jaw opens on a roar."""
    shapes = [(46.0, 70.0, 37.0), (41.0, 62.0, 33.0), (52.0, 78.0, 42.0)]
    for k in range(3):
        rng = random.Random('dragon-call-%d' % k)
        seconds = 3.3
        n = int(seconds * RATE)
        a, b, c = shapes[k]

        def f0(t, a=a, b=b, c=c):
            u = t / seconds
            if u < 0.35:
                return a + (b - a) * math.sin(math.pi * 0.5 * u / 0.35)
            return b + (c - b) * ((u - 0.35) / 0.65) ** 1.3
        src = pulse_train(rng, n, f0, jitter=0.05, width=0.006, rough=0.55)
        x = [0.0] * n
        add(x, bandpass(src, lambda t: 260.0 + 120.0 * math.sin(math.pi * min(1.0, t / seconds)), 4.0), 1.0)
        add(x, bandpass(src, lambda t: 620.0 + 160.0 * math.sin(math.pi * min(1.0, t / seconds)), 6.0), 0.55)
        add(x, bandpass(src, 1500.0, 5.0), 0.3)
        add(x, lowpass(src, 160), 1.1)
        # A sub an octave under the throat, felt in the chest.
        ph_sub = 0.0
        for i in range(n):
            ph_sub += TAU * f0(i / RATE) * 0.5 / RATE
            x[i] += 0.35 * math.sin(ph_sub)
        # A rasp riding the throat's pulses: breath torn through the voice.
        rasp = bandpass(pink(rng, n), 1700.0, 1.4)
        add(x, mul(rasp, [min(1.0, abs(v) * 3.0) for v in lowpass(src, 400)]), 0.45)
        # The horn: a few clean partials an octave over the throat, slow vibrato.
        ph = 0.0
        for i in range(n):
            t = i / RATE
            ph += TAU * f0(t) * 2.0 * (1.0 + 0.008 * math.sin(TAU * 4.5 * t)) / RATE
            x[i] += 0.16 * (math.sin(ph) + 0.4 * math.sin(2 * ph) + 0.18 * math.sin(3 * ph))
        add(x, bandpass(pink(rng, n), 520.0, 0.9), 0.25)
        env = [min(1.0, (i / RATE) / 0.45) ** 1.6 * (1.0 - max(0.0, (i / RATE - (seconds - 1.0)) / 1.0)) ** 1.5 for i in range(n)]
        write('dragon-call-%d' % (k + 1), soft(lowpass(mul(x, env), 4000), 2.0), 0.85)


def dragon_growl():
    """On the rim: a low rolling growl in the chest, breathing; seamless."""
    seconds, fade = 8.0, 0.8
    rng = random.Random('dragon-growl')
    n = int((seconds + fade) * RATE)
    w = wander(rng, seconds + fade, 0.6)
    src = pulse_train(rng, n, lambda t: 31.0 + 5.0 * w(t), jitter=0.06, width=0.008, rough=0.45)
    x = [0.0] * n
    add(x, bandpass(src, 230.0, 3.0), 1.0)
    add(x, bandpass(src, 520.0, 4.0), 0.35)
    add(x, lowpass(src, 120), 1.1)
    breath = wander(rng, seconds + fade, 0.25)
    x = [v * (0.6 + 0.4 * (0.5 + 0.5 * math.sin(TAU * i / RATE / 4.0))) * (0.85 + 0.15 * breath(i / RATE)) for i, v in enumerate(x)]
    write('dragon-growl-loop', seamless(highpass(lowpass(x, 1800), 25), int(fade * RATE)), 0.8, edge=False)


def stone_grind():
    """Stone dragged on stone under a great weight: a bed of crackle and
    grit in surges (stick and slip), a deep groan of the rock under it. The
    isle as the dragon tips it; pitched down, the serpent's ride rumble."""
    seconds, fade = 9.0, 0.8
    rng = random.Random('stone-grind')
    n = int((seconds + fade) * RATE)
    surge = wander(rng, seconds + fade, 0.8)
    grit = [0.0] * n
    i = 0
    while i < n:
        s = 0.5 + 0.5 * surge(i / RATE)
        grit[i] += rng.uniform(-1.0, 1.0) * (0.3 + 0.7 * s)
        i += max(1, int(rng.expovariate(220.0 + 900.0 * s) * RATE))
    x = [0.0] * n
    add(x, bandpass(grit, 700.0, 1.2), 1.0)
    add(x, bandpass(grit, 1900.0, 2.0), 0.4)
    groan_w = wander(rng, seconds + fade, 0.4)
    noise = pink(rng, n)
    add(x, bandpass(noise, lambda t: 70.0 * (1.0 + 0.2 * groan_w(t)), 6.0), 2.2)
    add(x, lowpass(noise, 120), 1.2)
    x = [v * (0.7 + 0.3 * surge(i / RATE)) for i, v in enumerate(x)]
    write('stone-grind-loop', seamless(highpass(lowpass(x, 4000), 30), int(fade * RATE)), 0.8, edge=False)


def rock_debris():
    """Stone breaking off a rim: a crack, then rocks knocking and tumbling
    away, thinning out, a dusty hiss and a low rumble under them."""
    for k in range(3):
        rng = random.Random('rock-debris-%d' % k)
        seconds = 2.4
        n = int(seconds * RATE)
        x = [0.0] * n
        add(x, bandpass([v * e for v, e in zip(white(rng, n), envelope(n, 0.001, 40.0))], rng.uniform(900, 1400), 1.0), 0.9)
        t = 0.02
        while t < seconds - 0.1:
            f = rng.uniform(500.0, 2200.0)
            d = rng.uniform(60.0, 110.0)
            m = int(0.06 * RATE)
            g = rng.uniform(0.2, 0.7) * math.exp(-t * 1.4)
            knock = [math.exp(-j / RATE * d) * (math.sin(TAU * f * j / RATE) + 0.5 * math.sin(TAU * f * 2.3 * j / RATE)) for j in range(m)]
            add(x, knock, g, int(t * RATE))
            t += rng.expovariate(14.0 * math.exp(-t * 0.9) + 2.0)
        noise = pink(rng, n)
        add(x, [v * math.exp(-i / RATE * 1.5) for i, v in enumerate(lowpass(noise, 140))], 1.6)
        add(x, [v * math.exp(-i / RATE * 2.2) for i, v in enumerate(highpass(noise, 2500))], 0.25)
        write('rock-debris-%d' % (k + 1), lowpass(x, 6000), 0.8)


def dragon_grip_rumbles():
    """It takes hold of a rim: no crash, a deep rolling rumble through the
    whole isle, as if the rock itself groaned under the weight. Swells in
    over a beat, rolls in slow surges, a few low crumbles in it, and dies
    away over seconds."""
    for k in range(2):
        rng = random.Random('dragon-grip-%d' % k)
        seconds = 4.5
        n = int(seconds * RATE)
        noise = pink(rng, n)
        roll = wander(rng, seconds, 2.2)
        x = [0.0] * n
        add(x, lowpass(lowpass(noise, 110), 160), 3.0)
        add(x, bandpass(noise, lambda t: 75.0 + 30.0 * roll(t), 2.5), 2.0)
        add(x, bandpass(noise, 190.0, 1.5), 0.6)
        f0 = rng.uniform(27.0, 33.0)
        ph = 0.0
        for i in range(n):
            ph += TAU * f0 * (1.0 + 0.04 * roll(i / RATE)) / RATE
            x[i] += 0.5 * math.sin(ph)
        # Low crumbles: stone settling deep in the isle, no bright cracks.
        t = 0.3
        while t < seconds - 1.0:
            m = int(0.25 * RATE)
            burst = lowpass([v * e for v, e in zip(white(rng, m), envelope(m, 0.01, 14.0))], 500)
            add(x, burst, rng.uniform(0.6, 1.2) * math.exp(-t * 0.5), int(t * RATE))
            t += rng.uniform(0.25, 0.7)
        env = [min(1.0, (i / RATE) / 0.35) ** 1.5 * math.exp(-max(0.0, i / RATE - 0.6) * 0.9)
               * (0.7 + 0.3 * (0.5 + 0.5 * roll(i / RATE))) for i in range(n)]
        write('dragon-grip-%d' % (k + 1), soft(highpass(mul(x, env), 20), 1.6), 0.9)


def dragon_slams():
    """It strikes the rim: a deep, heavy impact through the rock (felt more
    than heard), a crack, a short shudder."""
    for k in range(2):
        rng = random.Random('dragon-slam-%d' % k)
        seconds = 1.8
        n = int(seconds * RATE)
        x = [0.0] * n
        f0 = rng.uniform(30.0, 38.0)
        ph = 0.0
        for i in range(n):
            t = i / RATE
            ph += TAU * f0 * (1.0 - 0.35 * min(1.0, t * 3.0)) / RATE
            x[i] = math.sin(ph) * min(1.0, t / 0.006) * math.exp(-t * 3.2)
        noise = pink(rng, n)
        add(x, [v * math.exp(-i / RATE * 6.0) for i, v in enumerate(lowpass(noise, 380))], 2.4)
        add(x, bandpass([v * e for v, e in zip(white(rng, n), envelope(n, 0.001, 30.0))], 1100.0, 1.2), 0.5)
        shudder = [math.sin(TAU * 13.0 * i / RATE) * math.exp(-i / RATE * 4.0) for i in range(n)]
        add(x, mul(lowpass(noise, 200), shudder), 1.2)
        write('dragon-slam-%d' % (k + 1), soft(highpass(x, 20), 1.6), 0.9)


def gale_howl():
    """The dragon's gale passing: a rushing howl, hollow bands wavering over
    a broad roar, gusting hard; seamless."""
    seconds, fade = 8.0, 0.7
    rng = random.Random('gale-howl')
    n = int((seconds + fade) * RATE)
    noise = pink(rng, n)
    w1 = wander(rng, seconds + fade, 0.7)
    w2 = wander(rng, seconds + fade, 0.5)
    gust = wander(rng, seconds + fade, 1.1)
    a = bandpass(noise, lambda t: 240.0 * (1.0 + 0.25 * w1(t)), 5.0)
    b = bandpass(noise, lambda t: 520.0 * (1.0 + 0.2 * w2(t)), 6.0)
    broad = lowpass(noise, 2600)
    x = [(1.0 * p + 0.6 * q + 0.45 * r) * (0.6 + 0.4 * gust(i / RATE)) for i, (p, q, r) in enumerate(zip(a, b, broad))]
    write('gale-howl-loop', seamless(highpass(x, 40), int(fade * RATE)), 0.8, edge=False)


def buffets():
    """A gust striking the plane: a hollow knock through the airframe and
    its fabric drumming."""
    for k in range(3):
        rng = random.Random('buffet-%d' % k)
        seconds = 0.7
        n = int(seconds * RATE)
        x = [0.0] * n
        f0 = rng.uniform(65.0, 90.0)
        for i in range(n):
            t = i / RATE
            x[i] = math.sin(TAU * f0 * t) * min(1.0, t / 0.004) * math.exp(-t * 12.0)
        rate = rng.uniform(22.0, 30.0)
        drum = bandpass(white(rng, n), rng.uniform(700, 1000), 1.5)
        env = [abs(math.sin(math.pi * rate * i / RATE)) ** 3 * math.exp(-i / RATE * 7.0) for i in range(n)]
        add(x, mul(drum, env), 0.6)
        add(x, [v * math.exp(-i / RATE * 9.0) for i, v in enumerate(lowpass(pink(rng, n), 500))], 1.2)
        write('buffet-%d' % (k + 1), soft(x, 1.3), 0.85)


def wind_slams():
    """A wall of wind hitting: a burst of air that slams in and roars away,
    its top closing as it goes."""
    for k in range(2):
        rng = random.Random('wind-slam-%d' % k)
        seconds = 1.6
        n = int(seconds * RATE)
        noise = pink(rng, n)
        x = bandpass(noise, lambda t: 2600.0 * math.exp(-t * 2.2) + 350.0, 0.7)
        add(x, lowpass(noise, 200), 1.6)
        write('wind-slam-%d' % (k + 1), soft(mul(x, envelope(n, 0.04, 2.6, 0.7)), 1.2), 0.85)


def dragon_breaths():
    """On the rim: the long draw in (the tell, 2.1 s, rising to the blow) and
    the blow out (3.8 s): a vast breathy rush and hiss, a low throat under
    it. Air, not fire."""
    rng = random.Random('dragon-inhale')
    seconds = 2.1
    n = int(seconds * RATE)
    noise = pink(rng, n)
    x = bandpass(noise, lambda t: 260.0 + 900.0 * (t / seconds) ** 1.5, 1.4)
    add(x, lowpass(noise, 300), 0.7)
    env = [(i / n) ** 1.8 * min(1.0, (n - i) / (0.08 * RATE)) for i in range(n)]
    write('dragon-inhale', mul(x, env), 0.8)
    for k in range(2):
        rng = random.Random('dragon-exhale-%d' % k)
        seconds = 3.8
        n = int(seconds * RATE)
        noise = pink(rng, n)
        w = wander(rng, seconds, 1.4)
        x = bandpass(noise, lambda t: 520.0 * (1.0 + 0.2 * w(t)), 0.8)
        add(x, highpass(lowpass(white(rng, n), 7000), 2200), 0.18)
        add(x, lowpass(noise, 180), 1.0)
        src = pulse_train(rng, n, lambda t: 33.0, jitter=0.05, width=0.008, rough=0.4)
        add(x, bandpass(src, 200.0, 3.0), 0.4)
        env = []
        for i in range(n):
            t = i / RATE
            a = min(1.0, t / 0.35)
            a = a * a * (3 - 2 * a)
            r = max(0.0, (t - (seconds - 0.7)) / 0.7)
            env.append(a * (1.0 - r * r * (3 - 2 * r)) * (0.85 + 0.15 * w(t)))
        write('dragon-exhale-%d' % (k + 1), soft(mul(x, env), 1.15), 0.85)


def serpent_scales():
    """The serpent's stone scales: plates grinding over each other in a slow
    rolling rhythm as the body flows, the odd knock of one on the next, a
    rumble of weight; seamless."""
    seconds, fade = 8.0, 0.8
    rng = random.Random('serpent-scales')
    n = int((seconds + fade) * RATE)
    w = wander(rng, seconds + fade, 0.9)
    grit = [0.0] * n
    i = 0
    while i < n:
        t = i / RATE
        s = (0.5 + 0.5 * math.sin(TAU * t * 1.25) ** 2) * (0.7 + 0.3 * w(t))
        grit[i] += rng.uniform(-1.0, 1.0) * s
        i += max(1, int(rng.expovariate(150.0 + 700.0 * s) * RATE))
    x = [0.0] * n
    add(x, bandpass(grit, 520.0, 1.4), 1.0)
    add(x, bandpass(grit, 1300.0, 2.2), 0.35)
    t = 0.1
    while t < seconds + fade - 0.1:
        m = int(0.08 * RATE)
        f = rng.uniform(220.0, 380.0)
        add(x, [math.exp(-j / RATE * 45.0) * math.sin(TAU * f * j / RATE) for j in range(m)], rng.uniform(0.3, 0.7), int(t * RATE))
        t += rng.uniform(0.25, 0.7)
    add(x, lowpass(pink(rng, n), 90), 1.4)
    write('serpent-scales-loop', seamless(highpass(lowpass(x, 3500), 28), int(fade * RATE)), 0.8, edge=False)


def serpent_hum():
    """The runes' glow as sound: a deep resonant hum (55 Hz and its partials,
    two a hair apart so they beat slowly) with a faint glassy shimmer over
    it; every partial a whole number of cycles in the 10 s loop, so it seams
    clean."""
    seconds, fade = 10.0, 1.0
    rng = random.Random('serpent-hum')
    n = int((seconds + fade) * RATE)
    partials = [(55.0, 1.0), (55.3, 0.5), (110.0, 0.55), (165.1, 0.25), (220.4, 0.18), (329.6, 0.07),
                (880.0, 0.03), (880.6, 0.025), (1319.0, 0.015)]
    x = [0.0] * n
    for f, g in partials:
        lv = wander(rng, seconds + fade, 0.3, loop=seconds)
        ph0 = rng.uniform(0.0, TAU)
        w = TAU * f / RATE
        for i in range(n):
            x[i] += g * (0.75 + 0.25 * lv(i / RATE)) * math.sin(w * i + ph0)
    write('serpent-hum-loop', seamless(x, int(fade * RATE)), 0.7, edge=False)


def serpent_breaths():
    """The serpent's slow breath (its 5.2 s cycle: in for 2 s, out for
    2.5 s): deep, hollow, stone-throated."""
    for k in range(2):
        rng = random.Random('serpent-breath-%d' % k)
        seconds = 4.8
        n = int(seconds * RATE)
        noise = pink(rng, n)
        x = bandpass(noise, lambda t: 200.0 + 180.0 * min(1.0, t / 2.0) if t < 2.0 else 380.0 - 200.0 * min(1.0, (t - 2.0) / 2.5), 1.6)
        add(x, lowpass(noise, 160), 0.8)
        env = []
        for i in range(n):
            t = i / RATE
            if t < 2.0:
                e = 0.55 * math.sin(math.pi * 0.5 * t / 2.0) ** 2
            else:
                u = min(1.0, (t - 2.0) / 2.6)
                e = (0.55 + 0.45 * math.sin(math.pi * 0.5 * min(1.0, u * 4.0))) * (1.0 - u) ** 1.4
            env.append(e)
        write('serpent-breath-%d' % (k + 1), lowpass(mul(x, env), 2000), 0.75)


def bell(f0, seconds, decay, partials=((1.0, 1.0), (2.0, 0.45), (2.76, 0.3), (5.4, 0.12)), at=0.0):
    """A struck bell: inharmonic partials, the high ones dying first."""
    n = int(seconds * RATE)
    x = [0.0] * n
    for ratio, g in partials:
        d = decay * (0.6 + 0.4 * ratio)
        for i in range(int(at * RATE), n):
            t = i / RATE - at
            x[i] += g * math.exp(-t * d) * math.sin(TAU * f0 * ratio * t)
    return x


def race_cues():
    """The rival race's beats (scripts/endless/rival_race.gd): the count (a
    small struck bell), GO (a brighter bell over a rising breath), the win (a
    rising arpeggio that rings) and the loss (two falling, duller notes)."""
    rng = random.Random('race-count')
    x = bell(660.0, 0.5, 7.0)
    add(x, [v * math.exp(-i / RATE * 600.0) for i, v in enumerate(white(rng, len(x)))], 0.25)
    write('race-count', x, 0.75)
    rng = random.Random('race-go')
    x = bell(990.0, 1.3, 3.2)
    add(x, bell(495.0, 1.3, 2.6), 0.6)
    air = bandpass(white(rng, len(x)), 1400.0, 1.2)
    swell = envelope(len(x), 0.18, 3.5, 1.5)
    add(x, mul(air, swell), 0.5)
    write('race-go', soft(x, 1.1), 0.85)
    x = [0.0] * int(2.2 * RATE)
    for k, f in enumerate((660.0, 831.6, 990.0, 1320.0)):
        add(x, bell(f, 2.2 - 0.09 * k, 1.8), 0.8 if k < 3 else 1.0, int(0.09 * k * RATE))
    write('race-win', soft(x, 1.05), 0.85)
    x = [0.0] * int(1.4 * RATE)
    add(x, bell(440.0, 1.4, 3.0), 1.0)
    add(x, bell(330.0, 1.1, 2.6), 1.0, int(0.28 * RATE))
    write('race-lose', lowpass(x, 1800.0), 0.7)


TAKES = [air_rush, air_whistle, air_howl, engine, engine_start, wheel_rumble, skid, flutter,
         wire_sing, thin_wind, cloud_hush, thumps, creaks, ticks, swishes, whooshes,
         sail_pops, sail_folds, grabs,
         chirps, twitters, wings, bird_chorus, insect_hum, fall_roar, fall_spill, rope_creaks, rope_whips, crickets, frog_croaks,
         dragon_wingbeats, dragon_upstrokes, dragon_calls, dragon_growl, stone_grind, rock_debris, dragon_slams, dragon_grip_rumbles,
         gale_howl, buffets, wind_slams, dragon_breaths, serpent_scales, serpent_hum, serpent_breaths,
         race_cues]

if __name__ == '__main__':
    only = sys.argv[1] if len(sys.argv) > 1 else ''
    for take in TAKES:
        if only in take.__name__ or only in take.__name__.replace('_', '-'):
            take()
