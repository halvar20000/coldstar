# Coldstar

A space combat sim in the tradition of LucasArts' *X-Wing* (1993): throttle-governed
flight, reactor power you split between engines, lasers and shields, directional
shields, a targeting computer and a lead pipper — set in an original universe.

Working title. The Accord flies the **AF-4 Lancet**; the Dominion flies the **Vex
Interceptor**.

**No Star Wars content of any kind is used or will be.** Not the ships, names,
music, factions or hardware. The design is free to clone; the setting is ours.
See `docs/DESIGN.md`.

## Status — M0: flight feel

M0 answers exactly one question: *does flying this feel right?* It is a feel test,
not a game. There is no mission system yet — that is M1, and it is the piece that
decides whether the project survives past mission four, so it gets built properly
rather than smuggled into the prototype.

Working now:

- Kinematic flight model — throttle-governed speed, banked turns, no Newtonian drift
- Reactor power split across engines / lasers / shields (4 pips, engines get the rest)
- Directional fore/aft shields with a recharge bias, plus the laser→shield shunt
- 4 cannons with single/dual/quad linking and an energy cost per shot
- Cockpit view with a framed canopy, and an external chase view
- HUD: gunsight, lead pipper, target bracket, off-screen arrow, CMD target panel,
  fore/aft radar hemispheres, power pips, shields, throttle
- Three AI interceptors flying a real attack cycle: pursue → attack → break → extend
- Live tuning panel (F3) for every flight number, changeable while you fly

## Running it

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path "/Users/thomasherbrig/Developer/XWING_Clone"
```

Or open the folder in Godot 4.7 and press F5.

## Controls

| | |
|---|---|
| Arrow ←→ | roll |
| Arrow ↑↓ | pitch (inverted by default — pull back for nose up; flip it in F3) |
| `,` `.` | rudder yaw |
| `-` `=` | throttle down / up |
| `1` `2` `3` `4` | throttle 0 / 33 / 66 / 100% |
| Space, LMB | fire |
| `V` | cycle fire link: single / dual / quad |
| `A` `Z` | laser recharge up / down |
| `S` `X` | shield recharge up / down |
| `D` | reset power to balanced |
| `E` | shunt laser energy into the shields |
| `F` | shield config: balanced / forward / aft |
| `R` `T` `G` | target nearest / cycle / whatever is in the gunsight |
| F1 F2 | cockpit / chase view |
| F3 | flight tuning panel |
| F5 | reset the engagement |
| Esc | quit |

### Gamepad (Xbox layout)

| | |
|---|---|
| Left stick | pitch / roll |
| LT / RT | rudder yaw |
| Right stick ↑↓ | throttle — the stick drives the *rate*, the lever holds where you left it |
| A | fire |
| X | cycle fire link |
| Y / B / RB | target nearest / cycle / gunsight |
| D-pad ↑↓ | laser recharge up / down |
| D-pad ←→ | shield recharge down / up |
| LB | shunt laser energy into shields |
| L3 / R3 | shield config / reset power |
| View | toggle cockpit ↔ chase |
| Menu | reset the engagement |

A HOTAS works through the same axes (stick roll/pitch, triggers as rudder), but
device enumeration order is not stable across platforms — a proper binding screen
is on the list before this leaves the prototype stage. All bindings live in
`scripts/input_setup.gd`, built at runtime, not baked into `project.godot`.

Verify the pad mapping without a controller plugged in:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --padtest
```

It injects synthetic Xbox-layout events and checks each one reaches the ship with
the right sign.

## Verifying it without flying it

The whole combat loop runs headless under an autopilot that uses the same steering
maths the AI does:

Run it from the project directory (`--path .` resolves against your shell's
current directory — from anywhere else, pass the full path instead):

```bash
cd "/Users/thomasherbrig/Developer/XWING_Clone"
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --selftest=120 --verbose
```

It prints kills and times, hull and shield state, shots fired, and when the player
first took a hit. `--verbose` adds a trace every three seconds of each hostile's
range, angle off the nose and current AI state. This is how the AI's
break-and-extend cycle was debugged, and it is the regression test for M1.

Add `--seed=N` to sample a different fight; the same seed always replays the same
one. Screenshots for review: add `--shot=/path/to.png --shot-after=SECONDS`, and
`--chase` to boot into the external view.

## Next

1. **M1 — the mission system.** Data-driven: craft lists, waypoints, arrival and
   departure triggers, orders (attack / escort / inspect / disable) and goals, all
   loaded from mission files. Missions become content, not code.
2. Torpedoes with a lock-on delay, and subsystem targeting.
3. Capital ships: multiple hardpoints, turrets, large-object collision.
4. Real art through the Blender pipeline, replacing the procedural blockouts.
5. An input binding screen.
