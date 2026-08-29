class_name PowerSystem
extends RefCounted
## The X-Wing CMD trade: one reactor, three consumers. Four pips total; whatever
## you don't spend on laser or shield recharge stays in the engines. You cannot
## have fast guns, fast shields and full speed at the same time — that tension
## is the whole minute-to-minute decision loop of the game.

const TOTAL_PIPS := 4

# Index by pip count 0..4.
const ENGINE_FACTOR := [0.62, 0.80, 1.00, 1.14, 1.25]
const RECHARGE_FACTOR := [0.0, 0.5, 1.0, 1.7, 2.5]

var laser_pips := 1
var shield_pips := 1

func engine_pips() -> int:
	return TOTAL_PIPS - laser_pips - shield_pips

func free_pips() -> int:
	return engine_pips()

func engine_factor() -> float:
	return ENGINE_FACTOR[engine_pips()]

func laser_factor() -> float:
	return RECHARGE_FACTOR[laser_pips]

func shield_factor() -> float:
	return RECHARGE_FACTOR[shield_pips]

## Returns true if the pip actually moved, so the HUD can beep/flash on refusal.
func add_laser(delta: int) -> bool:
	return _shift("laser", delta)

func add_shield(delta: int) -> bool:
	return _shift("shield", delta)

func _shift(which: String, delta: int) -> bool:
	var l := laser_pips
	var s := shield_pips
	if which == "laser":
		l = clampi(l + delta, 0, TOTAL_PIPS)
	else:
		s = clampi(s + delta, 0, TOTAL_PIPS)
	if l + s > TOTAL_PIPS:
		return false
	if l == laser_pips and s == shield_pips:
		return false
	laser_pips = l
	shield_pips = s
	return true

func reset() -> void:
	laser_pips = 1
	shield_pips = 1
