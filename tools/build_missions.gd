extends SceneTree
## Generates the mission .tres files. Missions are edited in the Godot inspector
## from here on — this tool exists so the initial files are canonical Godot
## serialisations rather than hand-written text that only looks right.
##
##   Godot --headless --path . --script tools/build_missions.gd

const LANCET := "res://data/lancet.tres"
const VEX := "res://data/vex.tres"
const HAULER := "res://data/hauler.tres"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/missions"))
	_save(_intercept(), "res://data/missions/01_intercept.tres")
	_save(_escort(), "res://data/missions/02_escort.tres")
	quit()

func _save(m: Mission, path: String) -> void:
	var err := ResourceSaver.save(m, path)
	print("%s  %s" % ["OK  " if err == OK else "FAIL", path])

func _group(id: String, profile_path: String, count: int, spawn: Vector3) -> CraftGroup:
	var g := CraftGroup.new()
	g.id = id
	g.profile = load(profile_path)
	g.count = count
	g.spawn_point = spawn
	g.facing_point = Vector3.ZERO
	return g

func _goal(kind: MissionGoal.Kind, text: String, group_id := "", primary := true) -> MissionGoal:
	var goal := MissionGoal.new()
	goal.kind = kind
	goal.text = text
	goal.group_id = group_id
	goal.primary = primary
	return goal

## Mission 1 — a patrol that turns into an intercept. Teaches the gun envelope
## and the power trade, and introduces a second wave so the first kill is not
## the end of the fight.
func _intercept() -> Mission:
	var m := Mission.new()
	m.title = "Sweep at Tessaly Reach"
	m.subtitle = "Accord patrol — single Lancet"
	m.briefing = """Dominion raiders have been hitting ore convoys along the Reach.
Fly the picket line and clear anything hostile you find.

Two Vex interceptors are already loitering at the first waypoint.
Expect a second flight once the first is dealt with — they run
their reliefs on a fixed rotation, and we intend to use that.

Watch your laser recharge. Out here nobody is coming to help you."""
	m.player_profile = load(LANCET)
	m.player_start = Vector3(0, 0, 1200)
	m.player_facing = Vector3(0, 0, -2000)

	var raiders := _group("raiders", VEX, 2, Vector3(200, 80, -1800))
	raiders.skill = 0.5
	raiders.order = CraftGroup.Order.PATROL
	raiders.waypoints = [Vector3(-900, 120, -2400), Vector3(900, -160, -1200), Vector3(0, 0, -2000)]

	# Two, not three: this is mission one. The second wave exists to teach that
	# the fight is not over when the last contact leaves the radar, not to be
	# the hardest thing in the campaign.
	var relief := _group("relief", VEX, 2, Vector3(-1500, -300, -3400))
	relief.skill = 0.6
	relief.arrival = CraftGroup.Arrival.ON_GROUP_DESTROYED
	relief.arrival_group = "raiders"
	relief.order = CraftGroup.Order.ATTACK
	relief.order_target = "player"

	m.groups = [raiders, relief]
	m.goals = [
		_goal(MissionGoal.Kind.DESTROY_GROUP, "Destroy the raider patrol", "raiders"),
		_goal(MissionGoal.Kind.DESTROY_GROUP, "Destroy the relief flight", "relief"),
	]
	return m

## Mission 2 — escort. The transport cannot defend itself and cannot outrun
## anything, so the whole mission is about where you choose to be.
func _escort() -> Mission:
	var m := Mission.new()
	m.title = "Convoy out of Halgren"
	m.subtitle = "Accord escort — one Lancet, one hauler"
	m.briefing = """The Corvid is carrying reactor parts we cannot replace.
Its route runs past a Dominion picket and it has no guns.

Stay with it. It will not manoeuvre, it will not run, and it will
not survive a single unopposed pass. The first flight is already
out there; a second will jump in once you are committed.

Get the hauler to the jump point and you have done your job."""
	m.player_profile = load(LANCET)
	m.player_start = Vector3(180, 60, 900)
	m.player_facing = Vector3(0, 0, -1500)
	m.time_limit = 420.0

	var convoy := _group("convoy", HAULER, 1, Vector3(0, 0, 600))
	convoy.facing_point = Vector3(0, 0, -4000)
	convoy.order = CraftGroup.Order.GOTO
	convoy.waypoints = [Vector3(0, 0, -1400), Vector3(600, 100, -3200), Vector3(600, 100, -5200)]
	convoy.depart_at_end = true

	var picket := _group("picket", VEX, 2, Vector3(-1200, 200, -2600))
	picket.skill = 0.55
	picket.order = CraftGroup.Order.ATTACK
	picket.order_target = "convoy"

	var ambush := _group("ambush", VEX, 2, Vector3(1600, -260, -4200))
	ambush.skill = 0.75
	ambush.arrival = CraftGroup.Arrival.PLAYER_NEAR_POINT
	ambush.arrival_point = Vector3(300, 50, -2600)
	ambush.arrival_radius = 1500.0
	ambush.order = CraftGroup.Order.ATTACK
	ambush.order_target = "convoy"

	m.groups = [convoy, picket, ambush]
	m.goals = [
		_goal(MissionGoal.Kind.GROUP_DEPARTS, "See the Corvid clear the area", "convoy"),
		_goal(MissionGoal.Kind.PROTECT_GROUP, "Do not lose the Corvid", "convoy"),
		_goal(MissionGoal.Kind.DESTROY_GROUP, "Destroy the picket", "picket", false),
		_goal(MissionGoal.Kind.DESTROY_GROUP, "Destroy the ambush flight", "ambush", false),
	]
	return m
