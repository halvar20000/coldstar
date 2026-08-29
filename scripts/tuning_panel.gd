class_name TuningPanel
extends PanelContainer
## Live tuning for the numbers that decide flight feel. M0 exists to answer one
## question — does this feel right — and the only honest way to answer it is to
## change a turn rate while still holding the stick, not to edit a file and
## relaunch. F3 toggles it.

var player: PlayerShip
var _rows: Array = []

func setup(p: PlayerShip) -> void:
	player = p
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(24, 24)
	custom_minimum_size = Vector2(340, 0)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "FLIGHT TUNING  (F3)"
	box.add_child(title)

	_slider(box, "Control response", "control_response", 1.0, 14.0)
	_slider(box, "Pitch rate deg/s", "pitch_rate", 20.0, 160.0)
	_slider(box, "Yaw rate deg/s", "yaw_rate", 5.0, 90.0)
	_slider(box, "Roll rate deg/s", "roll_rate", 30.0, 300.0)
	_slider(box, "Rated speed m/s", "rated_speed", 60.0, 320.0)
	_slider(box, "Accel m/s2", "throttle_accel", 10.0, 200.0)
	_slider(box, "Decel m/s2", "throttle_decel", 10.0, 200.0)
	_slider(box, "Inertia response", "inertia_response", 0.3, 14.0)

	var inv := CheckBox.new()
	inv.text = "Invert pitch (pull back = nose up)   [I]"
	inv.button_pressed = Settings.invert_pitch
	inv.toggled.connect(func(v: bool) -> void: Settings.set_invert_pitch(v))
	Settings.changed.connect(func() -> void: inv.button_pressed = Settings.invert_pitch)
	box.add_child(inv)

	var vol := Label.new()
	vol.text = "VOLUME  (saved)"
	vol.add_theme_font_size_override("font_size", 12)
	box.add_child(vol)
	_volume(box, "Master", "master")
	_volume(box, "Effects", "sfx")
	_volume(box, "Music", "music")

	var hint := Label.new()
	hint.text = "Flight numbers apply immediately and are not saved.\nCopy good ones into data/lancet.tres. Pitch inversion IS saved."
	hint.add_theme_font_size_override("font_size", 11)
	box.add_child(hint)
	visible = false

## Volumes live in Settings, not in the ship profile: they belong to the
## person, so unlike the flight numbers they are written to disk.
func _volume(parent: Node, label: String, key: String) -> void:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size = Vector2(150, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	var value_lbl := Label.new()
	value_lbl.custom_minimum_size = Vector2(48, 0)
	value_lbl.add_theme_font_size_override("font_size", 12)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(120, 0)
	slider.value = Settings.get("volume_" + key)
	value_lbl.text = "%d%%" % int(slider.value * 100.0)
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_volume(key, v)
		value_lbl.text = "%d%%" % int(v * 100.0))
	row.add_child(name_lbl)
	row.add_child(slider)
	row.add_child(value_lbl)
	parent.add_child(row)

func _slider(parent: Node, label: String, prop: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size = Vector2(150, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	var value_lbl := Label.new()
	value_lbl.custom_minimum_size = Vector2(48, 0)
	value_lbl.add_theme_font_size_override("font_size", 12)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = (hi - lo) / 200.0
	slider.custom_minimum_size = Vector2(120, 0)
	slider.value = player.profile.get(prop)
	value_lbl.text = "%.1f" % slider.value
	slider.value_changed.connect(func(v: float) -> void:
		player.profile.set(prop, v)
		value_lbl.text = "%.1f" % v)
	row.add_child(name_lbl)
	row.add_child(slider)
	row.add_child(value_lbl)
	parent.add_child(row)
	_rows.append(row)
