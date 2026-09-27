"""Bake deterministic native equivalents of Electron audio.js procedural voices.
Run with Python 3; no external audio dependencies. Wildlife remains recordings.
`--genesis` bakes only the Genesis sounds (bake_genesis, docs/scenic/sound.md).
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 24000

def write(name, seconds, sample):
    rng = random.Random(name)
    low = 0.0
    mid = 0.0
    data = bytearray()
    for i in range(round(seconds * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += 0.14 * (noise - low)
        mid += 0.42 * (noise - mid)
        value = sample(t, noise, low, mid - low)
        # Quiet seam for loops, soft final release for one-shots.
        fade = min(1, t / .008, (seconds - t) / .015)
        data.extend(struct.pack('<h', round(max(-1, min(1, value * fade)) * 32767)))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(data)

def bake_classic():
    """The Electron-era beds and footsteps."""
    write('stream-bed', 8, lambda t,n,l,b: l*.65*(.75+.25*math.sin(t*2.1)*math.sin(t*5.3)) + .035*math.sin(math.tau*(480*(t%.23)+4500*(t%.23)**2))*math.exp(-(t%.23)*65))
    write('shore-bed', 8, lambda t,n,l,b: (.7*l+.035*n)*(.55+.45*math.sin(math.tau*t/2.6667))*(.85+.15*math.sin(t*3.7)))
    write('cricket-bed', 8, lambda t,n,l,b: .18*math.sin(math.tau*4200*t)*max(0,math.sin(math.tau*28*t))**3*(1 if t%.8 < .23 else 0))
    write('frog-bed', 8, lambda t,n,l,b: .2*math.sin(math.tau*(380*(t%2)+24*(t%2)**2))*max(0,math.sin(math.tau*21*t))**3*(1 if t%2 < .4 else 0))
    for variant in range(4):
        # Electron padStep: falling low sine + short band of forest litter.
        frequency = 65 + variant*4
        write('footstep-'+str(variant+1), .3, lambda t,n,l,b,f=frequency: .5*math.sin(math.tau*(f*1.25*t-f*3.2*min(t,.07)**2))*min(1,t/.012)*math.exp(-max(0,t-.02)/.035) + .8*b*min(1,t/.006)*math.exp(-max(0,t-.012)/.028))


# --- Genesis sound (docs/scenic/sound.md) -------------------------------------
# Stroke voices, creation beds and sparse one-shots for the Genesis plain.
# Everything is synthesised here from noise, filters and sines, so it carries
# no licence beyond the project's own. Loops are baked a little long and their
# tail crossfaded (equal power) into their head, so they loop without a seam.

class Biquad:
    """RBJ cookbook biquad: 'low', 'high' or 'band' (constant 0 dB peak)."""
    def __init__(self, kind, frequency, q, rate):
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0
        self.tune(kind, frequency, q, rate)

    def tune(self, kind, frequency, q, rate):
        w = math.tau * frequency / rate
        alpha = math.sin(w) / (2 * q)
        c = math.cos(w)
        if kind == 'low':
            b = ((1 - c) / 2, 1 - c, (1 - c) / 2)
        elif kind == 'high':
            b = ((1 + c) / 2, -(1 + c), (1 + c) / 2)
        else:
            b = (alpha, 0.0, -alpha)
        a0 = 1 + alpha
        self.b = [x / a0 for x in b]
        self.a = [-2 * c / a0, (1 - alpha) / a0]

    def __call__(self, x):
        y = self.b[0] * x + self.b[1] * self.x1 + self.b[2] * self.x2 - self.a[0] * self.y1 - self.a[1] * self.y2
        self.x2, self.x1, self.y2, self.y1 = self.x1, x, self.y1, y
        return y


def filtered(rng, count, stages):
    """`count` samples of white noise through a chain of filters."""
    out = []
    for _ in range(count):
        x = rng.uniform(-1, 1)
        for stage in stages:
            x = stage(x)
        out.append(x)
    return out


def smooth_random(rng, count, rate, hz):
    """A slowly wandering 0..1 control signal, about `hz` changes a second."""
    out = []
    value = target = rng.random()
    step = hz / rate
    phase = 0.0
    for _ in range(count):
        phase += step
        if phase >= 1:
            phase -= 1
            target = rng.random()
        value += (target - value) * min(1.0, step * 4)
        out.append(value)
    return out


def seamless(samples, keep, overlap):
    """First `keep` samples, with the `overlap` after them crossfaded into the head."""
    out = samples[:keep]
    for i in range(overlap):
        f = i / overlap
        out[i] = samples[keep + i] * math.cos(f * math.pi / 2) + out[i] * math.sin(f * math.pi / 2)
    return out


def save(name, rate, samples, peak):
    mean = sum(samples) / len(samples)
    samples = [x - mean for x in samples]
    top = max(1e-9, max(abs(x) for x in samples))
    data = bytearray()
    for x in samples:
        data.extend(struct.pack('<h', round(max(-1, min(1, x * peak / top)) * 32767)))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        wav.writeframes(data)


def loop(name, rate, seconds, peak, make):
    """Bake a seamless loop: `make(rng, count, rate)` returns the raw samples."""
    overlap = round(rate * 0.6)
    keep = round(rate * seconds)
    save(name, rate, seamless(make(random.Random(name), keep + overlap, rate), keep, overlap), peak)


def one_shot(name, rate, seconds, peak, make):
    count = round(rate * seconds)
    samples = make(random.Random(name), count, rate)
    # A couple of ms in, a soft last 15 ms out: never a click at either end.
    samples = [x * min(1.0, i / (rate * .002), (count - i) / (rate * .015)) for i, x in enumerate(samples)]
    save(name, rate, samples, peak)


def bubble(buffer, rate, at, frequency, tau, gain, rise=0.9):
    """A Minnaert bubble: a decaying sine whose pitch climbs as it rises."""
    start = round(at * rate)
    phase = 0.0
    for i in range(round(tau * 6 * rate)):
        if start + i >= len(buffer):
            break
        t = i / rate
        phase += math.tau * frequency * (1 + rise * t / tau * 0.25) / rate
        buffer[start + i] += gain * math.sin(phase) * math.exp(-t / tau) * min(1.0, t / 0.0015)


def grains_of(rng, count, rate, per_second, seconds, level_power=1.0):
    """Sparse decaying noise grains: soil settling, gravel, grass stems."""
    out = [0.0] * count
    t = 0.0
    while True:
        t += rng.expovariate(per_second)
        start = round(t * rate)
        if start >= count:
            return out
        level = rng.uniform(0.2, 1.0) ** level_power
        tau = rng.uniform(*seconds) * rate
        for i in range(min(round(tau * 5), count - start)):
            out[start + i] += level * rng.uniform(-1, 1) * math.exp(-i / tau)


def rumble(rng, count, rate):
    # Earth moving: brown noise under 160 Hz, three slow sub partials, and a
    # sparse gritty band of soil and stones settling. The 80-160 Hz body is
    # what a laptop speaker can play; the subs are for headphones.
    body = filtered(rng, count, [Biquad('low', 160, 0.7, rate), Biquad('low', 110, 0.7, rate)])
    grit = Biquad('band', 280, 1.3, rate)
    grains = grains_of(rng, count, rate, 9, (0.03, 0.08))
    swell = smooth_random(rng, count, rate, 1.3)
    out = []
    for i in range(count):
        t = i / rate
        sub = (0.35 * math.sin(math.tau * 31 * t) * (0.7 + 0.3 * math.sin(math.tau * 0.33 * t))
               + 0.25 * math.sin(math.tau * 43 * t + 1.1) * (0.6 + 0.4 * math.sin(math.tau * 0.51 * t))
               + 0.18 * math.sin(math.tau * 57 * t + 2.3) * (0.6 + 0.4 * math.sin(math.tau * 0.71 * t)))
        out.append(6.0 * body[i] * (0.6 + 0.4 * swell[i]) + 0.28 * sub + 0.9 * grit(grains[i]))
    return out


def thump(rng, count, rate):
    # A mountain lands: a falling low boom, a short dull hit and a rumbling tail.
    hit = filtered(rng, count, [Biquad('low', 220, 0.8, rate)])
    tail = filtered(rng, count, [Biquad('low', 130, 0.7, rate), Biquad('low', 100, 0.7, rate)])
    out = []
    phase = 0.0
    for i in range(count):
        t = i / rate
        phase += math.tau * (34 + 36 * math.exp(-t / 0.18)) / rate
        boom = math.sin(phase) * min(1.0, t / 0.008) * math.exp(-t / 0.5)
        out.append(boom + 2.5 * hit[i] * math.exp(-t / 0.12) + 7.0 * tail[i] * min(1.0, t / 0.05) * math.exp(-t / 0.9))
    return out


def pour(rng, count, rate):
    # Water poured from a height: a bright rush and a dense froth of small bubbles.
    rush = filtered(rng, count, [Biquad('band', 1400, 0.7, rate)])
    body = filtered(rng, count, [Biquad('low', 500, 0.7, rate)])
    out = [0.25 * rush[i] + 0.6 * body[i] * (0.8 + 0.2 * math.sin(math.tau * 0.7 * i / rate)) for i in range(count)]
    t = 0.0
    while True:
        t += rng.expovariate(38)
        if t * rate >= count:
            return out
        frequency = math.exp(rng.uniform(math.log(350), math.log(1400)))
        bubble(out, rate, t, frequency, rng.uniform(0.012, 0.04), rng.uniform(0.08, 0.3) * (700 / frequency) ** 0.5)


def fill(rng, count, rate):
    # A basin filling: deep, slow glugs over a low, sloshing body.
    body = filtered(rng, count, [Biquad('low', 350, 0.7, rate), Biquad('low', 300, 0.7, rate)])
    slosh = smooth_random(rng, count, rate, 0.9)
    out = [1.6 * body[i] * (0.55 + 0.45 * slosh[i]) for i in range(count)]
    t = 0.0
    while True:
        t += rng.expovariate(9)
        if t * rate >= count:
            return out
        bubble(out, rate, t, math.exp(rng.uniform(math.log(160), math.log(520))), rng.uniform(0.03, 0.08), rng.uniform(0.15, 0.4), 0.6)


def rustle(rng, count, rate):
    # Wind through leaves: an airy band, fluttering leaf clatter and a slow rush.
    air = filtered(rng, count, [Biquad('band', 2800, 0.5, rate)])
    leaves = filtered(rng, count, [Biquad('band', 4500, 0.9, rate)])
    rush = filtered(rng, count, [Biquad('low', 600, 0.7, rate)])
    flutter = smooth_random(rng, count, rate, 14)
    gust = smooth_random(rng, count, rate, 0.35)
    out = []
    for i in range(count):
        g = 0.45 + 0.55 * gust[i]
        out.append(g * (0.5 * air[i] + 0.9 * leaves[i] * flutter[i] ** 2.5 * g + 0.5 * rush[i]))
    return out


def meadow(rng, count, rate):
    # A hand brushed through long grass: a soft swish and the odd stem tick.
    swish = filtered(rng, count, [Biquad('band', 3500, 0.6, rate)])
    ticks = grains_of(rng, count, rate, 25, (0.0008, 0.0016))
    tick_band = Biquad('band', 5200, 1.2, rate)
    out = []
    for i in range(count):
        t = i / rate
        envelope = 0.55 + 0.25 * math.sin(math.tau * 0.9 * t) + 0.2 * math.sin(math.tau * 1.7 * t + 0.8)
        out.append(envelope * swish[i] + 0.35 * tick_band(ticks[i]))
    return out


def path(rng, count, rate):
    # Feet wearing a path: gravel grains crunching over a low, dry scuff.
    grains = grains_of(rng, count, rate, 70, (0.001, 0.004), 1.5)
    crunch = Biquad('band', 2200, 0.8, rate)
    scuff = filtered(rng, count, [Biquad('low', 400, 0.7, rate)])
    out = []
    for i in range(count):
        t = i / rate
        step = 0.5 + 0.5 * max(0.0, math.sin(math.tau * 1.4 * t)) ** 0.7
        out.append(step * (crunch(grains[i]) + 0.9 * scuff[i]))
    return out


def plain_air(rng, count, rate):
    # Open ground with nothing on it: a low, slow wind and a faint, drifting whistle.
    low = filtered(rng, count, [Biquad('low', 380, 0.7, rate), Biquad('low', 380, 0.7, rate)])
    swell = smooth_random(rng, count, rate, 0.18)
    whistle_level = smooth_random(rng, count, rate, 0.25)
    drift = smooth_random(rng, count, rate, 0.2)
    band = Biquad('band', 700, 12, rate)
    out = []
    for i in range(count):
        if i % 240 == 0:
            # Retune every 10 ms, keeping the filter's state, so the whistle glides.
            band.tune('band', 620 + 160 * drift[i], 12, rate)
        out.append((0.3 + 0.7 * swell[i]) * 2.2 * low[i] + 0.9 * band(rng.uniform(-1, 1)) * whistle_level[i] ** 2)
    return out


def plop(frequency):
    def make(rng, count, rate):
        # A fish breaks the surface: one bubble, a little splash and a droplet.
        out = [0.0] * count
        bubble(out, rate, 0.0, frequency, 0.025, 1.0, 1.4)
        bubble(out, rate, 0.07, frequency * 1.7, 0.012, 0.3, 1.2)
        splash = filtered(rng, count, [Biquad('band', 2500, 0.8, rate)])
        return [out[i] + 0.9 * splash[i] * math.exp(-i / (0.03 * rate)) for i in range(count)]
    return make


def croak(rng, count, rate):
    # One frog: two short, buzzy pulse trains, the second a touch lower.
    out = []
    for i in range(count):
        t = i / rate
        value = 0.0
        for start, pitch in ((0.0, 1.0), (0.27, 0.93)):
            local = t - start
            if 0 <= local < 0.18:
                gate = max(0.0, math.sin(math.tau * 24 * local)) ** 4 * math.sin(math.pi * local / 0.18)
                f = 330 * pitch * (1 - 0.08 * local / 0.18)
                partials = sum(math.sin(math.tau * f * k * local) * w for k, w in ((1, 0.5), (2, 0.7), (3, 1.0), (5, 0.6), (6, 0.3)))
                value += gate * partials
        out.append(value)
    return out


def heron(rng, count, rate):
    # A grey heron's harsh "fraank": a rough, falling buzz through two formants.
    f1 = Biquad('band', 850, 2.0, rate)
    f2 = Biquad('band', 1700, 3.0, rate)
    phase = 0.0
    jitter = 0.0
    out = []
    for i in range(count):
        t = i / rate
        jitter += (rng.uniform(-1, 1) - jitter) * 0.02
        phase += (190 - 45 * min(1.0, t / 0.55) + 8 * jitter) / rate
        saw = 2 * (phase % 1.0) - 1
        rough = 1 - 0.4 * (0.5 + 0.5 * math.sin(math.tau * 55 * t))
        envelope = min(1.0, t / 0.03) * (1.0 if t < 0.38 else math.exp(-(t - 0.38) / 0.1))
        source = saw * rough + 0.25 * rng.uniform(-1, 1)
        out.append(envelope * (f1(source) + 0.7 * f2(source)))
    return out


def knock(rng, count, rate):
    # Wood on wood, heard from far off: a few decaying modes and a dry click.
    modes = ((190, 0.12, 1.0), (470, 0.05, 0.6), (1150, 0.025, 0.35), (2300, 0.012, 0.2))
    click = Biquad('high', 1500, 0.7, rate)
    out = []
    for i in range(count):
        t = i / rate
        value = sum(a * math.sin(math.tau * f * t) * math.exp(-t / tau) for f, tau, a in modes)
        noise = click(rng.uniform(-1, 1)) * math.exp(-t / 0.002)
        out.append(value * min(1.0, t / 0.001) + 0.8 * noise)
    return out


def bow(rng, count, rate):
    # A rainbow: an open G-D chord, slightly detuned, breathing in and away.
    notes = (392.0, 587.33, 784.0, 1174.66)
    air = filtered(rng, count, [Biquad('band', 3000, 0.7, rate)])
    seconds = count / rate
    out = []
    for i in range(count):
        t = i / rate
        envelope = 0.5 - 0.5 * math.cos(math.pi * t / 2.5) if t < 2.5 else 0.5 + 0.5 * math.cos(math.pi * (t - 2.5) / (seconds - 2.5))
        value = sum((math.sin(math.tau * f * t) + math.sin(math.tau * (f + 0.7) * t)) / (1 + k) for k, f in enumerate(notes))
        out.append(envelope * (value + 0.4 * air[i]))
    return out


def bake_genesis():
    """The Genesis sounds: stroke voices, creation beds and one-shots."""
    loop('genesis-rumble', 12000, 6, 0.8, rumble)
    one_shot('genesis-thump', 12000, 1.8, 0.85, thump)
    loop('genesis-pour', 22050, 5, 0.7, pour)
    loop('genesis-fill', 16000, 5, 0.7, fill)
    loop('leaf-rustle-bed', 24000, 6, 0.65, rustle)
    loop('genesis-meadow', 24000, 4, 0.55, meadow)
    loop('genesis-path', 22050, 4, 0.6, path)
    loop('plain-air-bed', 16000, 8, 0.6, plain_air)
    one_shot('fish-plop-1', 22050, 0.35, 0.8, plop(620))
    one_shot('fish-plop-2', 22050, 0.35, 0.8, plop(790))
    one_shot('frog-croak', 22050, 0.5, 0.8, croak)
    one_shot('heron-call', 22050, 0.9, 0.8, heron)
    one_shot('wood-knock', 22050, 0.6, 0.9, knock)
    one_shot('bow-swell', 22050, 7.0, 0.5, bow)


if __name__ == '__main__':
    import sys
    # --genesis bakes only the Genesis sounds; the classic set stays as it is.
    if '--genesis' not in sys.argv:
        bake_classic()
    bake_genesis()
