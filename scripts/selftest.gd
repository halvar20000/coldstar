class_name SelfTest
extends Node
## Headless verification of the whole combat loop. Flies the player by
## autopilot — the same Steering the AI uses — so `--selftest` can prove in CI
## that targeting, lead, guns, damage, shields and kills all still work without
## anybody holding a stick.

var player: PlayerShip
var seconds := 90.0

var _t := 0.0
var _shots := 0
var _start_hostiles := 0
var _kill_times: Array[float] = []
var _first_damage_at := -1.0

var verbose := false

func start(p: PlayerShip, dur: float, p_verbose := false, rng_seed := 1) -> void:
	# Deterministic: the AI jitters and picks break vectors with randf(), so an
	# unseeded run reports a different kill count every time and is worthless as
	# a regression test. Vary --seed to sample different fights.
	seed(rng_seed)
	player = p
	player.autopilot = true
	seconds = dur
	verbose = p_verbose
	_start_hostiles = Combat.enemies_of(player.faction).size()
	player.damaged.connect(func(_s, _a, _f) -> void:
		if _first_damage_at < 0.0:
			_first_damage_at = _t)

func _physics_process(dt: float) -> void:
	_t += dt
	if not is_instance_valid(player) or player.dead:
		_report("player destroyed")
		return
	var live := Combat.enemies_of(player.faction)
	while _kill_times.size() < _start_hostiles - live.size():
		_kill_times.append(_t)
	if live.is_empty():
		_report("all hostiles destroyed")
		return
	if _t >= seconds:
		_report("time limit")
		return

	if verbose and fmod(_t, 3.0) < dt:
		_trace()

	# Autopilot: nearest hostile, lead pursuit, fire inside the gun envelope.
	var tgt: Ship = null
	var best := INF
	for s in live:
		var d := player.global_position.distance_to(s.global_position)
		if d < best:
			best = d
			tgt = s
	player.target = tgt
	var aim := Steering.lead_point(player, tgt)
	Steering.fly_toward(player, player.flight, aim, 1.0)
	player.throttle_input = 1.0
	if best < 900.0 and Steering.on_target(player, aim, 5.0) and player.can_fire():
		player.fire()
		_shots += 1
	# Manage power the way a pilot would, which is also the only way a Lancet
	# ever catches a Vex: engines while closing, guns once inside the envelope,
	# shields when the paint is coming off.
	if player.shield_pct() < 0.5:
		player.power.laser_pips = 1
		player.power.shield_pips = 2
	elif best < 900.0:
		player.power.laser_pips = 2
		player.power.shield_pips = 1
	else:
		player.power.laser_pips = 0
		player.power.shield_pips = 0

## One line per craft: where it is relative to the player and what it is doing.
func _trace() -> void:
	var parts: Array[String] = ["t=%5.1f  spd=%3.0f" % [_t, player.flight.speed]]
	for s in Combat.ships:
		if s == player:
			continue
		var to := s.global_position - player.global_position
		var off := rad_to_deg(acos(clampf((-player.global_transform.basis.z).dot(to.normalized()), -1.0, 1.0)))
		var state := (s as AIFighter).state_name() if s is AIFighter else "--"
		parts.append("%s d=%5.0f off=%3.0f deg %s hull=%3.0f" % [s.name, to.length(), off, state, s.hull])
	print("  ".join(parts))

func _report(reason: String) -> void:
	var live := Combat.enemies_of(player.faction).size() if is_instance_valid(player) else -1
	print("--- selftest: %s at %.1fs ---" % [reason, _t])
	print("kills            : %d of %d  (times: %s)" % [_kill_times.size(), _start_hostiles,
		", ".join(_kill_times.map(func(x: float) -> String: return "%.1fs" % x))])
	print("hostiles left    : %d" % live)
	if is_instance_valid(player):
		print("player hull      : %.0f / %.0f" % [player.hull, player.profile.hull_max])
		print("player shields   : fore %.0f  aft %.0f" % [player.shield_fore, player.shield_aft])
		print("laser energy     : %.0f" % player.laser_energy)
		print("speed            : %.0f m/s" % player.flight.speed)
		print("distance from 0  : %.0f m" % player.global_position.length())
	print("shots fired      : %d" % _shots)
	print("first hit taken  : %s" % ("%.1fs" % _first_damage_at if _first_damage_at >= 0.0 else "never"))
	get_tree().quit()
