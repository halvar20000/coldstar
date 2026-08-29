class_name Ship
extends Node3D
## Base craft: hull, directional shields, guns, and a FlightController.
## Player and AI subclass this and differ only in who sets the stick commands.

signal destroyed(ship: Ship)
signal damaged(ship: Ship, amount: float, from_fore: bool)

enum Link { SINGLE, DUAL, QUAD }

const LINK_COST := [1.0, 2.0, 4.0]
const LINK_INTERVAL := [0.13, 0.24, 0.42]

var profile: ShipProfile
var faction := "accord"
var flight: FlightController
var power := PowerSystem.new()

var hull := 100.0
var shield_fore := 0.0
var shield_aft := 0.0
var laser_energy := 100.0
var ab_fuel := 0.0
var afterburner := false
var link: Link = Link.DUAL
var dead := false
## Set by MissionRunner so orders can name a flight ("attack the raiders").
var group_id := ""
var last_attacker: Node3D = null

## -1 = all recharge to aft, 0 = balanced, +1 = all to fore.
var shield_bias := 0.0

var _gun_cd := 0.0
var _next_cannon := 0
var _hardpoints: Array[Vector3] = []

func setup(p_profile: ShipProfile) -> void:
	profile = p_profile
	faction = p_profile.faction
	flight = FlightController.new(p_profile, self)
	hull = p_profile.hull_max
	shield_fore = p_profile.shield_max
	shield_aft = p_profile.shield_max
	laser_energy = p_profile.laser_capacity
	ab_fuel = p_profile.ab_fuel
	_hardpoints = ShipFactory.build(self, p_profile)
	Combat.register(self)

func _exit_tree() -> void:
	Combat.unregister(self)

func _physics_process(dt: float) -> void:
	if dead:
		return
	flight.engine_factor = power.engine_factor()
	flight.step(dt)
	_recharge(dt)
	_gun_cd = maxf(0.0, _gun_cd - dt)
	_step_afterburner(dt)

var _ab_cool := 0.0

## Fuel only comes back once you have been off it for a moment, so the burner
## cannot be feathered indefinitely — you either commit or you save it.
func _step_afterburner(dt: float) -> void:
	if profile.ab_fuel <= 0.0:
		afterburner = false
		flight.afterburner = false
		return
	if afterburner and ab_fuel > 0.0:
		ab_fuel = maxf(0.0, ab_fuel - profile.ab_burn * dt)
		_ab_cool = profile.ab_recharge_delay
		if ab_fuel <= 0.0:
			afterburner = false
	else:
		afterburner = false
		_ab_cool = maxf(0.0, _ab_cool - dt)
		if _ab_cool <= 0.0:
			ab_fuel = minf(profile.ab_fuel, ab_fuel + profile.ab_recharge * dt)
	flight.afterburner = afterburner

func ab_pct() -> float:
	return ab_fuel / profile.ab_fuel if profile.ab_fuel > 0.0 else 0.0

func _recharge(dt: float) -> void:
	laser_energy = minf(profile.laser_capacity,
		laser_energy + profile.laser_recharge * power.laser_factor() * dt)
	if profile.shield_max <= 0.0:
		return
	var pool := profile.shield_recharge * power.shield_factor() * dt
	if pool > 0.0:
		# Bias first, then let whatever a full face cannot take spill to the
		# other one, so "shields forward" is a real choice and not a label.
		var fore_share := clampf(0.5 + shield_bias * 0.5, 0.0, 1.0)
		_add_shields(pool * fore_share, pool * (1.0 - fore_share))

## Adds to each face and redistributes whatever overflows a full face.
func _add_shields(to_fore: float, to_aft: float) -> void:
	var cap := profile.shield_max
	var spill := 0.0
	var room_f := cap - shield_fore
	shield_fore += minf(to_fore, room_f)
	spill += maxf(0.0, to_fore - room_f)
	var room_a := cap - shield_aft
	shield_aft += minf(to_aft + spill, room_a)
	spill = maxf(0.0, to_aft + spill - room_a)
	shield_fore = minf(cap, shield_fore + spill)

func shield_pct() -> float:
	if profile.shield_max <= 0.0:
		return 0.0
	return (shield_fore + shield_aft) / (profile.shield_max * 2.0)

## Move laser charge into the shields — the classic energy shunt.
func transfer_laser_to_shields() -> bool:
	if profile.shield_max <= 0.0 or laser_energy < 10.0:
		return false
	var room := (profile.shield_max - shield_fore) + (profile.shield_max - shield_aft)
	if room <= 0.1:
		return false
	var amount := minf(minf(laser_energy, profile.laser_capacity * 0.25), room)
	laser_energy -= amount
	_add_shields(amount * 0.5, amount * 0.5)
	return true

func cycle_link() -> void:
	var max_link := Link.QUAD if profile.cannon_count >= 4 else Link.DUAL
	link = ((link + 1) % (max_link + 1)) as Link

func can_fire() -> bool:
	return not dead and _gun_cd <= 0.0 and laser_energy >= profile.laser_cost * LINK_COST[link]

func fire() -> void:
	if not can_fire():
		return
	var count := int(LINK_COST[link])
	laser_energy -= profile.laser_cost * count
	_gun_cd = LINK_INTERVAL[link]
	var aim := global_position + (-global_transform.basis.z) * profile.convergence
	for i in count:
		var hp := _hardpoints[_next_cannon % _hardpoints.size()]
		_next_cannon += 1
		var muzzle := global_transform * hp
		Combat.spawn_bolt(get_parent(), muzzle, (aim - muzzle).normalized(), self)
	Audio.play_3d("laser_player" if faction == "accord" else "laser_enemy",
		global_position, get_parent(), -3.0, randf_range(0.96, 1.05))

func take_hit(amount: float, from_world: Vector3, shooter: Node3D = null) -> void:
	if dead:
		return
	last_attacker = shooter if is_instance_valid(shooter) else null
	var local := global_transform.affine_inverse() * from_world
	var from_fore := local.z < 0.0     # -Z is forward
	var left := amount
	if profile.shield_max > 0.0:
		if from_fore:
			var absorbed := minf(shield_fore, left)
			shield_fore -= absorbed
			left -= absorbed
		else:
			var absorbed := minf(shield_aft, left)
			shield_aft -= absorbed
			left -= absorbed
	# Shields absorbing and hull tearing must not sound alike: that difference
	# is how you know, without looking, that you are now in trouble.
	Audio.play_3d("shield_hit" if left <= 0.0 else "hull_hit", from_world, get_parent(),
		-2.0, randf_range(0.94, 1.07))
	hull -= left
	damaged.emit(self, amount, from_fore)
	if hull <= 0.0:
		_die()

func _die() -> void:
	dead = true
	Combat.spawn_explosion(get_parent(), global_position)
	destroyed.emit(self)
	Combat.unregister(self)
	queue_free()
