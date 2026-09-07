"""Deterministic looped noise beds, following the original Web Audio approach."""
import math, random, struct, wave
from pathlib import Path
RATE, SECONDS = 44100, 12
N = RATE * SECONDS
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'

def band(seed, frequency, q):
    rng = random.Random(seed)
    raw = [rng.uniform(-1, 1) for _ in range(N)]
    omega = 2*math.pi*frequency/RATE
    alpha = math.sin(omega)/(2*q)
    a0 = 1+alpha
    b0,b1,b2 = alpha/a0,0,-alpha/a0
    a1,a2 = -2*math.cos(omega)/a0,(1-alpha)/a0
    x1=x2=y1=y2=0
    result=[]
    # Settle the filter on the same periodic input before keeping a cycle.
    for cycle in range(2):
        for x in raw:
            y=b0*x+b1*x1+b2*x2-a1*y1-a2*y2
            x2,x1,y2,y1=x1,x,y1,y
            if cycle: result.append(y)
    rms=math.sqrt(sum(x*x for x in result)/N)
    return [x*.14/rms for x in result]

for name,freq,q,channels in [('wind-bed',300,.7,2),('rain-bed',4200,.35,2),('water-bed',850,.45,1)]:
    signals=[band(71+len(name)*13+i,freq,q) for i in range(channels)]
    data=bytearray()
    peak=0
    for j in range(N):
        for i,signal in enumerate(signals):
            envelope=.87+.13*math.sin(2*math.pi*j/N*(2+i)+i*2.1)
            value=signal[j]*envelope
            peak=max(peak,abs(value))
            data.extend(struct.pack('<h',round(max(-.98,min(.98,value))*32767)))
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(channels);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(data)
    print(name,'peak',round(peak,3),'seconds',SECONDS)
