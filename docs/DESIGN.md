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

## M1: missions as data

`MissionRunner` reads a `Mission` resource and knows nothing about any specific
mission. A mission owns `CraftGroup`s (what flies, when it arrives, what it was
told to do) and `MissionGoal`s (what counts as winning). Orders change AI
behaviour rather than adding AI code: PATROL investigates, ATTACK hunts a named
flight, ESCORT flies formation on its charge, GOTO flies the route through a
dogfight and jumps out.

Departing is deliberately not the same as dying. A hauler that reaches its jump
point increments `departed`, not `destroyed`, and the player sees a blue streak
rather than a fireball — because "they made it" and "they died" must never look
alike.

Missions are Godot resources rather than JSON so the inspector is the mission
editor from day one: typed dropdowns for orders and triggers, no separate tool,
and a typo becomes a compile-time impossibility instead of a runtime bug.

## M2: what to take from Wing Commander

Coldstar clones X-Wing's systems, but three Wing Commander ideas are strictly
better and cost little on top of what M1 already built:

**Named wingmen with permanent losses.** The AI was already there; what was
missing was a name and a consequence. A pilot who dies is struck off the roster
for the rest of the campaign, and a flight of three launches as two.

**Branching on failure.** X-Wing makes you refly a lost mission; WC lets the war
go badly and gives you the next one. The mission system already tracked pass/fail
per goal, so branching is a graph over missions rather than new machinery. The
branch is shown at the debrief *before* you accept it, so a botched mission can
still be replayed — the campaign only moves when you say so.

**The afterburner.** The Vex is faster than the Lancet by design. Without a burst
the player has no answer to a fleeing interceptor except hoping it turns. Fuel
makes it a decision rather than a second throttle.

## Sound

Generated, not sourced. `tools/make_sounds.py` writes every clip from oscillators
and filtered noise, which means no licence tracking, no asset hunting, and a
sound design that is edited by changing numbers in a file under version control.
Loops are built from a whole number of cycles at the loop length so they repeat
without a click.

Two rules drive the mix. **Shields and hull sound different** — the pilot must be
able to tell absorbed from wounded without looking. And **the engine follows the
throttle, not the speed**, because it is the pilot's own input that should be
audible; a ship that answers the lever feels connected in a way one that answers
the physics does not.

The score copies X-Wing's trick rather than its tunes: two stems on one root,
crossfaded on threat proximity, fading in fast and out slow. The stems shipped
here are placeholders; the crossfade is the feature.

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
Mission / CraftGroup / MissionGoal   mission data (.tres)
MissionRunner         spawning, arrival triggers, goal evaluation, mission end
BriefingScreen        pre-flight briefing, debrief, campaign end
Audio                 generated clips, positional one-shots, dynamic score
Settings              what belongs to the player: pitch inversion, volumes
Pilot                 a named wingman; alive/dead persists across the campaign
Campaign / CampaignNode   the mission graph and its win/lose branches
CampaignState         current node + roster + history, saved as JSON in user://
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
