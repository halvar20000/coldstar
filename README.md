# Coldstar

A space combat sim in the tradition of LucasArts' *X-Wing* (1993): throttle-governed
flight, reactor power you split between engines, lasers and shields, directional
shields, a targeting computer and a lead pipper — set in an original universe.

Working title. The Accord flies the **AF-4 Lancet**; the Dominion flies the **Vex
Interceptor**.

**No Star Wars content of any kind is used or will be.** Not the ships, names,
music, factions or hardware. The design is free to clone; the setting is ours.
See `docs/DESIGN.md`.

## Status — M1: the mission system

M0 (flight feel) passed: the handling was judged X-Wing-like, so the flight model
is settled and work from here is refinement, not re-architecture.

M1 makes missions **data**. A mission is a `.tres` file — flights, arrival
triggers, orders, waypoints and goals — loaded by `MissionRunner`, which knows
nothing about any particular mission. Adding mission thirty means adding a file.

Two missions ship with it:

1. **Sweep at Tessaly Reach** — patrol intercept. A loitering raider pair, then a
   relief flight that jumps in *because* you killed the first one.
2. **Convoy out of Halgren** — escort. An unarmed hauler that cannot manoeuvre or
   run, a picket already waiting, and an ambush triggered by where *you* fly.

Working now:

- Kinematic flight model — throttle-governed speed, banked turns, no Newtonian drift
- Reactor power split across engines / lasers / shields (4 pips, engines get the rest)
- Directional fore/aft shields with a recharge bias, plus the laser→shield shunt
- 4 cannons with single/dual/quad linking and an energy cost per shot
- Cockpit view with a framed canopy, and an external chase view
- HUD: gunsight, lead pipper, target bracket, off-screen arrow, CMD target panel,
  fore/aft radar hemispheres, power pips, shields, throttle
- AI flying a real attack cycle: pursue → attack → break → extend
- Mission orders that change behaviour: PATROL breaks off to investigate, ATTACK
  hunts an assigned flight, ESCORT flies formation on its charge, GOTO flies the
  route through a dogfight and jumps out at the end
- Arrival triggers: at start, after a delay, when a flight dies, when a flight
  arrives, or when the player crosses a point
- Goals: destroy, protect, see-them-depart, reach-a-point, survive
- Briefing and debrief screens, and a live objectives list in the cockpit
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
| Space | launch from briefing / fly again from debrief |
| N | next mission (debrief only) |
| F5 | restart the mission |
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
`--chase` to boot into the external view, `--mission=2` to pick one, `--nobrief`
to skip the briefing.

## Writing a mission

Missions are Godot resources, so the inspector *is* the mission editor: open a
`.tres` under `data/missions/` and every order and trigger is a typed dropdown.
`tools/build_missions.gd` regenerates the two shipped missions from code if you
ever need canonical files again:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/build_missions.gd
```

## Next

1. Torpedoes with a lock-on delay, and subsystem targeting.
3. Capital ships: multiple hardpoints, turrets, large-object collision.
4. Real art through the Blender pipeline, replacing the procedural blockouts.
5. An input binding screen.
