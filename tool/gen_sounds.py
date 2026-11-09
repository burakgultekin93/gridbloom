"""Synthesizes Blazegrid's sound effects and music from scratch (numpy only).

Every sound is generated here, so all audio in the game is original.
Run: python3 tool/gen_sounds.py  -> writes assets/sounds/<pack>/*.wav
(three packs: classic, arcade, pop) and assets/sounds/music.mp3.
Set SKIP_MUSIC=1 to keep the existing music file.
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


def save(name, x, gain=0.8, max_rms=None):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    # Dense sounds (saturated booms, square waves) feel much louder at the same
    # peak, so cap their average loudness to sit level with the chimes.
    if max_rms:
        rms = np.sqrt(np.mean(x ** 2))
        if rms > max_rms:
            x *= max_rms / rms
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
    """Deep, punchy fire blast: a pitch-dropping thump, a warm "whoomp" of
    filtered noise and a few soft crackles. Saturation adds harmonics so the
    low end still sounds full on phone speakers. step raises pitch a little."""
    x = t(0.75)
    k = 2 ** (step * 1.5 / 12)
    n = len(x)
    # Kick-like thump: frequency falls from ~210 Hz to ~55 Hz.
    f = (55 + 155 * np.exp(-x / 0.045)) * k
    phase = 2 * np.pi * np.cumsum(f) / SR
    thump = np.tanh(2.2 * np.sin(phase)) * env(n, 0.001, 0.16)
    # Body: a second, rounder tone an octave up for "tok" punch.
    body = np.sin(phase * 2 + 0.5) * env(n, 0.002, 0.06) * 0.45
    # Whoomp: low-passed noise that swells and rolls off.
    noise = rng.standard_normal(n)
    whoomp = lowpass(lowpass(noise, 520 * k), 900) * env(n, 0.012, 0.2) * 3.2
    # A soft pop at the start (low-passed click) for a fun attack.
    pop = lowpass(rng.standard_normal(n), 2400) * env(n, 0.0005, 0.006) * 1.1
    # Few, gentle crackles (no shrill hiss).
    crack = np.zeros(n)
    for _ in range(7):
        s = int(rng.uniform(0.06, 0.5) * SR)
        m = int(0.006 * SR)
        crack[s:s + m] += rng.standard_normal(m) * rng.uniform(0.3, 0.8) * (1 - s / n)
    crack = lowpass(highpass(crack, 700), 3200)
    out = thump * 1.25 + body + whoomp + pop + crack * 0.45
    return np.tanh(out * 1.3)


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


# ---------------------------------------------------------------- Arcade pack
# Retro chip-style sounds: square and triangle waves with a noise channel.


def sq(f, x, duty=0.5):
    return np.where((f * x) % 1 < duty, 1.0, -1.0)


def tri(f, x):
    return 2 * np.abs(2 * ((f * x) % 1) - 1) - 1


def crush(x, steps=16):
    """Coarse amplitude steps for a lo-fi chip feel."""
    return np.round(x * steps) / steps


def chip_noise(n, rate):
    """Noise held for several samples, like an old sound chip's noise channel."""
    hold = max(1, int(SR / rate))
    v = rng.standard_normal(n // hold + 1)
    return np.repeat(v, hold)[:n]


def a_place():
    x = t(0.08)
    return tri(196 * (1 - 0.4 * x / 0.08), x) * env(len(x), 0.001, 0.03)


def a_pick():
    x = t(0.05)
    return sq(988, x, 0.25) * env(len(x), 0.001, 0.012) * 0.6


def a_ice(step):
    """Rising sparkly arpeggio."""
    x = t(0.5)
    out = np.zeros(len(x))
    base = 784 * 2 ** (step * 2 / 12)
    for j, semis in enumerate((0, 7, 12, 19)):
        s = int(j * 0.045 * SR)
        m = len(x) - s
        out[s:] += sq(base * 2 ** (semis / 12), x[:m], 0.125) * env(m, 0.001, 0.07) * (1 - j * 0.12)
    return crush(out * 0.5)


def a_fire(step):
    """Chunky chip explosion: crunchy low noise and a falling square bass."""
    x = t(0.6)
    n = len(x)
    k = 2 ** (step * 1.5 / 12)
    boom = chip_noise(n, 2200 * k) * env(n, 0.001, 0.16)
    f = (40 + 150 * np.exp(-x / 0.08)) * k
    bass = np.where(np.sin(2 * np.pi * np.cumsum(f) / SR) > 0, 1.0, -1.0) * env(n, 0.001, 0.14) * 0.6
    return crush(lowpass(boom, 1800) * 1.6 + bass, 12)


def a_big():
    x = t(1.4)
    out = np.zeros(len(x))
    f = a_fire(3)
    out[: len(f)] += f
    for j, semis in enumerate((0, 4, 7, 12, 16, 19, 24)):
        s = int((0.1 + j * 0.06) * SR)
        m = len(x) - s
        out[s:] += 0.35 * sq(523.25 * 2 ** (semis / 12), x[:m], 0.25) * env(m, 0.002, 0.18 if j < 6 else 0.5)
    return crush(out, 16)


def a_goal():
    x = t(0.4)
    out = np.zeros(len(x))
    for st, fr in ((0, 1046.5), (0.07, 1318.5), (0.14, 2093)):
        s = int(st * SR)
        m = len(x) - s
        out[s:] += sq(fr, x[:m], 0.25) * env(m, 0.001, 0.08)
    return out


def a_gameover():
    x = t(1.1)
    out = np.zeros(len(x))
    for j, fr in enumerate((392, 370, 349.2, 330, 311.1, 293.7)):
        s = int(j * 0.13 * SR)
        m = len(x) - s
        out[s:] += sq(fr / 2, x[:m], 0.5) * env(m, 0.005, 0.12 if j < 5 else 0.4) * 0.5
    return out


# ---------------------------------------------------------------- Pop pack
# Bubbly, toy-like sounds: water-drop pops, wooden knocks and soft marimba.


def drop(f0, f1, dur, x):
    """Water-drop pop: a sine that glides up quickly."""
    f = f0 + (f1 - f0) * (1 - np.exp(-x / (dur * 0.35)))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(x), 0.001, dur)


