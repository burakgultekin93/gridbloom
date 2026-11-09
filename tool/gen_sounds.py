"""Synthesizes Blazegrid's sound effects and music from scratch (numpy only).

Every sound is generated here, so all audio in the game is original.
Run: python3 tool/gen_sounds.py  -> writes assets/sounds/*.wav
"""
import os
import shutil
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(42)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, decay=None, sustain=1.0):
    """Fast attack, exponential decay envelope over n samples."""
    x = np.arange(n) / SR
    a = np.clip(x / attack, 0, 1)
    d = np.exp(-x / decay) if decay else np.ones(n)
    return a * d * sustain


def lowpass(x, cutoff):
    """One-pole low-pass filter."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    # Short fade out to avoid clicks.
    fade = min(len(x), int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def place():
    """Soft glassy thunk when a piece lands."""
    x = t(0.12)
    body = np.sin(2 * np.pi * (220 - 90 * x / 0.12) * x) * env(len(x), 0.002, 0.03)
    click = highpass(rng.standard_normal(len(x)), 2000) * env(len(x), 0.0005, 0.004) * 0.4
    tone = np.sin(2 * np.pi * 880 * x) * env(len(x), 0.001, 0.02) * 0.25
    return body + click + tone


def pick():
    """Tiny tick when a piece is picked up."""
    x = t(0.05)
    return np.sin(2 * np.pi * 1500 * x) * env(len(x), 0.001, 0.008)


def ice(step):
    """Crystal shatter: bright detuned chimes + glassy noise. step raises pitch."""
    x = t(0.7)
    k = 2 ** (step * 2 / 12)
    out = np.zeros(len(x))
    for f, amp, dec in ((1568, 1.0, 0.25), (2093, 0.7, 0.2), (2637, 0.5, 0.16), (3136, 0.35, 0.12), (4186, 0.25, 0.08)):
        for det in (0.997, 1.003):
            out += amp * np.sin(2 * np.pi * f * k * det * x) * env(len(x), 0.002, dec)
    shards = highpass(rng.standard_normal(len(x)), 4000) * env(len(x), 0.001, 0.05) * 1.2
    # Little tinkles of falling ice.
    for _ in range(6):
        s = int(rng.uniform(0.05, 0.45) * SR)
        f = rng.uniform(3000, 6000) * k
        n = int(0.06 * SR)
        if s + n < len(x):
            out[s:s + n] += 0.3 * np.sin(2 * np.pi * f * x[:n]) * env(n, 0.0005, 0.015)
    return out * 0.6 + shards


def fire(step):
    """Fiery blast: low boom, noisy whoosh and crackles. step raises pitch."""
    x = t(0.8)
    k = 2 ** (step * 2 / 12)
    boom = np.sin(2 * np.pi * (90 * k - 50 * x) * x) * env(len(x), 0.003, 0.18)
    noise = rng.standard_normal(len(x))
    whoosh = lowpass(noise, 1800 * k) * env(len(x), 0.01, 0.22) * 2.5
    crack = np.zeros(len(x))
    for _ in range(18):
        s = int(rng.uniform(0.02, 0.6) * SR)
        n = int(0.004 * SR)
        crack[s:s + n] += rng.standard_normal(n) * rng.uniform(0.3, 1.0) * (1 - s / len(x))
    crack = highpass(crack, 2500)
    return boom * 1.2 + whoosh + crack * 0.8


def big():
    """Board clear / new record: ice burst into a fire blast and a rising chord."""
    x = t(1.8)
    out = np.zeros(len(x))
    i = ice(4)
    out[: len(i)] += i * 0.8
    f = fire(2)
    s = int(0.15 * SR)
    out[s:s + len(f)] += f
    for j, semis in enumerate((0, 4, 7, 12)):
        fr = 523.25 * 2 ** (semis / 12)
        st = int((0.2 + j * 0.09) * SR)
        n = len(x) - st
        out[st:] += 0.35 * np.sin(2 * np.pi * fr * x[:n]) * env(n, 0.01, 0.6)
    return out


def goal():
    """Two bright notes for a finished mini goal."""
    x = t(0.5)
    out = np.zeros(len(x))
    for st, fr in ((0, 1046.5), (0.1, 1568)):
        s = int(st * SR)
        n = len(x) - s
        out[s:] += (np.sin(2 * np.pi * fr * x[:n]) + 0.3 * np.sin(2 * np.pi * fr * 2 * x[:n])) * env(n, 0.003, 0.15)
    return out


def gameover():
    """Falling notes that cool down."""
    x = t(1.3)
    out = np.zeros(len(x))
    for j, fr in enumerate((659.25, 523.25, 440.0, 329.63)):
        s = int(j * 0.18 * SR)
        n = len(x) - s
        out[s:] += np.sin(2 * np.pi * fr * x[:n]) * env(n, 0.01, 0.35) * (0.9 - j * 0.1)
    return lowpass(out, 3000)


def music():
    """A calm 16-bar loop: soft pad chords, a pulsing bass and a sparse bell melody.

    A minor, 96 bpm. Loops seamlessly (length is a whole number of bars).
    """
    bpm = 96
    beat = 60 / bpm
    bars = 16
    total = int(bars * 4 * beat * SR)
    x = np.arange(total) / SR
    out = np.zeros(total)
    # Chord progression (root midi notes): Am F C G, repeated.
    prog = [(57, (0, 3, 7)), (53, (0, 4, 7)), (60, (0, 4, 7)), (55, (0, 4, 7))]

    def hz(m):
        return 440 * 2 ** ((m - 69) / 12)

    for b in range(bars):
        root, chord = prog[b % 4]
        s = int(b * 4 * beat * SR)
        n = int(4 * beat * SR)
        seg = x[:n]
        pad_env = np.minimum(1, seg / 0.6) * np.minimum(1, (4 * beat - seg) / 0.6)
        for iv in chord:
            f = hz(root + iv + 12)
            for det in (0.996, 1.004):
                out[s:s + n] += 0.08 * np.sin(2 * np.pi * f * det * seg) * pad_env
        # Bass pulse on each beat.
        for q in range(4):
            qs = s + int(q * beat * SR)
            qn = int(beat * SR)
            out[qs:qs + qn] += 0.18 * np.sin(2 * np.pi * hz(root - 12) * x[:qn]) * env(qn, 0.01, 0.25)
    # Sparse bell melody from the A minor pentatonic.
    scale = [69, 72, 74, 76, 79, 81]
    mrng = np.random.default_rng(7)
    for e in range(bars * 2):
        if mrng.random() < 0.55:
            s = int(e * 2 * beat * SR + mrng.choice([0, 1]) * beat * SR)
            n = int(1.5 * SR)
            if s + n > total:
                n = total - s
            f = hz(int(mrng.choice(scale)))
            seg = x[:n]
            out[s:s + n] += 0.12 * (np.sin(2 * np.pi * f * seg) + 0.25 * np.sin(2 * np.pi * f * 3 * seg)) * env(n, 0.005, 0.4)
    out = lowpass(out, 5000)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    save("place.wav", place(), 0.5)
    save("pick.wav", pick(), 0.25)
    for s in range(4):
        save(f"ice{s}.wav", ice(s), 0.7)
        save(f"fire{s}.wav", fire(s), 0.8)
    save("big.wav", big(), 0.9)
    save("goal.wav", goal(), 0.6)
    save("gameover.wav", gameover(), 0.6)
    save("music.wav", music(), 0.45)
    # Music is long, so ship it as MP3 (needs ffmpeg); effects stay WAV for low latency.
    if shutil.which("ffmpeg"):
        src = os.path.join(OUT, "music.wav")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-c:a", "libmp3lame", "-b:a", "96k",
                        os.path.join(OUT, "music.mp3")], check=True)
        os.remove(src)


if __name__ == "__main__":
    main()
