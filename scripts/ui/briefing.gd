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

enum Mode { BRIEF, DEBRIEF, CAMPAIGN_END }

var mission: Mission
var mode: Mode = Mode.BRIEF
var result_text := ""
var result_ok := true
## "Next: ..." / "Falling back to: ..." — the branch, shown before you take it.
var next_line := ""
var roster: Array[Pilot] = []

var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_briefing(m: Mission, p_roster: Array[Pilot] = []) -> void:
	mission = m
	mode = Mode.BRIEF
	roster = p_roster
	visible = true
	queue_redraw()

func show_debrief(m: Mission, complete: bool, p_next := "", p_roster: Array[Pilot] = []) -> void:
	mission = m
	mode = Mode.DEBRIEF
	result_ok = complete
	result_text = "MISSION COMPLETE" if complete else "MISSION FAILED"
	next_line = p_next
	roster = p_roster
	visible = true
	queue_redraw()

func show_campaign_end(campaign_title: String, won: bool, p_roster: Array[Pilot]) -> void:
	mode = Mode.CAMPAIGN_END
	result_ok = won
	result_text = "CAMPAIGN COMPLETE" if won else "CAMPAIGN OVER"
	next_line = campaign_title
	roster = p_roster
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
	elif mode == Mode.DEBRIEF and key.physical_keycode == KEY_N:
		next_mission_requested.emit()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if mission == null and mode != Mode.CAMPAIGN_END:
		return
	var debrief := mode != Mode.BRIEF
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
	var sub := next_line if mode == Mode.CAMPAIGN_END else (mission.title if debrief else mission.subtitle)
	_text(Vector2(x, y + 48), sub, DIM, 15)
	y += 76

	if mode == Mode.CAMPAIGN_END:
		y = _draw_squadron(x, y)
		_text(Vector2(x, y + 20), "SPACE — start a new campaign      ESC — quit", AMBER, 15)
		return

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

	y += 14
	y = _draw_squadron(x, y)

	if next_line != "":
		_text(Vector2(x, y), next_line, Color(0.86, 0.90, 0.92), 15)
		y += 26

	draw_line(Vector2(x, y - 4), Vector2(x + w, y - 4), Color(GREEN, 0.25), 1.0)
	var footer := "SPACE — launch"
	if debrief:
		footer = "SPACE — fly it again      N — accept and continue      ESC — quit"
	_text(Vector2(x, y + 18), footer, AMBER, 15)

## Who is flying and who is not coming back. Losses are the whole point of
## naming them, so they stay on the board for the rest of the campaign.
func _draw_squadron(x: float, y: float) -> float:
	if roster.is_empty():
		return y
	_text(Vector2(x, y), "SQUADRON", DIM, 13)
	y += 22
	for p in roster:
		var colour := Color(0.86, 0.90, 0.92) if p.alive else Color(RED, 0.75)
		var status := "ready" if p.alive else "lost"
		_text(Vector2(x, y), "%-6s %-16s %s" % [p.callsign, p.name_full, status], colour, 14)
		y += 20
	return y + 10

func _text(p: Vector2, s: String, c: Color, size_px: int) -> void:
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, 1400.0, size_px, c)
