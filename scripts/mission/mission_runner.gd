class_name MissionRunner
extends Node
## Runs a Mission resource: spawns the player and every flight, evaluates
## arrival triggers and goals, and decides when the mission is over.
##
## Nothing in here knows about any particular mission. Adding one is adding a
## .tres file — that is the whole point of the milestone.

signal state_changed(state: State)
signal announce(text: String, seconds: float)
signal goals_changed()

enum State { FLYING, COMPLETE, FAILED }

## Runtime bookkeeping for one CraftGroup. `departed` is deliberately separate
## from `destroyed`: a transport that jumps out is a success, not a loss.
class GroupState:
	var def: CraftGroup
	var ships: Array[Ship] = []
	var arrived := false
	var spawned := 0
	var destroyed := 0
	var departed := 0

	func alive() -> int:
		return spawned - destroyed - departed

	func all_gone() -> bool:
		return spawned > 0 and alive() == 0

var mission: Mission
var world: Node3D
var player: PlayerShip
var state: State = State.FLYING
var elapsed := 0.0

var _groups: Dictionary = {}     # id -> GroupState

func setup(p_mission: Mission, p_world: Node3D) -> PlayerShip:
	mission = p_mission
	world = p_world
	elapsed = 0.0
	state = State.FLYING
	_groups.clear()

	for goal in mission.goals:
		goal.status = MissionGoal.Status.PENDING

	player = PlayerShip.new()
	player.name = "Player"
	world.add_child(player)
	player.setup(mission.player_profile.duplicate(true))
	player.global_position = mission.player_start
	player.look_at(mission.player_facing, Vector3.UP)
	player.throttle_input = 0.66
	player.flight.speed = player.flight.max_speed() * 0.66
	player.group_id = "player"

	for def in mission.groups:
		var gs := GroupState.new()
		gs.def = def
		_groups[def.id] = gs
	_check_arrivals()
	return player

func _physics_process(dt: float) -> void:
	if state != State.FLYING:
		return
	elapsed += dt
	_check_arrivals()
	_bind_escorts()
	_evaluate_goals()
	_check_end()

# --- arrivals ------------------------------------------------------------

func _check_arrivals() -> void:
	for id: String in _groups:
		var gs: GroupState = _groups[id]
		if gs.arrived or not _arrival_met(gs.def):
			continue
		_spawn_group(gs)

func _arrival_met(def: CraftGroup) -> bool:
	match def.arrival:
		CraftGroup.Arrival.START:
			return true
		CraftGroup.Arrival.AFTER_TIME:
			return elapsed >= def.arrival_delay
		CraftGroup.Arrival.ON_GROUP_DESTROYED:
			var other: GroupState = _groups.get(def.arrival_group)
			return other != null and other.arrived and other.all_gone()
		CraftGroup.Arrival.ON_GROUP_ARRIVED:
			var other: GroupState = _groups.get(def.arrival_group)
			return other != null and other.arrived and elapsed >= def.arrival_delay
		CraftGroup.Arrival.PLAYER_NEAR_POINT:
			return is_instance_valid(player) and not player.dead \
				and player.global_position.distance_to(def.arrival_point) < def.arrival_radius
	return false

func _spawn_group(gs: GroupState) -> void:
	var def := gs.def
	gs.arrived = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.id)
	for i in def.count:
		var ship := AIFighter.new()
		ship.name = "%s_%d" % [def.id, i + 1]
		world.add_child(ship)
		var profile := def.profile.duplicate(true) as ShipProfile
		if def.faction_override != "":
			profile.faction = def.faction_override
		ship.setup(profile)
		ship.group_id = def.id
		ship.skill = def.skill
		ship.order = def.order
		ship.order_target_group = def.order_target
		ship.waypoints = def.waypoints.duplicate()
		ship.depart_at_end = def.depart_at_end
		# Spread the flight out so they don't spawn inside each other.
		var offset := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1))
		ship.global_position = def.spawn_point + offset * def.spawn_spread + Vector3(0, 0, i * 45.0)
		if def.facing_point != def.spawn_point:
			ship.look_at(def.facing_point, Vector3.UP)
		ship.flight.throttle = 1.0
		ship.flight.speed = profile.rated_speed
		ship.destroyed.connect(_on_ship_destroyed.bind(gs))
		ship.departed.connect(_on_ship_departed.bind(gs))
		gs.ships.append(ship)
		gs.spawned += 1
	if def.arrival != CraftGroup.Arrival.START:
		announce.emit("%s arriving" % def.id.to_upper(), 3.0)

