"""Farmeow 자체 제작 효과음 (CC0): 야옹, 크리티컬, 대박, 슬롯, 카드 뒤집기.
python3 tools/synth_sfx.py assets/audio/sfx/synth"""
import sys, wave, numpy as np, subprocess, os
SR = 22050
out = sys.argv[1]

def save(name, x):
    x = np.clip(x / (np.abs(x).max() + 1e-9) * 0.8, -1, 1)
    w = os.path.join(out, name + '.wav')
    with wave.open(w, 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', w, '-c:a', 'libvorbis', '-q:a', '3', w[:-4] + '.ogg'], check=True)
    os.remove(w)

def env(n, a=0.01, r=0.3):
    t = np.linspace(0, 1, n)
    e = np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / r * 0 ) 
    return e * np.clip((1 - t) / 0.35, 0, 1)

def meow(dur, f_start, f_peak, f_end, bright=1.0, seed=0):
    n = int(SR * dur); t = np.arange(n) / SR; k = t / dur
    f0 = np.where(k < 0.35, f_start + (f_peak - f_start) * (k / 0.35), f_peak + (f_end - f_peak) * ((k - 0.35) / 0.65))
    f0 *= 1 + 0.015 * np.sin(2 * np.pi * 6 * t)
    ph = 2 * np.pi * np.cumsum(f0) / SR
    # 모음 "이-아-우" 포먼트 느낌: 배음 가중치를 시간에 따라 바꾼다
    x = np.zeros(n)
    for h in range(1, 12):
        fh = f0 * h
        form = np.exp(-((fh - (900 + 900 * np.sin(np.pi * k))) / (500 * bright)) ** 2) + 0.35 * np.exp(-((fh - 2600) / 700) ** 2)
        x += np.sin(h * ph) * form / h ** 0.3
    rng = np.random.default_rng(seed)
    x += rng.normal(0, 0.02, n)
    a = np.minimum(1, k / 0.08) * np.clip((1 - k) / 0.4, 0, 1)
    return x * a

save('meow1', meow(0.42, 520, 760, 480, 1.0, 1))
save('meow2', meow(0.32, 640, 900, 620, 1.2, 2))
save('meow3', meow(0.55, 450, 680, 380, 0.9, 3))
save('meow_sad', meow(0.6, 600, 640, 300, 0.8, 4))
save('mew_short', meow(0.18, 800, 1050, 900, 1.3, 5))

def tone(freqs, dur, decay=4.0, wave_='sine'):
    n = int(SR * dur); t = np.arange(n) / SR
    x = np.zeros(n)
    for f in freqs:
        s = np.sin(2 * np.pi * f * t) if wave_ == 'sine' else np.sign(np.sin(2 * np.pi * f * t)) * 0.5
        x += s
    return x * np.exp(-decay * t)

def seq(notes, step, dur, decay=6, wave_='square'):
    parts = []
    for f in notes:
        parts.append(tone([f], dur, decay, wave_)[: int(SR * step)])
    return np.concatenate(parts)

save('crit', tone([1568, 2349], 0.25, 14) + 0.5 * tone([3136], 0.25, 20))
save('combo', seq([784, 1175], 0.06, 0.12, 12))
save('jackpot', np.concatenate([seq([523, 659, 784, 1047, 784, 1047, 1319], 0.08, 0.2, 7), tone([1047, 1319, 1568], 0.9, 3, 'square')]))
save('bigwin', seq([659, 880, 1175, 1568], 0.07, 0.15, 8))
save('slot_tick', tone([1800], 0.03, 60, 'square'))
save('slot_stop', tone([220, 330], 0.12, 25, 'square'))
save('lose', seq([392, 330, 262], 0.12, 0.2, 6))
rng = np.random.default_rng(9)
n = int(SR * 0.12)
save('card_flip', rng.normal(0, 1, n) * np.exp(-np.linspace(0, 10, n)) * np.sin(np.linspace(0, 40, n)))
save('rare', seq([880, 1109, 1319, 1760], 0.05, 0.3, 5, 'sine'))
save('legend', np.concatenate([seq([523, 784, 1047, 1568, 2093], 0.06, 0.3, 4, 'sine'), tone([1047, 1568, 2093], 1.2, 2.2)]))
save('pop', tone([660, 990], 0.08, 30))
save('whoosh', rng.normal(0, 1, int(SR * 0.25)) * np.sin(np.linspace(0, np.pi, int(SR * 0.25))) ** 2)
save('rooster', meow(0.7, 700, 1300, 900, 1.6, 7))
print('ok')
