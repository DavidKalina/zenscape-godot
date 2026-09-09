"""Bake deterministic native equivalents of Electron audio.js procedural voices.
Run with Python 3; no external audio dependencies. Wildlife remains recordings.
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

write('stream-bed', 8, lambda t,n,l,b: l*.65*(.75+.25*math.sin(t*2.1)*math.sin(t*5.3)) + .035*math.sin(math.tau*(480*(t%.23)+4500*(t%.23)**2))*math.exp(-(t%.23)*65))
write('shore-bed', 8, lambda t,n,l,b: (.7*l+.035*n)*(.55+.45*math.sin(math.tau*t/2.6667))*(.85+.15*math.sin(t*3.7)))
write('cricket-bed', 8, lambda t,n,l,b: .18*math.sin(math.tau*4200*t)*max(0,math.sin(math.tau*28*t))**3*(1 if t%.8 < .23 else 0))
write('frog-bed', 8, lambda t,n,l,b: .2*math.sin(math.tau*(380*(t%2)+24*(t%2)**2))*max(0,math.sin(math.tau*21*t))**3*(1 if t%2 < .4 else 0))
for variant in range(4):
    # Electron padStep: falling low sine + short band of forest litter.
    frequency = 65 + variant*4
    write('footstep-'+str(variant+1), .3, lambda t,n,l,b,f=frequency: .5*math.sin(math.tau*(f*1.25*t-f*3.2*min(t,.07)**2))*min(1,t/.012)*math.exp(-max(0,t-.02)/.035) + .8*b*min(1,t/.006)*math.exp(-max(0,t-.012)/.028))