## Escorts need a live anchor, and their charge may not have spawned yet — or
## may have been shot out from under them mid-mission.
func _bind_escorts() -> void:
	for id: String in _groups:
		var gs: GroupState = _groups[id]
		if gs.def.order != CraftGroup.Order.ESCORT:
			continue
		var anchor := _lead_of(gs.def.order_target)
		for s in gs.ships:
			if is_instance_valid(s) and s is AIFighter:
				(s as AIFighter).escort_anchor = anchor

func _lead_of(group_id: String) -> Ship:
	var gs: GroupState = _groups.get(group_id)
	if gs == null:
		return null
	for s in gs.ships:
		if is_instance_valid(s) and not s.dead:
			return s
	return null

func _on_ship_destroyed(_ship: Ship, gs: GroupState) -> void:
	gs.destroyed += 1

func _on_ship_departed(_ship: AIFighter, gs: GroupState) -> void:
	gs.departed += 1

# --- goals ---------------------------------------------------------------

func _evaluate_goals() -> void:
	var changed := false
	for goal in mission.goals:
		if goal.status != MissionGoal.Status.PENDING:
			continue
		var gs: GroupState = _groups.get(goal.group_id)
		match goal.kind:
			MissionGoal.Kind.DESTROY_GROUP:
				if gs != null and gs.arrived and gs.spawned > 0 and gs.destroyed >= gs.spawned:
					goal.status = MissionGoal.Status.COMPLETE
					changed = true
			MissionGoal.Kind.PROTECT_GROUP:
				# Only ever fails. Still pending at mission end counts as kept.
				if gs != null and gs.arrived and gs.spawned > 0 and gs.destroyed >= gs.spawned:
					goal.status = MissionGoal.Status.FAILED
					changed = true
			MissionGoal.Kind.GROUP_DEPARTS:
				if gs != null and gs.arrived and gs.spawned > 0 and gs.alive() == 0 and gs.departed > 0:
					goal.status = MissionGoal.Status.COMPLETE
					changed = true
			MissionGoal.Kind.PLAYER_REACH_POINT:
				if is_instance_valid(player) and not player.dead \
						and player.global_position.distance_to(goal.point) < goal.radius:
					goal.status = MissionGoal.Status.COMPLETE
					changed = true
			MissionGoal.Kind.SURVIVE_TIME:
				if elapsed >= goal.seconds:
					goal.status = MissionGoal.Status.COMPLETE
					changed = true
		if changed and goal.status == MissionGoal.Status.COMPLETE:
			announce.emit("OBJECTIVE COMPLETE — %s" % goal.label(), 3.0)
		elif changed and goal.status == MissionGoal.Status.FAILED:
			announce.emit("OBJECTIVE FAILED — %s" % goal.label(), 3.0)
	if changed:
		goals_changed.emit()

func _check_end() -> void:
	if not is_instance_valid(player) or player.dead:
		_finish(State.FAILED)
		return
	var pending := 0
	for goal in mission.goals:
		if not goal.primary:
			continue
		if goal.status == MissionGoal.Status.FAILED:
			_finish(State.FAILED)
			return
		# PROTECT goals can only ever fail, so they must not be counted as
		# outstanding work — otherwise a mission that hinges on keeping
		# something alive can never reach "all objectives met".
		if goal.status == MissionGoal.Status.PENDING and goal.kind != MissionGoal.Kind.PROTECT_GROUP:
			pending += 1
	if mission.time_limit > 0.0 and elapsed > mission.time_limit:
		_finish(State.FAILED if pending > 0 else State.COMPLETE)
		return
	if pending == 0:
		_finish(State.COMPLETE)

func _finish(result: State) -> void:
	if state != State.FLYING:
		return
	state = result
	# A "don't lose them" goal that never failed has, by definition, been met.
	if result == State.COMPLETE:
		for goal in mission.goals:
			if goal.kind == MissionGoal.Kind.PROTECT_GROUP and goal.status == MissionGoal.Status.PENDING:
				goal.status = MissionGoal.Status.COMPLETE
	state_changed.emit(state)

# --- reporting -----------------------------------------------------------

func group_state(id: String) -> GroupState:
	return _groups.get(id)

## Per-flight tally: spawned, lost, and jumped out. With reinforcements in play
## a single "kills" number stops meaning anything.
func group_report() -> String:
	var lines: Array[String] = []
	for id: String in _groups:
		var gs: GroupState = _groups[id]
		lines.append("  %-10s arrived=%s spawned=%d destroyed=%d departed=%d alive=%d" % [
			id, "y" if gs.arrived else "n", gs.spawned, gs.destroyed, gs.departed, gs.alive()])
	return "\n".join(lines)

func summary() -> String:
	var lines: Array[String] = []
	for goal in mission.goals:
		var mark: String = ["PENDING", "COMPLETE", "FAILED"][goal.status]
		lines.append("  [%-8s] %s%s" % [mark, goal.label(), "" if goal.primary else "  (secondary)"])
	return "\n".join(lines)
