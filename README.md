# Coldstar

A space combat sim in the tradition of LucasArts' *X-Wing* (1993): throttle-governed
flight, reactor power you split between engines, lasers and shields, directional
shields, a targeting computer and a lead pipper — set in an original universe.

Working title. The Accord flies the **AF-4 Lancet**; the Dominion flies the **Vex
Interceptor**.

**No Star Wars content of any kind is used or will be.** Not the ships, names,
music, factions or hardware. The design is free to clone; the setting is ours.
See `docs/DESIGN.md`.

## Status — M2: wingmen, campaign, afterburner

M0 (flight feel) passed: the handling was judged X-Wing-like, so the flight model
is settled and work from here is refinement, not re-architecture.

M1 makes missions **data**. A mission is a `.tres` file — flights, arrival
triggers, orders, waypoints and goals — loaded by `MissionRunner`, which knows
nothing about any particular mission. Adding mission thirty means adding a file.

**M2 borrows the three things Wing Commander did better than X-Wing.**

- **Named wingmen.** Your flight is filled from a squadron roster — Rell, Mara,
  Odo — and they stay dead. Losses carry across the whole campaign, which is the
  only reason naming them is worth doing. They call out when they are hit, when
  they lose someone, and when they take a kill.
- **A branching campaign.** Failing a mission does not mean flying it again: the
  war moves on and you fly the consequence. Fail the sweep and you are defending
  Halgren Gate against the raiders you let through. The debrief shows you the
  branch *before* you commit to it, so you can still replay a mission you botched.
- **Afterburner.** A fuel-limited burst that overrides the throttle. It is the
  Lancet's only answer to a Vex in a straight line, and it does not come back
  until you have been off it for a moment.

Three missions ship with it:

1. **Sweep at Tessaly Reach** — patrol intercept. A loitering raider pair, then a
   relief flight that jumps in *because* you killed the first one.
2. **Convoy out of Halgren** — escort. An unarmed hauler that cannot manoeuvre or
   run, a picket already waiting, and an ambush triggered by where *you* fly.
3. **Regroup at Halgren Gate** — the failure branch. Five interceptors, your full
   wing, and no room to lose anyone.

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
- Sound: positional guns, hits, explosions and jump-outs; an engine note that
  tracks the throttle; a cockpit warning tone; radio blips on comms; and a
  two-stem dynamic score that leans into the combat layer as something closes

## Running it

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path "/Users/thomasherbrig/Developer/XWING_Clone"
```

Or open the folder in Godot 4.7 and press F5.

## Controls

| | |
|---|---|
| Arrow ←→ | roll |
| Arrow ↑↓ | pitch — up is nose up by default; press `I` to invert |
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
| `I` | invert pitch (saved between sessions; works in flight and on the briefing) |
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
| **Hold LB** | wing orders: A attack my target, Y cover me, X form up, B break and engage; d-pad ↑ inverts pitch |
| D-pad ↑↓ | laser recharge up / down |
| D-pad ←→ | shield recharge down / up |
| LB (tap) | shunt laser energy into shields |
| L3 / R3 | shield config / reset power |
| View | toggle cockpit ↔ chase |
| Menu | reset the engagement |

On the briefing screen the pad drives everything: **A** launches, **B** continues
at the debrief, **Y** flips the pitch setting.

**Pitch direction is a saved preference, not a convention.** It defaults to
push-up-for-nose-up, which is what most people expect; press `I` (or **Y** on the
briefing screen, or LB + d-pad up in flight) for the sim-standard pull-back-for-
nose-up. The setting lives in `user://settings.json` and survives restarts.

A HOTAS works through the same axes (stick roll/pitch, right stick as rudder), but
device enumeration order is not stable across platforms — a proper binding screen
is on the list before this leaves the prototype stage. All bindings live in
`scripts/input_setup.gd`, built at runtime, not baked into `project.godot`.

Campaign branching and the persistent roster have their own test, which needs no
flying at all:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/test_campaign.gd
```

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

## Sound

Every clip is **synthesised from scratch** by `tools/make_sounds.py` — no sample
packs, nothing to license, and every parameter is a number in that file rather
than a property of a recording. Rebuild the whole set with:

```bash
python3 tools/make_sounds.py
```

Check it without a mission (windowed to hear it, headless to verify it loads):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --soundtest
```

Shields absorbing and hull tearing deliberately sound different — that contrast
is how you know you are in trouble without looking at the panel. The score is two
stems on the same root, crossfaded by how close the nearest hostile is: it leans
into the combat layer fast and back out slowly, so the tension does not flicker.

The two music stems are placeholders — the *system* is the point. To swap in real
tracks, drop 8-second seamless loops named `music_calm.wav` and
`music_combat.wav` into `assets/audio/`, in the same key so the crossfade does
not clash. (Suno tracks cut the way the Sugarfall loops were cut work directly.)

Volumes (master / effects / music) are in the F3 panel and are saved with the
rest of your preferences.

And yes: space is silent. So was X-Wing's, for the same reason — a silent
dogfight is unreadable.

## The campaign

`data/campaigns/accord.tres` is a graph: each node names a mission and where a
win or a loss sends you. Progress and the squadron roster are saved as plain JSON
in `user://campaign.json` — readable, diffable, deletable. `--newcampaign` wipes
it; `--mission=N` bypasses the campaign entirely for testing.

## Next

1. Torpedoes with a lock-on delay, and subsystem targeting.
3. Capital ships: multiple hardpoints, turrets, large-object collision.
4. Real art through the Blender pipeline, replacing the procedural blockouts.
5. An input binding screen.
