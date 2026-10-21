"""Reproduce the two original 40-second Monster Dusk scores (Python standard library).

Apache-2.0 original composition and synthesis. No sampled reference-game audio.
The inspected Kenney audio libraries supply SFX; their previews are not BGM.
"""
import array
import json
import math
import random
import wave
from pathlib import Path

RATE = 22050
BPM = 96
BEAT = 60 / BPM
BARS = 16
DURATION = BARS * 4 * BEAT


def compose(path, patrol):
    count = round(RATE * DURATION)
    samples = [0.0] * count
    rng = random.Random(81021 + int(patrol))

    def note(midi, start, length, amplitude, pluck=False):
        frequency = 440 * 2 ** ((midi - 69) / 12)
        begin = round(start * RATE)
        frames = round(length * RATE)
        for n in range(frames):
            t = n / RATE
            u = t / length
            if pluck:
                envelope = min(1, t / .012) * math.exp(-3.8 * u) * min(1, (length-t) / .06)
            else:
                envelope = math.sin(math.pi * u) ** .7
            tone = math.sin(math.tau * frequency * t) + .16 * math.sin(math.tau * frequency * 2 * t)
            samples[(begin+n) % count] += amplitude * envelope * tone

    chords = [(50,53,57), (46,50,53), (48,53,57), (48,52,55),
              (50,53,57), (46,50,53), (43,46,50), (45,49,52)]
    motifs = [(74,69,65,72), (70,65,62,65), (72,69,65,67), (67,64,60,64),
              (77,74,69,72), (70,74,77,74), (67,70,74,70), (73,69,64,69)]
    for bar in range(BARS):
        chord = chords[(bar//2) % 8]
        start = bar * 4 * BEAT
        for pitch in chord:
            note(pitch, start, 4 * BEAT, .043 if patrol else .052)
        for beat in (0,2):
            note(chord[0]-12, start + beat * BEAT, 1.8 * BEAT, .12 if patrol else .08, True)
        motif = motifs[(bar//2) % 8]
        for beat, pitch in enumerate(motif):
            if not patrol and beat % 2:
                continue
            note(pitch, start + beat * BEAT, .85 * BEAT, .095 if patrol else .085, True)
        if patrol:
            for beat in range(4):
                begin = round((start+beat*BEAT)*RATE)
                for n in range(round(.10*RATE)):
                    t=n/RATE
                    sound = math.sin(math.tau*(70*t-160*t*t)) if beat%2 == 0 else rng.uniform(-1,1)*.28
                    samples[(begin+n)%count] += .075 * sound * min(1,t/.003) * math.exp(-45*t)
    peak = max(abs(x) for x in samples)
    pcm = array.array('h')
    for n,value in enumerate(samples):
        fade = min(1, n/(RATE*.025), (count-1-n)/(RATE*.025))
        pcm.append(round(value * .78 / peak * fade * 32767))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as out:
        out.setparams((1,2,RATE,0,'NONE','not compressed'))
        out.writeframes(pcm.tobytes())
    return {'file':path.name, 'seconds':DURATION, 'sample_rate':RATE,
            'bpm':BPM, 'bars':BARS, 'channels':1, 'peak':.78,
            'parts':['minor-key harmonic bed','plucked melody','bass'] + (['soft pulse percussion'] if patrol else [])}


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    rows = [compose(root/'assets/audio/camp_watch.wav', False), compose(root/'assets/audio/dusk_patrol.wav', True)]
    (root/'assets/audio/MUSIC.json').write_text(json.dumps({'license':'Apache-2.0 original composition',
        'loop':'Godot WAV forward loop over the complete file; 25ms edge fades',
        'tracks':rows}, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'tracks':rows}))
