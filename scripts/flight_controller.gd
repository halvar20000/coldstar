class_name FlightController
extends RefCounted
## Kinematic flight model. Deliberately NOT a RigidBody3D: X-Wing flies like a
## WWII dogfighter, throttle-governed with banked turns and no Newtonian drift,
## and that is far easier to author directly than to fight out of a physics
## solver. Player and AI both fly through this same object, so anything the
## player can do the AI can do too.

var profile: ShipProfile
var body: Node3D

# Commanded axes, -1..1. Set by the pilot (human or AI) every frame.
var pitch_cmd := 0.0    # +1 = nose up
var yaw_cmd := 0.0      # +1 = nose right
var roll_cmd := 0.0     # +1 = roll right
var throttle := 0.0     # 0..1

# Live state.
var speed := 0.0
var velocity := Vector3.ZERO
var engine_factor := 1.0    # from the power system
var afterburner := false

var _pitch_rate := 0.0
var _yaw_rate := 0.0
var _roll_rate := 0.0

func _init(p_profile: ShipProfile, p_body: Node3D) -> void:
	profile = p_profile
	body = p_body

func max_speed() -> float:
	var top := profile.rated_speed * engine_factor
	return top * profile.ab_speed_mult if afterburner else top

func step(dt: float) -> void:
	var k := clampf(dt * profile.control_response, 0.0, 1.0)
	_pitch_rate = lerpf(_pitch_rate, clampf(pitch_cmd, -1.0, 1.0) * profile.pitch_rate, k)
	_yaw_rate = lerpf(_yaw_rate, clampf(yaw_cmd, -1.0, 1.0) * profile.yaw_rate, k)
	_roll_rate = lerpf(_roll_rate, clampf(roll_cmd, -1.0, 1.0) * profile.roll_rate, k)

	# Local-axis rotation, so control is always relative to the pilot's frame.
	body.rotate_object_local(Vector3.RIGHT, deg_to_rad(_pitch_rate) * dt)
	body.rotate_object_local(Vector3.UP, deg_to_rad(-_yaw_rate) * dt)
	body.rotate_object_local(Vector3.FORWARD, deg_to_rad(_roll_rate) * dt)
	body.transform.basis = body.transform.basis.orthonormalized()

	# Lighting the burner overrides the throttle lever: it is a commitment, not
	# a setting, and it goes to full whatever the lever says.
	var target_speed := max_speed() if afterburner else clampf(throttle, 0.0, 1.0) * max_speed()
	var rate := profile.throttle_accel if target_speed > speed else profile.throttle_decel
	if afterburner:
		rate *= profile.ab_accel_mult
	speed = move_toward(speed, target_speed, rate * dt)

	var forward := -body.global_transform.basis.z
	velocity = velocity.lerp(forward * speed, clampf(dt * profile.inertia_response, 0.0, 1.0))
	body.global_position += velocity * dt

## Rotation rates actually being flown, for the HUD and for AI gun-solutions.
func angular_rates() -> Vector3:
	return Vector3(_pitch_rate, _yaw_rate, _roll_rate)
