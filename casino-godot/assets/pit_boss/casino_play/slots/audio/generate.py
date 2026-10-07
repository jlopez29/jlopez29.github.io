"""Generate original, quiet placeholder slot cues using sine harmonics. No samples."""
from pathlib import Path
import math, struct, wave
CUES = {'spin':[220,330], 'stop1':[330], 'stop2':[392], 'stop3':[494],
        'small':[523,659,784], 'big':[523,659,784,1047],
        'top':[523,659,784,1047,1319,1568], 'free':[392,523,659,784]}
for name, notes in CUES.items():
    frames = bytearray()
    duration = .085 if name.startswith('stop') else .11
    for frequency in notes:
        count = int(22050*duration)
        for i in range(count):
            t=i/22050
            envelope=min(1,t/.006)*max(0,1-i/count)**1.8
            signal=(math.sin(2*math.pi*frequency*t)+.2*math.sin(4*math.pi*frequency*t))*envelope*.22
            frames.extend(struct.pack('<h',int(signal*32767)))
    with wave.open(str(Path(__file__).with_name(name+'.wav')),'wb') as wav:
        wav.setparams((1,2,22050,0,'NONE','not compressed')); wav.writeframes(frames)
