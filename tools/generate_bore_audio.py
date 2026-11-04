"""Bake the burrower chase's bore sounds into assets/audio/bore/.

Stdlib only, deterministic (every take seeded by its name), the building
blocks of tools/generate_kit_audio.py. Nothing here is a recording: noise,
filters and sines, a touch stylised (a tuned stone ring in the crack, a
pitched grind) rather than library-real.

    python3 tools/generate_bore_audio.py            # everything
    python3 tools/generate_bore_audio.py crack      # only takes whose name has "crack"

A spur's eruption is three layers played together, each picked and pitched on
its own (scripts/endless/flight_sound.gd `bore_burst`), so no two spurs sound
alike:

- bore-thump-N: the low body blow, a falling sine with a dirt thud.
- bore-crack-N: the rock splitting, a hard snap, a burst of sub-cracks and a
  short ringing stone note.
- bore-debris-N: the tail, grit and pebbles raining off with a low settle.

bore-grind-N is the tell (the crack opening before the spur): a rising
rumble and a gritty grind, 0.8 s to its peak (bore_spurs.gd HOLD_S), and,
pitched down, a plug's warning.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_kit_audio as kit  # noqa: E402
from generate_kit_audio import RATE, TAU, white, pink, lowpass, highpass, bandpass, wander, envelope, add, mul, soft  # noqa: E402

kit.OUT = Path(__file__).resolve().parents[1] / 'assets/audio/bore'
write = kit.write


def sweep_sine(n, f0, f1, fall, decay, attack=0.003):
    """A sine falling from f0 toward f1 at `fall` per second, under an
    attack/decay envelope."""
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = f1 + (f0 - f1) * math.exp(-t * fall)
        ph += TAU * f / RATE
        out[i] = math.sin(ph) * min(1.0, t / attack) * math.exp(-t * decay)
    return out


def decay_noise(rng, n, decay, attack=0.001):
    return [v * min(1.0, (i / RATE) / attack) * math.exp(-(i / RATE) * decay) for i, v in enumerate(white(rng, n))]


def thumps():
    for k in range(4):
        rng = random.Random('bore-thump-%d' % k)
        n = int(1.1 * RATE)
        f0 = rng.uniform(120.0, 150.0)
        x = sweep_sine(n, f0, f0 * rng.uniform(0.38, 0.46), rng.uniform(9.0, 14.0), rng.uniform(4.2, 6.0))
        # A second, lower body a hair later: the ground giving.
        add(x, sweep_sine(n, f0 * 0.55, f0 * 0.3, 6.0, 4.0, 0.012), 0.6, int(rng.uniform(0.008, 0.02) * RATE))
        # The dirt's thud: low noise, quick.
        add(x, lowpass(lowpass(decay_noise(rng, n, 16.0, 0.002), 260.0), 260.0), 2.4)
        write('bore-thump-%d' % (k + 1), soft(lowpass(x, 1100.0), 2.2), 0.9)


def cracks():
    for k in range(4):
        rng = random.Random('bore-crack-%d' % k)
        n = int(0.75 * RATE)
        x = [0.0] * n
        # The snap: a hard bright click.
        add(x, highpass(decay_noise(rng, int(0.03 * RATE), 260.0, 0.0004), 1500.0), 1.6)
        # Sub-cracks, the split running through the rock.
        t = 0.004
        for j in range(rng.randint(4, 7)):
            t += rng.uniform(0.008, 0.045)
            f = rng.uniform(900.0, 3200.0)
            m = int(0.09 * RATE)
            c = bandpass(decay_noise(rng, m, rng.uniform(55.0, 110.0), 0.0006), f, rng.uniform(1.2, 2.5))
            add(x, c, rng.uniform(0.6, 1.2) * (1.0 - j * 0.08), int(t * RATE))
        # A short ringing stone note (stylised): two tuned partials.
        ring = rng.uniform(520.0, 820.0)
        m = int(0.5 * RATE)
        tone = [0.0] * m
        for i in range(m):
            s = i / RATE
            tone[i] = (math.sin(TAU * ring * s) + 0.45 * math.sin(TAU * ring * 2.76 * s)) * math.exp(-s * 11.0) * min(1.0, s / 0.002)
        add(x, tone, 0.22)
        # Body under the crack, a little lower.
        add(x, bandpass(decay_noise(rng, n, 14.0, 0.002), rng.uniform(280.0, 420.0), 0.9), 0.9)
        write('bore-crack-%d' % (k + 1), soft(x, 1.5), 0.85)


def debris():
    for k in range(4):
        rng = random.Random('bore-debris-%d' % k)
        seconds = rng.uniform(1.6, 2.1)
        n = int(seconds * RATE)
        x = [0.0] * n
        # The settle: a low rolling rumble, swelling in and dying.
        rumble = lowpass(lowpass(pink(rng, n), 220.0), 220.0)
        wob = wander(rng, seconds, 9.0)
        add(x, [v * (0.6 + 0.4 * wob(i / RATE)) * e for i, (v, e) in enumerate(zip(rumble, envelope(n, 0.05, 2.4, 1.0)))], 3.0)
        # Grit: many tiny clicks, thick at first and thinning out.
        g = 0.03
        while g < seconds - 0.05:
            life = g / seconds
            m = int(0.012 * RATE)
            grain = bandpass(decay_noise(rng, m, rng.uniform(300.0, 600.0), 0.0003), rng.uniform(1500.0, 5000.0), 1.5)
            add(x, grain, rng.uniform(0.5, 1.3) * (1.0 - life) ** 1.6, int(g * RATE))
            g += rng.expovariate(140.0 * (1.0 - life) ** 2 + 12.0)
        # Pebbles: fewer, lower knocks, a bounce or two each.
        for j in range(rng.randint(7, 12)):
            at = rng.uniform(0.06, seconds * 0.7)
            f = rng.uniform(220.0, 700.0)
            for b in range(rng.randint(1, 3)):
                m = int(0.05 * RATE)
                knock = bandpass(decay_noise(rng, m, 90.0, 0.0005), f * (1.0 + 0.15 * b), 4.0)
                add(x, knock, rng.uniform(0.5, 1.0) * (0.55 ** b) * (1.0 - at / seconds), int((at + b * rng.uniform(0.05, 0.11)) * RATE))
        write('bore-debris-%d' % (k + 1), soft(x, 1.3), 0.8)


def grinds():
    for k in range(3):
        rng = random.Random('bore-grind-%d' % k)
        seconds = 0.95
        n = int(seconds * RATE)
        peak = 0.78
        swell = [0.0] * n
        for i in range(n):
            t = i / RATE
            swell[i] = (t / peak) ** 1.8 if t < peak else math.exp(-(t - peak) * 30.0)
        # The rumble: low pink, lumpy.
        lump = wander(rng, seconds, 14.0)
        rumble = lowpass(lowpass(pink(rng, n), 160.0), 160.0)
        x = [v * (0.65 + 0.35 * lump(i / RATE)) * 6.0 for i, v in enumerate(rumble)]
        # The grind: rock on rock, a rising pitched band, chattering.
        f0 = rng.uniform(170.0, 230.0)
        chatter = wander(rng, seconds, 38.0)
        band = bandpass(white(rng, n), lambda t: f0 * (1.0 + 1.1 * (t / seconds) ** 1.5), 5.0)
        add(x, [v * max(0.0, 0.5 + 0.7 * chatter(i / RATE)) for i, v in enumerate(band)], 1.6)
        # A faint tuned groan inside it (stylised).
        groan = [math.sin(TAU * f0 * 0.5 * (1.0 + 0.5 * (i / n)) * (i / RATE)) for i in range(n)]
        add(x, groan, 0.08)
        # Grit ticks thickening toward the snap.
        g = 0.1
        while g < peak:
            m = int(0.01 * RATE)
            add(x, bandpass(decay_noise(rng, m, 500.0, 0.0003), rng.uniform(1800.0, 4500.0), 1.5), rng.uniform(0.1, 0.35) * (g / peak), int(g * RATE))
            g += rng.expovariate(20.0 + 90.0 * (g / peak))
        write('bore-grind-%d' % (k + 1), soft(mul(x, swell), 1.4), 0.8)


TAKES = [thumps, cracks, debris, grinds]

if __name__ == '__main__':
    only = sys.argv[1] if len(sys.argv) > 1 else ''
    for take in TAKES:
        if only in take.__name__:
            take()
