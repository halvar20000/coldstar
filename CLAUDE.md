# Working notes for Coldstar

## Run it

All of these assume the project directory is the shell's cwd — `--path .` against
`~` silently hangs headless instead of erroring.

```bash
cd "/Users/thomasherbrig/Developer/XWING_Clone"
/Applications/Godot.app/Contents/MacOS/Godot --path .                       # play
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --selftest=120 --verbose
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --shot=/tmp/a.png --shot-after=7 --chase
```

Godot 4.7.2 lives at `/Applications/Godot.app/Contents/MacOS/Godot` (installed via
Homebrew cask). Blender is at `/opt/homebrew/bin/blender` for when the asset
pipeline starts.

## Gotchas already paid for

- **`class_name` globals do not exist until the editor has scanned the project.**
  A fresh clone run with `--headless` fails with "Could not find type Ship". Run
  `Godot --headless --editor --quit --path .` once to build
  `.godot/global_script_class_cache.cfg`, then normal runs work.
- **`PlayerShip._read_stick()` overwrites externally set flight commands.** Set
  `player.autopilot = true` before driving it from code, or your commands are gone
  before `flight.step()` ever sees them.
- **HUD size**: under a `CanvasLayer` the anchor preset alone does not track the
  window; `HUD._process` pins `size` to the viewport rect each frame.
- **Cockpit geometry is authored eye-relative**, in metres from the pilot's head.
  Authoring it in ship space put struts 2 m wide across the middle of the screen.
- **Input events injected in the first ~10 frames after boot are dropped.** The
  pad test warms up before testing, or the first checks fail for no reason.
- **The briefing and debrief pause the tree.** Anything that must keep running
  through them (Main, SelfTest, PadTest) needs
  `process_mode = Node.PROCESS_MODE_ALWAYS`, or a headless test hangs forever at
  the moment the mission ends.
- **A goal that can only fail must not count as pending work** in
  `MissionRunner._check_end`, or a mission that hinges on keeping something alive
  can never reach "all objectives met". PROTECT_GROUP is the case.
- SelfTest runs the sim at 4x by raising `physics_ticks_per_second` to 240 *and*
  `time_scale` to 4 together, which keeps the 1/60 s delta the game actually uses.
  Changing only time_scale would change the physics step and the results with it.
- **A freed object compares EQUAL to null in Godot.** `if obj != null and not
  is_instance_valid(obj)` short-circuits to false and never clears the dangling
  reference — use `is_instance_valid()` alone. This cost real damage: bolts whose
  shooter had died were failing their typed-argument check and their hits were
  silently thrown away.
- `MissionRunner.roster` must be assigned *before* `setup()`, because setup spawns
  the START groups and a roster flight draws its pilots at spawn time.
- LB on the pad is a held modifier for wing orders, so PlayerShip handles its
  press and release *before* the press-only guard in `_unhandled_input`.
- Headless runs render nothing, so `_draw` bugs will not show up there. Take a
  screenshot with `--shot=` to check anything visual.

## Preferences vs tuning

`Settings` (autoload) holds what belongs to the *person*: pitch inversion, saved
to `user://settings.json`. The F3 panel's flight numbers belong to the *craft*
and are deliberately not saved. Don't move one into the other.

The pitch actions are named `pitch_back` / `pitch_forward` after the stick
direction, never after the result — which direction raises the nose is exactly
what the preference decides.

## Where the numbers live

`data/lancet.tres` and `data/vex.tres` (`ShipProfile`). The F3 panel edits the
*running* copies — `main.gd` duplicates the resources at spawn, so tuning never
writes to disk. Copy good numbers into the `.tres` by hand.

## Before changing flight or AI

Run the self-test first and keep the numbers, then run it again after. It reports
kills, times, shots and damage taken, which is enough to catch "the AI stopped
attacking" and "the player can no longer catch anything" — both of which happened
during M0 and neither of which is visible from a screenshot.
