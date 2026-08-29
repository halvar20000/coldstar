#!/usr/bin/env python3
"""Generate every sound in the game from scratch.

No sample packs, no licences to track, and every parameter is a number in this
file rather than a property of some .wav somebody else recorded. Run it and the
whole audio set is rebuilt:

    python3 tools/make_sounds.py

Loops (engine, afterburner, music) are built from an exact whole number of
cycles at the loop length, so they repeat without a click.
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


# --- building blocks ------------------------------------------------------

def silence(dur):
    return [0.0] * int(SR * dur)


def sine(buf, freq, amp=1.0, phase=0.0, sweep_to=None):
    n = len(buf)
    ph = phase
    for i in range(n):
        f = freq if sweep_to is None else freq + (sweep_to - freq) * (i / max(n - 1, 1))
        ph += 2.0 * math.pi * f / SR
        buf[i] += amp * math.sin(ph)
    return buf


def saw(buf, freq, amp=1.0, harmonics=8):
    for h in range(1, harmonics + 1):
        sine(buf, freq * h, amp / h)
    return buf


def noise(buf, amp=1.0, rng=None):
    rng = rng or random
    for i in range(len(buf)):
        buf[i] += amp * (rng.random() * 2.0 - 1.0)
    return buf


def lowpass(buf, cutoff):
    """One-pole lowpass; cutoff may be a number or a per-sample function."""
    y = 0.0
    for i in range(len(buf)):
        fc = cutoff(i / len(buf)) if callable(cutoff) else cutoff
        a = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
        y += a * (buf[i] - y)
        buf[i] = y
    return buf


def highpass(buf, cutoff):
    y = 0.0
    out = []
    for i, x in enumerate(buf):
        a = 1.0 - math.exp(-2.0 * math.pi * cutoff / SR)
        y += a * (x - y)
        out.append(x - y)
    buf[:] = out
    return buf


def envelope(buf, attack=0.005, decay=None, curve=3.0):
    """Fast attack, exponential decay across the rest of the buffer."""
    n = len(buf)
    a = max(int(attack * SR), 1)
    for i in range(n):
        if i < a:
            g = i / a
        else:
            t = (i - a) / max(n - a, 1)
            g = math.exp(-curve * t) if decay is None else math.exp(-decay * t)
        buf[i] *= g
    return buf


def fade_edges(buf, ms=6.0):
    n = int(SR * ms / 1000.0)
    for i in range(min(n, len(buf) // 2)):
        g = i / n
        buf[i] *= g
        buf[-1 - i] *= g
    return buf


def mix(*bufs):
    n = max(len(b) for b in bufs)
    out = [0.0] * n
    for b in bufs:
        for i, v in enumerate(b):
            out[i] += v
    return out


def normalize(buf, peak=0.92):
    hi = max(abs(v) for v in buf) or 1.0
    k = peak / hi
    return [v * k for v in buf]


def write(name, buf, peak=0.92):
    buf = normalize(buf, peak)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in buf))
    print("  %-22s %5.2fs" % (name, len(buf) / SR))


def loop_freq(base, dur):
    """Nearest frequency to `base` that fits a whole number of cycles in dur."""
    return round(base * dur) / dur


# --- the sounds -----------------------------------------------------------

def laser(name, f_start, f_end, body=0.20, buzz=0.35, seed=1):
    rng = random.Random(seed)
    b = silence(body)
    sine(b, f_start, 0.9, sweep_to=f_end)
    sine(b, f_start * 1.5, 0.25, sweep_to=f_end * 1.5)   # metallic upper
    n = silence(body)
    noise(n, buzz, rng)
    lowpass(n, 2600)
    out = mix(b, n)
    envelope(out, attack=0.002, decay=7.0)
    write(name, out)


def impact():
    rng = random.Random(7)
    n = silence(0.18)
    noise(n, 1.0, rng)
    lowpass(n, 3200)
    highpass(n, 400)
    t = silence(0.18)
    sine(t, 320, 0.5, sweep_to=120)
    out = mix(n, t)
    envelope(out, attack=0.001, decay=9.0)
    write("impact.wav", out)


def shield_hit():
    b = silence(0.42)
    # Two detuned partials: reads as energy, not as metal being struck.
    sine(b, 640, 0.7, sweep_to=520)
    sine(b, 968, 0.4, sweep_to=790)
    sine(b, 1590, 0.15, sweep_to=1300)
    envelope(b, attack=0.002, decay=6.0)
    write("shield_hit.wav", b)


def hull_hit():
    rng = random.Random(11)
    n = silence(0.45)
    noise(n, 1.0, rng)
    lowpass(n, 1400)
    t = silence(0.45)
    sine(t, 110, 0.9, sweep_to=55)
    out = mix(n, t)
    envelope(out, attack=0.001, decay=5.0)
    write("hull_hit.wav", out)


def explosion():
    rng = random.Random(3)
    dur = 1.6
    n = silence(dur)
    noise(n, 1.0, rng)
    lowpass(n, lambda t: 3800 * math.exp(-3.2 * t) + 120)
    rumble = silence(dur)
    sine(rumble, 74, 0.9, sweep_to=28)
    crack = silence(0.25)
    noise(crack, 0.8, rng)
    highpass(crack, 1800)
    envelope(crack, attack=0.001, decay=12.0)
    out = mix(n, rumble, crack + [0.0] * (len(n) - len(crack)))
    envelope(out, attack=0.004, decay=3.4)
    write("explosion.wav", out)


def engine_loop(name, dur=2.0, drone=(78, 117, 158), noise_amp=0.35, cutoff=900, seed=5):
    rng = random.Random(seed)
    b = silence(dur)
    for i, f in enumerate(drone):
        sine(b, loop_freq(f, dur), 0.55 / (i + 1))
    n = silence(dur)
    noise(n, noise_amp, rng)
    lowpass(n, cutoff)
    out = mix(b, n)
    # Slow whole-cycle wobble so a two-second loop does not sound static.
    for i in range(len(out)):
        out[i] *= 1.0 + 0.06 * math.sin(2.0 * math.pi * (1.0 / dur) * i / SR)
    fade_edges(out, 4.0)
    write(name, out, peak=0.75)


def lock_beep():
    b = silence(0.07)
    sine(b, 1180, 1.0)
    envelope(b, attack=0.002, decay=5.0)
    write("lock.wav", b, peak=0.55)


def warn_beep():
    b = silence(0.42)
    half = len(b) // 2
    a1 = silence(half / SR)
    sine(a1, 880, 1.0)
    envelope(a1, attack=0.004, decay=3.0)
    a2 = silence(half / SR)
    sine(a2, 620, 1.0)
    envelope(a2, attack=0.004, decay=3.0)
    write("warning.wav", a1 + a2, peak=0.7)


def comms_blip():
    rng = random.Random(13)
    b = silence(0.11)
    sine(b, 1500, 0.5, sweep_to=900)
    n = silence(0.11)
    noise(n, 0.5, rng)
    highpass(n, 2200)
    out = mix(b, n)
    envelope(out, attack=0.002, decay=8.0)
    write("comms.wav", out, peak=0.5)


def jump_out():
    rng = random.Random(17)
    dur = 1.1
    b = silence(dur)
    sine(b, 180, 0.8, sweep_to=2600)
    n = silence(dur)
    noise(n, 0.7, rng)
    lowpass(n, lambda t: 400 + 5200 * t)
    out = mix(b, n)
    for i in range(len(out)):
        out[i] *= min(1.0, i / (0.25 * SR)) * math.exp(-2.0 * i / len(out))
    write("jump.wav", out, peak=0.8)


def ui_blip():
    b = silence(0.09)
    sine(b, 760, 1.0, sweep_to=1140)
    envelope(b, attack=0.003, decay=6.0)
    write("ui.wav", b, peak=0.5)


def music(name, dur=8.0, root=98.0, combat=False, seed=23):
    """Two stems on the same root so they can be crossfaded without a key clash.

    Placeholder music: the dynamic system matters more than the tune, and these
    are meant to be replaced by real tracks cut to the same loop length.
    """
    rng = random.Random(seed)
    b = silence(dur)
    # minor triad pad, one octave apart
    for mult, amp in ((1.0, 0.5), (1.5, 0.3), (1.2, 0.28), (2.0, 0.2)):
        saw(b, loop_freq(root * mult, dur), amp * 0.25, harmonics=6)
    lowpass(b, 700 if not combat else 1300)

    if combat:
        # Eighth-note pulse: eight hits per loop second, tied to the loop length.
        pulse = silence(dur)
        step = dur / 16.0
        for k in range(16):
            hit = silence(step * 0.9)
            sine(hit, loop_freq(root * 0.5, step * 0.9), 1.0)
            envelope(hit, attack=0.002, decay=7.0)
            off = int(k * step * SR)
            for i, v in enumerate(hit):
                if off + i < len(pulse):
                    pulse[off + i] += v * 0.5
        tick = silence(dur)
        noise(tick, 0.25, rng)
        highpass(tick, 4000)
        for i in range(len(tick)):
            tick[i] *= 0.5 + 0.5 * math.sin(2.0 * math.pi * (8.0 / dur) * i / SR)
        b = mix(b, pulse, tick)

    fade_edges(b, 5.0)
    write(name, b, peak=0.55 if combat else 0.42)


def main():
    os.makedirs(OUT, exist_ok=True)
    print("writing to", OUT)
    laser("laser_player.wav", 1500, 320, seed=1)
    laser("laser_enemy.wav", 980, 210, body=0.22, buzz=0.5, seed=2)
    impact()
    shield_hit()
    hull_hit()
    explosion()
    engine_loop("engine_loop.wav")
    engine_loop("afterburner_loop.wav", drone=(58, 88, 132), noise_amp=0.85, cutoff=2200, seed=9)
    lock_beep()
    warn_beep()
    comms_blip()
    jump_out()
    ui_blip()
    music("music_calm.wav", combat=False)
    music("music_combat.wav", combat=True)


if __name__ == "__main__":
    main()
