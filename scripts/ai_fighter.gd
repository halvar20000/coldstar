class_name AIFighter
extends Ship
## Fighter AI as an explicit state machine, so you can always read off the HUD
## why a Vex just did what it did. Pursuit maths only — no cheating: it flies the
## same FlightController with the same profile limits you do.
##
## Orders come from the mission data, not from here. A craft told to GOTO will
## fly its route through a dogfight; one told to PATROL will break off to
## investigate. That difference is what makes a mission feel authored.

signal departed(ship: AIFighter)

enum State { SEEK, PURSUE, ATTACK, BREAK, EXTEND, NAVIGATE, HOLD }

const STATE_NAMES := ["SEEK", "PURSUE", "ATTACK", "BREAK", "EXTEND", "NAV", "HOLD"]

@export var skill := 0.6              # 0..1: aim jitter, reaction, patience

# --- orders (set by MissionRunner); group_id lives on Ship ---
var order: CraftGroup.Order = CraftGroup.Order.PATROL
var order_target_group := ""
var waypoints: Array[Vector3] = []
var depart_at_end := true
var escort_anchor: Ship = null        ## lead craft of the group we're covering

var target: Ship = null
var state: State = State.SEEK

var _state_time := 0.0
var _break_dir := Vector3.UP
var _jink := Vector3.ZERO
var _jink_time := 0.0
var _wp := 0

# Ranges in metres.
const ATTACK_RANGE := 900.0      # start the run
const OPEN_FIRE_RANGE := 650.0   # squeeze the trigger
const BREAK_RANGE := 180.0       # too close, disengage
const EXTEND_TO := 1100.0        # separation to regain before turning back
const WAYPOINT_REACHED := 260.0

func combat_capable() -> bool:
	return profile != null and profile.cannon_count > 0

## How far this craft will look for a fight, given what it was told to do.
func engage_radius() -> float:
	match order:
		CraftGroup.Order.ATTACK: return 12000.0
		CraftGroup.Order.PATROL: return 2400.0
		CraftGroup.Order.ESCORT: return 1900.0
		CraftGroup.Order.WAIT: return 1500.0
		CraftGroup.Order.GOTO: return 900.0     # only what is already shooting at it
	return 2000.0

func _physics_process(dt: float) -> void:
	if dead:
		return
	_state_time += dt
	_jink_time -= dt
	if _jink_time <= 0.0:
		# Slow wander so formation flying doesn't look like a rail.
		_jink = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * (1.0 - skill) * 0.5
		_jink_time = randf_range(0.6, 1.6)
	_update_target()
	if target != null and combat_capable():
		_fight(dt)
	else:
		_navigate(dt)
	super._physics_process(dt)

## Order-aware target selection. An ATTACK order hunts its assigned group across
## the whole map; everyone else only reacts to what comes near them.
func _update_target() -> void:
	if target != null and (not is_instance_valid(target) or target.dead):
		target = null
	if not combat_capable():
		target = null
		return

	var radius := engage_radius()
	var origin := global_position
	if order == CraftGroup.Order.ESCORT and is_instance_valid(escort_anchor) and not escort_anchor.dead:
		# Cover the transport, not yourself: threats are measured from it.
		origin = escort_anchor.global_position

	var best: Ship = null
	var best_score := INF
	for s in Combat.enemies_of(faction):
		var d := origin.distance_to(s.global_position)
		if d > radius:
			continue
		var score := d
		if order == CraftGroup.Order.ATTACK and s.get("group_id") == order_target_group:
			score -= 6000.0     # stick to the assigned quarry
		if s == target:
			score -= 250.0      # hysteresis, or it flip-flops every frame
		if score < best_score:
			best_score = score
			best = s
	# A craft under fire defends itself whatever its orders said.
	if best == null and order == CraftGroup.Order.GOTO:
		return
	target = best

