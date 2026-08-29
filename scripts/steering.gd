class_name Steering
extends RefCounted
## Shared pursuit maths. The AI, the HUD's lead pipper and the headless
## self-test autopilot all call in here, so a change to how a fighter chases
## something changes it everywhere at once.

## Time until a bolt fired now meets a target moving at rel_v. Returns 0 when
## there is no solution (target outrunning the bolt).
static func intercept_time(rel: Vector3, rel_v: Vector3, bolt_speed: float) -> float:
	var a := rel_v.dot(rel_v) - bolt_speed * bolt_speed
	var b := 2.0 * rel.dot(rel_v)
	var c := rel.dot(rel)
	if absf(a) < 0.001:
		return clampf(-c / b, 0.0, 5.0) if absf(b) > 0.001 else 0.0
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return 0.0
	var sq := sqrt(disc)
	var t0 := (-b - sq) / (2.0 * a)
	var t1 := (-b + sq) / (2.0 * a)
	var t := INF
	if t0 > 0.0:
		t = t0
	if t1 > 0.0 and t1 < t:
		t = t1
	return clampf(t if t < INF else 0.0, 0.0, 5.0)

## Where to put the pipper so bolt and target arrive together.
static func lead_point(shooter: Ship, target: Ship) -> Vector3:
	var rel := target.global_position - shooter.global_position
	var rel_v := target.flight.velocity - shooter.flight.velocity
	return target.global_position + rel_v * intercept_time(rel, rel_v, shooter.profile.bolt_speed)

## Fly toward a world point the way a pilot would: roll until the target sits in
## the vertical plane, then pull. Yaw stays a fine-aim rudder, because the
## profile gives it a fraction of the pitch rate — that asymmetry is what makes
## the ship turn like an airframe instead of sliding like a mouse cursor.
static func fly_toward(body: Node3D, flight: FlightController, point: Vector3,
		throttle: float, roll_skill := 1.0, jink := Vector3.ZERO) -> void:
	var local := body.global_transform.affine_inverse() * point
	if local.length() < 0.001:
		return
	var dir := local.normalized()
	var angle_off := acos(clampf(-dir.z, -1.0, 1.0))     # 0 = dead ahead
	var flat := Vector2(dir.x, dir.y)
	var roll_err := atan2(flat.x, flat.y) if flat.length() > 0.001 else 0.0

	# Don't roll for tiny corrections or the ship wallows on the gunsight.
	var roll_authority := clampf((angle_off - deg_to_rad(3.0)) / deg_to_rad(20.0), 0.0, 1.0)
	flight.roll_cmd = clampf(roll_err / (PI * 0.5), -1.0, 1.0) * roll_authority * roll_skill

	var pull := clampf(angle_off / deg_to_rad(25.0), 0.0, 1.0)
	var aligned := clampf(1.0 - absf(roll_err) / deg_to_rad(70.0), 0.0, 1.0)
	flight.pitch_cmd = clampf(pull * aligned + dir.y * 1.5, -1.0, 1.0) + jink.y
	flight.yaw_cmd = clampf(dir.x * 1.2, -1.0, 1.0) * 0.5 + jink.x
	flight.throttle = throttle

## True when `point` sits inside a cone of `degrees` around the nose.
static func on_target(body: Node3D, point: Vector3, degrees: float) -> bool:
	var dir := (point - body.global_position).normalized()
	return dir.dot(-body.global_transform.basis.z) > cos(deg_to_rad(degrees))
