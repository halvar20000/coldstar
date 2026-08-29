class_name AIFighter
extends Ship
## Fighter AI as an explicit state machine, so you can always read off the HUD
## label why a Vex just did what it did. Pursuit maths only — no cheating: it
## flies the same FlightController with the same profile limits you do.

enum State { SEEK, PURSUE, ATTACK, BREAK, EXTEND }

const STATE_NAMES := ["SEEK", "PURSUE", "ATTACK", "BREAK", "EXTEND"]

@export var skill := 0.6              # 0..1: aim jitter, reaction, patience
var target: Ship = null
var state: State = State.SEEK

var _state_time := 0.0
var _break_dir := Vector3.UP
var _jink := Vector3.ZERO
var _jink_time := 0.0

# Ranges in metres.
const ATTACK_RANGE := 900.0      # start the run
const OPEN_FIRE_RANGE := 650.0   # squeeze the trigger
const BREAK_RANGE := 180.0       # too close, disengage
const EXTEND_TO := 1100.0        # separation to regain before turning back

func _physics_process(dt: float) -> void:
	if dead:
		return
	_state_time += dt
	_jink_time -= dt
	if _jink_time <= 0.0:
		# Slow wander so formation flying doesn't look like a rail.
		_jink = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * (1.0 - skill) * 0.5
		_jink_time = randf_range(0.6, 1.6)
	_pick_target()
	_think(dt)
	super._physics_process(dt)

func _pick_target() -> void:
	if target != null and is_instance_valid(target) and not target.dead:
		return
	var best: Ship = null
	var best_d := INF
	for s in Combat.enemies_of(faction):
		var d := global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	target = best

func _think(dt: float) -> void:
	if target == null:
		flight.throttle = 0.4
		flight.pitch_cmd = 0.0
		flight.yaw_cmd = 0.0
		flight.roll_cmd = 0.0
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()

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

	# Under fire and hurt: shorter fuse on breaking off.
	if hull < profile.hull_max * 0.35 and state == State.ATTACK and randf() < dt * 0.4:
		_start_break()

func _set_state(s: State) -> void:
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
