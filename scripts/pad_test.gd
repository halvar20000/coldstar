class_name PadTest
extends Node
## Injects synthetic gamepad events and checks the ship responds. A binding
## table that merely parses proves nothing — this proves the axes reach the
## flight controller with the right sign, and that the face buttons and d-pad
## reach targeting and the reactor.

var player: PlayerShip
var _fails := 0

func run(p: PlayerShip) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	# Rudder lives on the right stick so the triggers can be burner and guns.
	await _axis(JOY_AXIS_RIGHT_X, 1.0)
	_check("right stick right -> yaw right", player.flight.yaw_cmd > 0.5, player.flight.yaw_cmd)
	await _axis(JOY_AXIS_RIGHT_X, 0.0)

	var charge := player.laser_energy
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, 6)
	_check("right trigger -> guns fire", player.laser_energy < charge, player.laser_energy)
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

	# Left trigger lights the burner: speed goes above the throttle setting and
	# the tank drains.
	var fuel_before := player.ab_fuel
	var top_before := player.flight.max_speed()
	await _axis(JOY_AXIS_TRIGGER_LEFT, 1.0, 20)
	_check("LT -> afterburner lit", player.afterburner, player.afterburner)
	_check("burner raises top speed", player.flight.max_speed() > top_before * 1.5,
		"%.0f -> %.0f" % [top_before, player.flight.max_speed()])
	_check("burner burns fuel", player.ab_fuel < fuel_before - 1.0, player.ab_fuel)
	await _axis(JOY_AXIS_TRIGGER_LEFT, 0.0, 20)
	_check("burner cuts out", not player.afterburner, player.afterburner)

	# LB is a modifier while held: face buttons become wing orders.
	await _press(JOY_BUTTON_LEFT_SHOULDER)
	_check("LB opens the wing menu", player.wing_menu_open, player.wing_menu_open)
	var link_before := player.link
	await _button(JOY_BUTTON_X)
	_check("X under LB does not cycle guns", player.link == link_before, player.link)
	await _release(JOY_BUTTON_LEFT_SHOULDER)
	_check("LB closes the wing menu", not player.wing_menu_open, player.wing_menu_open)

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
	await _press(button)
	await _release(button)

func _press(button: int) -> void:
	await _btn(button, true)

func _release(button: int) -> void:
	await _btn(button, false)

func _btn(button: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)
	for i in 2:
		await get_tree().physics_frame

func _check(label: String, ok: bool, value: Variant) -> void:
	if not ok:
		_fails += 1
	print("  %s %-30s (%s)" % ["PASS" if ok else "FAIL", label, value])
