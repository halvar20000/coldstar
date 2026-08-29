class_name Pilot
extends Resource
## A named wingman. Pilots persist across a campaign and stay dead when killed —
## that permanence is the entire reason to name them. An anonymous wingman
## exploding is a sound effect; Rell exploding is a thing that happened to you.

@export var callsign: String = "Two"
@export var name_full: String = "Unnamed"
@export var skill: float = 0.6
@export var alive: bool = true

func label() -> String:
	return "%s (%s)" % [callsign, name_full]
