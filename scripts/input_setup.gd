extends Node
## Builds the InputMap at boot rather than baking it into project.godot.
##
## Why: joystick/HOTAS device enumeration order is not stable across macOS,
## Linux and Windows, and axis indices differ per device. Bindings therefore
## live in plain data we can rewrite at runtime once a binding screen exists.
## project.godot stays free of Object(InputEventKey, ...) blobs.

const K := "key"
const AXIS := "axis"      # [AXIS, axis_index, direction(+1/-1)]
const BTN := "button"
const MOUSE := "mouse"

## Xbox-layout pad, mapped in full — a space sim you cannot throttle or target
## from the pad is a pad you cannot fly with. Left stick flies, triggers are the
## rudder, right stick Y is the throttle lever, the d-pad is the reactor.
const BINDINGS := {
	# --- flight ---
	# Pitch is inverted by default (pull back = nose up), the sim convention.
	# Flip it live in the tuning panel (F3) if you'd rather fly nose-follows-key.
	"pitch_up":    [[K, KEY_DOWN],  [AXIS, JOY_AXIS_LEFT_Y, 1.0]],
	"pitch_down":  [[K, KEY_UP],    [AXIS, JOY_AXIS_LEFT_Y, -1.0]],
	"roll_left":   [[K, KEY_LEFT],  [AXIS, JOY_AXIS_LEFT_X, -1.0]],
	"roll_right":  [[K, KEY_RIGHT], [AXIS, JOY_AXIS_LEFT_X, 1.0]],
	"yaw_left":    [[K, KEY_COMMA], [AXIS, JOY_AXIS_RIGHT_X, -1.0]],
	"yaw_right":   [[K, KEY_PERIOD],[AXIS, JOY_AXIS_RIGHT_X, 1.0]],
	## Triggers earn their keep: left burns, right shoots.
	"afterburner": [[K, KEY_SHIFT], [AXIS, JOY_AXIS_TRIGGER_LEFT, 1.0]],

	# --- throttle ---
	# On the pad this is a rate, not a position: hold the right stick forward to
	# wind the throttle up and it stays where you left it, like a real lever.
	"throttle_up":   [[K, KEY_EQUAL]],
	"throttle_down": [[K, KEY_MINUS]],
	"throttle_more": [[AXIS, JOY_AXIS_RIGHT_Y, -1.0]],
	"throttle_less": [[AXIS, JOY_AXIS_RIGHT_Y, 1.0]],
	"throttle_0":    [[K, KEY_1]],
	"throttle_33":   [[K, KEY_2]],
	"throttle_66":   [[K, KEY_3]],
	"throttle_100":  [[K, KEY_4]],

	# --- guns ---
	"fire":      [[K, KEY_SPACE], [MOUSE, MOUSE_BUTTON_LEFT], [BTN, JOY_BUTTON_A],
	              [AXIS, JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"link_mode": [[K, KEY_V], [BTN, JOY_BUTTON_X]],

	# --- power management (the CMD loop) ---
	"laser_up":    [[K, KEY_A], [BTN, JOY_BUTTON_DPAD_UP]],
	"laser_down":  [[K, KEY_Z], [BTN, JOY_BUTTON_DPAD_DOWN]],
	"shield_up":   [[K, KEY_S], [BTN, JOY_BUTTON_DPAD_RIGHT]],
	"shield_down": [[K, KEY_X], [BTN, JOY_BUTTON_DPAD_LEFT]],
	"power_reset": [[K, KEY_D], [BTN, JOY_BUTTON_RIGHT_STICK]],
	"xfer_shield": [[K, KEY_E]],
	## Held on the pad, LB turns the face buttons into the wing command menu.
	## Tapped and released without a command, it still does the energy shunt.
	"wing_menu":   [[BTN, JOY_BUTTON_LEFT_SHOULDER]],
	"shield_cfg":  [[K, KEY_F], [BTN, JOY_BUTTON_LEFT_STICK]],

	# --- wing commands (keyboard direct; on the pad, hold LB + face button) ---
	"wing_attack": [[K, KEY_Q]],
	"wing_cover":  [[K, KEY_W]],
	"wing_form":   [[K, KEY_C]],
	"wing_break":  [[K, KEY_B]],

	# --- targeting ---
	"target_next":    [[K, KEY_T], [BTN, JOY_BUTTON_B]],
	"target_nearest": [[K, KEY_R], [BTN, JOY_BUTTON_Y]],
	"target_gunsight":[[K, KEY_G], [BTN, JOY_BUTTON_RIGHT_SHOULDER]],

	# --- views / debug ---
	"view_cockpit": [[K, KEY_F1]],
	"view_chase":   [[K, KEY_F2]],
	"view_toggle":  [[BTN, JOY_BUTTON_BACK]],
	"view_tuning":  [[K, KEY_F3]],
	"scenario_reset":[[K, KEY_F5], [BTN, JOY_BUTTON_START]],
	"quit":         [[K, KEY_ESCAPE]],
}

## Stick axes need a real deadzone or a worn thumbstick trims the ship for you.
const DEADZONE := 0.22

func _ready() -> void:
	for action_name: String in BINDINGS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, DEADZONE)
		for b: Array in BINDINGS[action_name]:
			var ev := _make_event(b)
			if ev != null:
				InputMap.action_add_event(action_name, ev)

func _make_event(b: Array) -> InputEvent:
	match b[0]:
		K:
			var e := InputEventKey.new()
			e.physical_keycode = b[1]
			return e
		MOUSE:
			var e := InputEventMouseButton.new()
			e.button_index = b[1]
			return e
		BTN:
			var e := InputEventJoypadButton.new()
			e.button_index = b[1]
			return e
		AXIS:
			var e := InputEventJoypadMotion.new()
			e.axis = b[1]
			e.axis_value = b[2]
			return e
	return null