def marimba(f, x, dec=0.25):
    return (np.sin(2 * np.pi * f * x) + 0.18 * np.sin(2 * np.pi * f * 4 * x) * np.exp(-x / 0.02)) * env(len(x), 0.001, dec)


def p_place():
    x = t(0.1)
    return marimba(330, x, 0.04) + drop(250, 500, 0.03, x) * 0.4


def p_pick():
    x = t(0.06)
    return drop(700, 1400, 0.02, x)


def p_ice(step):
    """Glassy bubble pops climbing up."""
    x = t(0.55)
    out = np.zeros(len(x))
    k = 2 ** (step * 2 / 12)
    for j, (st, f) in enumerate(((0, 880), (0.05, 1175), (0.1, 1480), (0.16, 1760))):
        s = int(st * SR)
        m = len(x) - s
        out[s:] += drop(f * k * 0.7, f * k, 0.06, x[:m]) * (1 - j * 0.15)
        out[s:] += marimba(f * k * 2, x[:m], 0.12) * 0.25
    return out


def p_fire(step):
    """Big round "bloop" with a soft thump: warm and bouncy."""
    x = t(0.6)
    n = len(x)
    k = 2 ** (step * 1.5 / 12)
    f = (70 + 120 * np.exp(-x / 0.05)) * k
    thump = np.tanh(1.8 * np.sin(2 * np.pi * np.cumsum(f) / SR)) * env(n, 0.002, 0.14)
    bloop = drop(140 * k, 420 * k, 0.12, x) * 0.7
    fizz = lowpass(rng.standard_normal(n), 700) * env(n, 0.02, 0.12) * 1.5
    # A couple of little bubbles after the bloop.
    out = thump + bloop + fizz
    for st, f0 in ((0.12, 300), (0.2, 380)):
        s = int(st * SR)
        m = int(0.08 * SR)
        out[s:s + m] += drop(f0 * k, f0 * 2 * k, 0.03, x[:m]) * 0.4
    return out


def p_big():
    x = t(1.6)
    out = np.zeros(len(x))
    f = p_fire(3)
    out[: len(f)] += f
    for j, semis in enumerate((0, 4, 7, 12, 16)):
        s = int((0.12 + j * 0.08) * SR)
        m = len(x) - s
        out[s:] += 0.5 * marimba(523.25 * 2 ** (semis / 12), x[:m], 0.35)
    return out


def p_goal():
    x = t(0.45)
    out = np.zeros(len(x))
    for st, fr in ((0, 784), (0.09, 1175)):
        s = int(st * SR)
        m = len(x) - s
        out[s:] += marimba(fr, x[:m], 0.18)
    return out


def p_gameover():
    x = t(1.2)
    out = np.zeros(len(x))
    for j, fr in enumerate((523.25, 440, 349.2, 261.6)):
        s = int(j * 0.17 * SR)
        m = len(x) - s
        out[s:] += marimba(fr, x[:m], 0.3) * (1 - j * 0.1)
    return out


PACKS = {
    "classic": dict(place=place, pick=pick, ice=ice, fire=fire, big=big, goal=goal, gameover=gameover),
    "arcade": dict(place=a_place, pick=a_pick, ice=a_ice, fire=a_fire, big=a_big, goal=a_goal, gameover=a_gameover),
    "pop": dict(place=p_place, pick=p_pick, ice=p_ice, fire=p_fire, big=p_big, goal=p_goal, gameover=p_gameover),
}


def main():
    for pack, fx in PACKS.items():
        d = os.path.join(OUT, pack)
        os.makedirs(d, exist_ok=True)
        global rng
        rng = np.random.default_rng(42)

        def put(name, x, gain):
            save(os.path.join(pack, name), x, gain, max_rms=0.13)

        put("place.wav", fx["place"](), 0.5)
        put("pick.wav", fx["pick"](), 0.25)
        for s in range(4):
            put(f"ice{s}.wav", fx["ice"](s), 0.7)
            put(f"fire{s}.wav", fx["fire"](s), 0.85)
        put("big.wav", fx["big"](), 0.9)
        put("goal.wav", fx["goal"](), 0.6)
        put("gameover.wav", fx["gameover"](), 0.6)
    if os.environ.get("SKIP_MUSIC"):
        return
    save("music.wav", music(), 0.45)
    # Music is long, so ship it as MP3 (needs ffmpeg); effects stay WAV for low latency.
    if shutil.which("ffmpeg"):
        src = os.path.join(OUT, "music.wav")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-c:a", "libmp3lame", "-b:a", "96k",
                        os.path.join(OUT, "music.mp3")], check=True)
        os.remove(src)


if __name__ == "__main__":
    main()