func _fight(dt: float) -> void:
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if state == State.NAVIGATE or state == State.HOLD:
		_set_state(State.PURSUE)

	match state:
		State.SEEK, State.PURSUE:
			_fly_toward(_lead_point(), 1.0, dt)
			if dist < ATTACK_RANGE:
				_set_state(State.ATTACK)
		State.ATTACK:
			var aim := _lead_point()
			_fly_toward(aim, 0.9, dt)
			if dist < OPEN_FIRE_RANGE and _on_target(aim, 4.0) and randf() < 0.6 + skill * 0.4:
				fire()
			if dist < BREAK_RANGE:
				_start_break()
			elif dist > ATTACK_RANGE * 1.4:
				_set_state(State.PURSUE)
		State.BREAK:
			# Hard turn off the attack axis so the overshoot doesn't become a
			# collision, holding the break vector rather than re-aiming.
			_fly_toward(global_position + _break_dir * 500.0, 1.0, dt)
			if _state_time > 1.5 + (1.0 - skill) * 1.2 or dist > 500.0:
				_set_state(State.EXTEND)
		State.EXTEND:
			# Run straight out to regain separation. Without this the fight
			# collapses into a 200 m furball where nobody can line up a shot.
			var away := (global_position - target.global_position).normalized()
			_fly_toward(global_position + away * 1200.0, 1.0, dt)
			if dist > EXTEND_TO or _state_time > 7.0:
				_set_state(State.PURSUE)

	if hull < profile.hull_max * 0.35 and state == State.ATTACK and randf() < dt * 0.4:
		_start_break()

## Flying the route. Escorts fly formation on their charge instead of a fixed
## path, so they arrive where the thing they are guarding actually is.
func _navigate(dt: float) -> void:
	if order == CraftGroup.Order.ESCORT and is_instance_valid(escort_anchor) and not escort_anchor.dead:
		_set_state(State.NAVIGATE)
		var offset := escort_anchor.global_transform.basis * Vector3(
			120.0 * (1.0 if (get_instance_id() % 2) == 0 else -1.0), 40.0, 90.0)
		var station := escort_anchor.global_position + offset
		var gap := global_position.distance_to(station)
		_fly_toward(station, clampf(gap / 400.0, 0.25, 1.0), dt)
		return

	if waypoints.is_empty():
		_set_state(State.HOLD)
		Steering.fly_toward(self, flight, global_position + global_transform.basis.x * 600.0
			- global_transform.basis.z * 600.0, 0.35)
		return

	_set_state(State.NAVIGATE)
	var wp := waypoints[_wp]
	if global_position.distance_to(wp) < WAYPOINT_REACHED:
		_wp += 1
		if _wp >= waypoints.size():
			if order == CraftGroup.Order.PATROL:
				_wp = 0
			elif depart_at_end:
				depart()
				return
			else:
				_wp = waypoints.size() - 1
	_fly_toward(waypoints[_wp], 1.0, dt)

## Jumping out is a mission outcome, not a death: the runner counts it toward
## "see them clear the area" instead of toward losses.
func depart() -> void:
	if dead:
		return
	dead = true
	Combat.spawn_jump(get_parent(), global_position, global_transform.basis.z)
	departed.emit(self)
	Combat.unregister(self)
	queue_free()

func _set_state(s: State) -> void:
	if state != s:
		state = s
		_state_time = 0.0

func _start_break() -> void:
	var up := global_transform.basis.y
	var right := global_transform.basis.x
	_break_dir = (up * randf_range(-1.0, 1.0) + right * randf_range(-1.0, 1.0)).normalized()
	if _break_dir.length() < 0.1:
		_break_dir = up
	_set_state(State.BREAK)

## Where to shoot, with a skill-scaled aiming error so low-skill pilots miss.
func _lead_point() -> Vector3:
	if target == null:
		return global_position - global_transform.basis.z * 1000.0
	var jitter := (1.0 - skill) * 40.0
	return Steering.lead_point(self, target) + Vector3(
		randf_range(-jitter, jitter), randf_range(-jitter, jitter), randf_range(-jitter, jitter))

func _on_target(point: Vector3, degrees: float) -> bool:
	return Steering.on_target(self, point, degrees)

func _fly_toward(point: Vector3, throttle: float, _dt: float) -> void:
	Steering.fly_toward(self, flight, point, throttle, 0.4 + skill * 0.6, _jink)

func state_name() -> String:
	return STATE_NAMES[state]
