class_name BriefingScreen
extends Control
## Pre-flight briefing and post-flight debrief. Same screen, two modes — the
## objectives list you read before launching is the list you are judged against
## afterwards, which is the whole contract of a mission.

signal launch_requested()
signal next_mission_requested()

const GREEN := Color(0.35, 1.0, 0.55)
const AMBER := Color(1.0, 0.72, 0.20)
const RED := Color(1.0, 0.38, 0.32)
const DIM := Color(0.60, 0.68, 0.72)

var mission: Mission
var debrief := false
var result_text := ""
var result_ok := true

var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_briefing(m: Mission) -> void:
	mission = m
	debrief = false
	visible = true
	queue_redraw()

func show_debrief(m: Mission, complete: bool) -> void:
	mission = m
	debrief = true
	result_ok = complete
	result_text = "MISSION COMPLETE" if complete else "MISSION FAILED"
	visible = true
	queue_redraw()

func _process(_dt: float) -> void:
	size = get_viewport_rect().size
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key == null:
		return
	if key.physical_keycode == KEY_SPACE or key.physical_keycode == KEY_ENTER:
		launch_requested.emit()
		get_viewport().set_input_as_handled()
	elif debrief and key.physical_keycode == KEY_N:
		next_mission_requested.emit()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if mission == null:
		return
	var vp := size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.02, 0.03, 0.94), true)
	var x := maxf(vp.x * 0.5 - 420.0, 40.0)
	var y := maxf(vp.y * 0.5 - 250.0, 40.0)
	var w := minf(840.0, vp.x - 80.0)

	draw_line(Vector2(x, y - 14), Vector2(x + w, y - 14), Color(GREEN, 0.35), 1.0)
	if debrief:
		_text(Vector2(x, y + 22), result_text, GREEN if result_ok else RED, 34)
	else:
		_text(Vector2(x, y + 22), mission.title, AMBER, 34)
	_text(Vector2(x, y + 48), mission.subtitle if not debrief else mission.title, DIM, 15)
	y += 76

	if not debrief:
		for line in mission.briefing.split("\n"):
			_text(Vector2(x, y), line, Color(0.86, 0.90, 0.92), 15)
			y += 21
		y += 14

	_text(Vector2(x, y), "OBJECTIVES", DIM, 13)
	y += 22
	for goal in mission.goals:
		var colour := DIM
		var mark := "[ ]"
		if debrief:
			match goal.status:
				MissionGoal.Status.COMPLETE:
					colour = GREEN
					mark = "[x]"
				MissionGoal.Status.FAILED:
					colour = RED
					mark = "[!]"
				_:
					mark = "[ ]"
		else:
			colour = Color(0.86, 0.90, 0.92) if goal.primary else DIM
		var suffix := "" if goal.primary else "   (secondary)"
		_text(Vector2(x, y), "%s  %s%s" % [mark, goal.label(), suffix], colour, 16)
		y += 24

	y += 24
	draw_line(Vector2(x, y - 14), Vector2(x + w, y - 14), Color(GREEN, 0.25), 1.0)
	var footer := "SPACE — launch"
	if debrief:
		footer = "SPACE — fly it again      N — next mission      ESC — quit"
	_text(Vector2(x, y + 6), footer, AMBER, 15)

func _text(p: Vector2, s: String, c: Color, size_px: int) -> void:
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, 1400.0, size_px, c)
