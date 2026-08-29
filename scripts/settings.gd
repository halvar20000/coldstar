extends Node
## Player preferences that outlive a session. Autoloaded as `Settings`.
##
## Pitch inversion lives here rather than on the ship because it is a property
## of the person flying, not of the craft — and because having to re-tick a box
## every launch is not an option, it is a nuisance.

const SAVE_PATH := "user://settings.json"

signal changed()

## false = press up / push forward for nose up (what most people expect)
## true  = pull back for nose up (the flight-sim convention)
var invert_pitch := false

## 0..1 each. Master feeds the bus everything else routes into.
var volume_master := 0.8
var volume_sfx := 0.9
var volume_music := 0.5

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	invert_pitch = data.get("invert_pitch", invert_pitch)
	volume_master = data.get("volume_master", volume_master)
	volume_sfx = data.get("volume_sfx", volume_sfx)
	volume_music = data.get("volume_music", volume_music)

func save_settings() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("could not write settings")
		return
	f.store_string(JSON.stringify({
		"invert_pitch": invert_pitch,
		"volume_master": volume_master,
		"volume_sfx": volume_sfx,
		"volume_music": volume_music,
	}, "  "))
	f.close()

func set_invert_pitch(value: bool) -> void:
	if invert_pitch == value:
		return
	invert_pitch = value
	save_settings()
	changed.emit()

func set_volume(which: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match which:
		"master": volume_master = value
		"sfx": volume_sfx = value
		"music": volume_music = value
	save_settings()
	changed.emit()

func toggle_invert_pitch() -> bool:
	set_invert_pitch(not invert_pitch)
	return invert_pitch

## How to describe the current setting in one line, on screen.
func pitch_label() -> String:
	return "PULL BACK for nose up" if invert_pitch else "PUSH UP for nose up"
