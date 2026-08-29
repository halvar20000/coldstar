class_name LaserBolt
extends Node3D
## A bolt is a segment, not a sphere: each frame it tests the line it swept this
## frame against every ship's hit sphere. At 900 m/s and 60 fps a bolt covers
## 15 m per frame, so point-overlap collision would tunnel straight through a
## fighter. This also means no physics layers to misconfigure.

var velocity := Vector3.ZERO
var damage := 9.0
var owner_ship: Node3D = null
var faction := "accord"
var life := 2.2

var _age := 0.0

func setup(p_from: Vector3, p_dir: Vector3, p_speed: float, p_damage: float, p_owner: Node3D, p_faction: String, p_life: float) -> void:
	global_position = p_from
	velocity = p_dir.normalized() * p_speed
	damage = p_damage
	owner_ship = p_owner
	faction = p_faction
	life = p_life
	look_at(p_from + p_dir, Vector3.UP)

func _physics_process(dt: float) -> void:
	# Bolts outlive their shooter. Once the shooter is gone the reference must be
	# dropped, or take_hit() is called with a freed object and the hit is thrown
	# away — a dying pilot's last shots would pass straight through the target.
	#
	# No `!= null` guard here: in Godot a freed object compares EQUAL to null,
	# so `owner_ship != null and not is_instance_valid(owner_ship)` short-circuits
	# to false and never clears the dangling reference. is_instance_valid alone.
	if not is_instance_valid(owner_ship):
		owner_ship = null
	_age += dt
	if _age > life:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * dt
	var hit := _sweep(from, to)
	if hit != null:
		hit.take_hit(damage, from, owner_ship)
		Combat.spawn_impact(get_parent(), to)
		queue_free()
		return
	global_position = to

func _sweep(from: Vector3, to: Vector3) -> Ship:
	var best: Ship = null
	var best_t := 2.0
	for s: Ship in Combat.ships:
		if s == owner_ship or not is_instance_valid(s) or s.dead:
			continue
		if s.faction == faction:
			continue    # no friendly fire in M0; revisit when wingmen exist
		var t := _segment_sphere(from, to, s.global_position, s.profile.hit_radius)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = s
	return best

## Returns the fraction along from->to of the first intersection, or -1.
static func _segment_sphere(from: Vector3, to: Vector3, centre: Vector3, radius: float) -> float:
	var d := to - from
	var m := from - centre
	var a := d.dot(d)
	if a < 0.0001:
		return -1.0
	var b := 2.0 * m.dot(d)
	var c := m.dot(m) - radius * radius
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var sq := sqrt(disc)
	var t0 := (-b - sq) / (2.0 * a)
	var t1 := (-b + sq) / (2.0 * a)
	if t0 >= 0.0 and t0 <= 1.0:
		return t0
	if t1 >= 0.0 and t1 <= 1.0:
		return t1
	return -1.0
