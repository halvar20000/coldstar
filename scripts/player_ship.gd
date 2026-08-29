class_name PlayerShip
extends Ship
## Reads the stick. Everything else it inherits from Ship, so the AI and the
## player are flying identical maths.

signal target_changed(t: Ship)
signal wing_command(cmd: AIFighter.WingOrder)
signal invert_toggled()

var target: Ship = null
var throttle_input := 0.66
## When true the stick is ignored and flight commands come from outside — used
## by the headless self-test, and later by autopilot / cutscene flight.
var autopilot := false

## True while LB is held on the pad: the face buttons become wing orders and
## their normal jobs (including the trigger) are suppressed until it is let go.
var wing_menu_open := false
var _wing_menu_used := false

var _target_ring: Array[Ship] = []
var _ring_index := -1

func _ready() -> void:
	Combat.player = self

func _physics_process(dt: float) -> void:
	if dead:
		return
	if not autopilot:
		_read_stick(dt)
		if Input.is_action_pressed("fire") and not wing_menu_open:
			fire()
	if target != null and (not is_instance_valid(target) or target.dead):
		_set_target(null)
	super._physics_process(dt)

const PAD_THROTTLE_RATE := 0.55    # full sweep in a bit under two seconds

func _read_stick(dt: float) -> void:
	# Positive means "stick pulled back". The preference decides what that does.
	var stick_back := Input.get_action_strength("pitch_back") - Input.get_action_strength("pitch_forward")
	flight.pitch_cmd = stick_back if Settings.invert_pitch else -stick_back
	flight.roll_cmd = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
	flight.yaw_cmd = Input.get_action_strength("yaw_right") - Input.get_action_strength("yaw_left")
	afterburner = Input.is_action_pressed("afterburner") and ab_fuel > 0.0

	# Pad throttle: the stick drives the rate, the lever holds its position.
	var lever := Input.get_action_strength("throttle_more") - Input.get_action_strength("throttle_less")
	if absf(lever) > 0.001:
		throttle_input = clampf(throttle_input + lever * PAD_THROTTLE_RATE * dt, 0.0, 1.0)
	flight.throttle = throttle_input

func _unhandled_input(event: InputEvent) -> void:
	# The pad's wing menu has to see releases, so it is handled before the
	# press-only guard below.
	if event.is_action_pressed("wing_menu"):
		wing_menu_open = true
		_wing_menu_used = false
		return
	if event.is_action_released("wing_menu"):
		wing_menu_open = false
		if not _wing_menu_used:
			transfer_laser_to_shields()
		return
	if not event.is_pressed() or event.is_echo():
		return
	if wing_menu_open:
		_pad_wing_command(event)
		return
	if event.is_action("wing_attack"):
		wing_command.emit(AIFighter.WingOrder.ATTACK_TARGET)
	elif event.is_action("wing_cover"):
		wing_command.emit(AIFighter.WingOrder.COVER_ME)
	elif event.is_action("wing_form"):
		wing_command.emit(AIFighter.WingOrder.FORM_UP)
	elif event.is_action("wing_break"):
		wing_command.emit(AIFighter.WingOrder.BREAK_ENGAGE)
	elif event.is_action("throttle_up"):
		throttle_input = clampf(throttle_input + 0.1, 0.0, 1.0)
	elif event.is_action("throttle_down"):
		throttle_input = clampf(throttle_input - 0.1, 0.0, 1.0)
	elif event.is_action("throttle_0"):
		throttle_input = 0.0
	elif event.is_action("throttle_33"):
		throttle_input = 0.33
	elif event.is_action("throttle_66"):
		throttle_input = 0.66
	elif event.is_action("throttle_100"):
		throttle_input = 1.0
	elif event.is_action("laser_up"):
		power.add_laser(1)
	elif event.is_action("laser_down"):
		power.add_laser(-1)
	elif event.is_action("shield_up"):
		power.add_shield(1)
	elif event.is_action("shield_down"):
		power.add_shield(-1)
	elif event.is_action("power_reset"):
		power.reset()
	elif event.is_action("xfer_shield"):
		transfer_laser_to_shields()
	elif event.is_action("shield_cfg"):
		shield_bias = 0.0 if shield_bias > 0.5 else (1.0 if shield_bias < -0.5 else -1.0)
	elif event.is_action("link_mode"):
		cycle_link()
	elif event.is_action("target_next"):
		_target_next()
	elif event.is_action("target_nearest"):
		_target_nearest()
	elif event.is_action("target_gunsight"):
		_target_gunsight()

## While LB is held: A attacks, Y covers, X forms up, B breaks and engages.
func _pad_wing_command(event: InputEvent) -> void:
	var cmd := -1
	if event.is_action("fire"):
		cmd = AIFighter.WingOrder.ATTACK_TARGET
	elif event.is_action("target_nearest"):
		cmd = AIFighter.WingOrder.COVER_ME
	elif event.is_action("link_mode"):
		cmd = AIFighter.WingOrder.FORM_UP
	elif event.is_action("target_next"):
		cmd = AIFighter.WingOrder.BREAK_ENGAGE
	if cmd >= 0:
		_wing_menu_used = true
		wing_command.emit(cmd as AIFighter.WingOrder)
		return
	# LB + d-pad up: the pitch preference without reaching for the keyboard.
	if event.is_action("laser_up"):
		_wing_menu_used = true
		invert_toggled.emit()

func _set_target(t: Ship) -> void:
	if t != null and t != target:
		Audio.play_ui("lock", -4.0)
	target = t
	target_changed.emit(t)

func _target_next() -> void:
	_target_ring = Combat.enemies_of(faction)
	if _target_ring.is_empty():
		_set_target(null)
		return
	_ring_index = (_ring_index + 1) % _target_ring.size()
	_set_target(_target_ring[_ring_index])

func _target_nearest() -> void:
	var best: Ship = null
	var best_d := INF
	for s in Combat.enemies_of(faction):
		var d := global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	_set_target(best)

## Nearest thing inside the gunsight cone — the "shoot what I'm looking at" key.
func _target_gunsight() -> void:
	var fwd := -global_transform.basis.z
	var best: Ship = null
	var best_score := -1.0
	for s in Combat.enemies_of(faction):
		var to := s.global_position - global_position
		var d := to.length()
		if d > 4000.0:
			continue
		var align := fwd.dot(to / maxf(d, 0.01))
		if align < 0.9:
			continue
		var score := align - d / 40000.0
		if score > best_score:
			best_score = score
			best = s
	if best != null:
		_set_target(best)

## Point to shoot at so bolt and target meet. Shared with the HUD lead pipper.
func lead_point_for(t: Ship) -> Vector3:
	return Steering.lead_point(self, t)
