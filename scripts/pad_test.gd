class_name PadTest
extends Node
## Injects synthetic gamepad events and checks the ship responds. A binding
## table that merely parses proves nothing — this proves the axes reach the
## flight controller with the right sign, and that the face buttons and d-pad
## reach targeting and the reactor.

var player: PlayerShip
var _fails := 0

func run(p: PlayerShip) -> void:
	player = p
	# Events injected in the first frames after boot are dropped — Input is not
	# flushing yet — so let the loop settle before testing anything.
	for i in 12:
		await get_tree().physics_frame
	print("--- pad test (synthetic Xbox-layout events) ---")

	await _axis(JOY_AXIS_LEFT_Y, 1.0)
	_check("stick back  -> nose up", player.flight.pitch_cmd > 0.5, player.flight.pitch_cmd)
	await _axis(JOY_AXIS_LEFT_Y, -1.0)
	_check("stick fwd   -> nose down", player.flight.pitch_cmd < -0.5, player.flight.pitch_cmd)
	await _axis(JOY_AXIS_LEFT_Y, 0.0)

	await _axis(JOY_AXIS_LEFT_X, 1.0)
	_check("stick right -> roll right", player.flight.roll_cmd > 0.5, player.flight.roll_cmd)
	await _axis(JOY_AXIS_LEFT_X, 0.0)

	await _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_check("right trigger -> yaw right", player.flight.yaw_cmd > 0.5, player.flight.yaw_cmd)
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)

	# Throttle lever: hold the right stick forward, then let go and check it stayed.
	var before := player.throttle_input
	await _axis(JOY_AXIS_RIGHT_Y, -1.0, 30)
	var during := player.throttle_input
	await _axis(JOY_AXIS_RIGHT_Y, 0.0, 10)
	_check("right stick fwd -> throttle up", during > before + 0.1, during)
	_check("throttle holds position", absf(player.throttle_input - during) < 0.01, player.throttle_input)

	var pips := player.power.laser_pips
	await _button(JOY_BUTTON_DPAD_UP)
	_check("d-pad up -> laser pip", player.power.laser_pips == pips + 1, player.power.laser_pips)

	var link := player.link
	await _button(JOY_BUTTON_X)
	_check("X -> cycle fire link", player.link != link, player.link)

	await _button(JOY_BUTTON_Y)
	_check("Y -> target nearest", player.target != null, str(player.target))

	print("--- pad test: %s ---" % ("all checks passed" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

func _axis(axis: int, value: float, frames := 2) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	for i in frames:
		await get_tree().physics_frame

func _button(button: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().physics_frame

func _check(label: String, ok: bool, value: Variant) -> void:
	if not ok:
		_fails += 1
	print("  %s %-30s (%s)" % ["PASS" if ok else "FAIL", label, value])
