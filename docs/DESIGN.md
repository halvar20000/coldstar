# Coldstar — design decisions

## Decided (2026-08-29)

| Decision | Choice | Why |
|---|---|---|
| Engine | Godot 4.7, GDScript | Native Mac/Linux/Windows exports, real joystick enumeration, VR later. Note this is *not* the Fiefdom stack (TypeScript + three.js) — no code carries over, only the working method. |
| View | Cockpit-first | The framed canopy is what makes roll and pitch legible, and the energy-management loop is a cockpit loop. Chase view exists for judging the flight model from outside. |
| First milestone | M0 flight feel | Mirrors Fiefdom's M0 look test: prove the thing the project lives or dies on before building content around it. |
| Setting | Original space opera | Legal necessity, and it means the ships can be designed for the silhouette we want. Accord vs Dominion; AF-4 Lancet vs Vex Interceptor. |

## Constraints that shape the code

**No Star Wars content.** Not models, names, music, factions, or terminology.
Lucasfilm and Disney enforce, and a public repo is what gets found. The mechanics —
energy management, targeting computer, subsystem targeting, torpedo locks, mission
structure — are not protectable and are exactly what we are cloning.

**World scale stays inside ~20 km.** 32-bit float precision becomes visible far
from the origin, and Godot's double-precision build has to be compiled from source.
The original sat in roughly this envelope anyway. Engagements happen at 100 m–2 km.

**Flight is kinematic, never rigid-body.** X-Wing flies like a WWII dogfighter:
throttle-governed speed, banked turns, essentially no drift. Authoring that
directly in `FlightController` is far cheaper than fighting it out of a physics
solver. `inertia_response` in the ship profile is the dial that would take it
Newtonian if we ever wanted to see what that feels like.

**Bolts are swept segments, not points.** At 900 m/s and 60 fps a bolt moves 15 m
per frame; point collision tunnels straight through a fighter. `LaserBolt` tests
the segment it swept this frame against each ship's hit sphere — no physics layers
to misconfigure, and it is deterministic enough to test headless.

**Input bindings are built at runtime**, not baked into `project.godot`. Joystick
axis indices and device order differ across macOS, Linux and Windows, so bindings
must live in data we can rewrite. `scripts/input_setup.gd` is the single source.

## Architecture

```
Combat (autoload)     ship registry, bolt and effect spawning
Ship                  hull, directional shields, guns, power, flight
 ├── PlayerShip       reads the stick; `autopilot` hands control to the self-test
 └── AIFighter        pursue → attack → break → extend, no cheating
FlightController      kinematic integration, shared by player and AI
PowerSystem           the 4-pip engines/lasers/shields trade
Steering              pursuit maths: intercept time, lead point, fly-toward
ShipProfile (.tres)   every number that decides feel; tunable live in F3
ShipFactory           procedural hulls, to be replaced by Blender assets
Cockpit / HUD         canopy frame, instruments
SelfTest              headless autopilot that proves the combat loop
```

Player and AI fly the *same* `FlightController` with the same profile limits. The
AI has no hidden turn rate and no perfect aim — its miss distance comes from a
skill-scaled jitter on the lead point. If the player can do it, so can the AI, and
vice versa.

## Balance intent

The Vex owns straight-line speed (165 vs 140 m/s rated); the Lancet owns the turn,
the shields and the guns. That asymmetry is the whole reason a slower ship can win,
and it is why energy management matters: engines to close, lasers to kill, shields
to survive the overshoot. It was mis-set initially — the Vex was better on every
axis — and the headless self-test is what caught it.

## Open questions

- Name. "Coldstar" is a working title.
- Faction voice: how much fiction do briefings carry?
- Torpedo lock model: X-Wing's timed tone, or something of our own?
- Whether wingmen and orders ("attack my target", "go home") land in M1 or M2.
