class_name HUD
extends Control
## Cockpit instrumentation, drawn in one immediate-mode pass. Everything the
## pilot needs to explain a fight after the fact is on screen: which way power
## is flowing, which shield face is thin, what the AI is currently doing, and
## where the target is when it's not in front of you.

var player: PlayerShip
var camera: Camera3D
var show_debug := true

const AMBER := Color(1.0, 0.72, 0.20)
const GREEN := Color(0.35, 1.0, 0.55)
const RED := Color(1.0, 0.35, 0.30)
const DIM := Color(0.55, 0.62, 0.66)
const PANEL_BG := Color(0.02, 0.05, 0.06, 0.55)

const RADAR_R := 62.0

var _font: Font
var _damage_flash := 0.0
var _msg := ""
var _msg_time := 0.0

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	# Under a CanvasLayer the anchor preset alone does not reliably track the
	# window, and a stale rect puts the whole panel set off-screen.
	size = get_viewport_rect().size
	_damage_flash = maxf(0.0, _damage_flash - dt * 2.0)
	_msg_time = maxf(0.0, _msg_time - dt)
	queue_redraw()

func flash_damage() -> void:
	_damage_flash = 1.0

func message(text: String, seconds := 3.0) -> void:
	_msg = text
	_msg_time = seconds

func _draw() -> void:
	if player == null or not is_instance_valid(player) or camera == null:
		_dead_screen()
		return
	var vp := size
	_draw_reticle(vp)
	_draw_target_overlay(vp)
	_draw_power(vp)
	_draw_shields(vp)
	_draw_throttle(vp)
	_draw_cmd(vp)
	_draw_radar(vp)
	if _damage_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 0.2, 0.15, _damage_flash * 0.22))
	if _msg_time > 0.0:
		_text(Vector2(vp.x * 0.5, vp.y * 0.28), _msg, AMBER, 22, HORIZONTAL_ALIGNMENT_CENTER)
	if show_debug:
		_draw_debug(vp)

func _dead_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	_text(size * 0.5, "CRAFT DESTROYED", RED, 32, HORIZONTAL_ALIGNMENT_CENTER)
	_text(size * 0.5 + Vector2(0, 34), "F5 to reset the engagement", DIM, 16, HORIZONTAL_ALIGNMENT_CENTER)

# --- gunsight -----------------------------------------------------------

func _draw_reticle(vp: Vector2) -> void:
	var c := vp * 0.5
	var col := GREEN if player.can_fire() else DIM
	draw_arc(c, 26.0, 0, TAU, 48, col, 1.5)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * 26.0, c + d * 34.0, col, 1.5)
	draw_line(c - Vector2(5, 0), c + Vector2(5, 0), col, 1.0)
	draw_line(c - Vector2(0, 5), c + Vector2(0, 5), col, 1.0)

func _draw_target_overlay(vp: Vector2) -> void:
	var t := player.target
	if t == null or not is_instance_valid(t) or t.dead:
		return
	var box_col := RED
	var pos3 := t.global_position
	if camera.is_position_behind(pos3):
		_offscreen_arrow(vp, pos3, box_col)
		return
	var p := camera.unproject_position(pos3)
	var dist := player.global_position.distance_to(pos3)
	var half := clampf(3000.0 / maxf(dist, 40.0), 12.0, 90.0)
	_bracket(p, half, box_col)
	_text(p + Vector2(half + 6, -half), "%s" % t.profile.display_name, box_col, 13)
	_text(p + Vector2(half + 6, -half + 15), "%d m" % int(dist), box_col, 13)

	# Lead pipper: put this on the enemy and the shot connects.
	var lead := player.lead_point_for(t)
	if not camera.is_position_behind(lead):
		var lp := camera.unproject_position(lead)
		draw_arc(lp, 9.0, 0, TAU, 24, AMBER, 2.0)
		draw_line(lp - Vector2(13, 0), lp - Vector2(6, 0), AMBER, 2.0)
		draw_line(lp + Vector2(6, 0), lp + Vector2(13, 0), AMBER, 2.0)
		draw_line(p, lp, Color(AMBER.r, AMBER.g, AMBER.b, 0.25), 1.0)

func _bracket(p: Vector2, h: float, c: Color) -> void:
	var arm := h * 0.45
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := p + Vector2(sx * h, sy * h)
			draw_line(corner, corner - Vector2(sx * arm, 0), c, 2.0)
			draw_line(corner, corner - Vector2(0, sy * arm), c, 2.0)

func _offscreen_arrow(vp: Vector2, world: Vector3, c: Color) -> void:
	var local := camera.global_transform.affine_inverse() * world
	var dir := Vector2(local.x, -local.y)
	if dir.length() < 0.001:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var centre := vp * 0.5
	var p := centre + dir * (minf(vp.x, vp.y) * 0.42)
	var a := dir.angle()
	var pts := PackedVector2Array([
		p + Vector2(cos(a), sin(a)) * 14.0,
		p + Vector2(cos(a + 2.5), sin(a + 2.5)) * 10.0,
		p + Vector2(cos(a - 2.5), sin(a - 2.5)) * 10.0,
	])
	draw_colored_polygon(pts, c)
	_text(p + dir * 26.0 - Vector2(20, 0), "BEHIND", c, 12)

# --- power / shields / throttle -----------------------------------------
#
# Everything below is laid out from the bottom edge of the viewport, so the
# instrument band survives any window size instead of walking off screen.

func _draw_power(vp: Vector2) -> void:
	var x := 24.0
	var y := vp.y - 214.0
	_panel(Rect2(x - 10, y - 22, 196, 172))
	_text(Vector2(x, y), "POWER", DIM, 13)
	_pip_row(Vector2(x, y + 8), "ENG", player.power.engine_pips(), GREEN)
	_pip_row(Vector2(x, y + 32), "LAS", player.power.laser_pips, AMBER)
	_pip_row(Vector2(x, y + 56), "SHD", player.power.shield_pips, Color(0.45, 0.75, 1.0))
	var frac := player.laser_energy / player.profile.laser_capacity
	_bar(Rect2(x, y + 92, 166, 12), frac, AMBER, "LASERS")
	var link_names := ["SINGLE", "DUAL", "QUAD"]
	_text(Vector2(x, y + 124), "LINK  %s   (V)" % link_names[player.link], DIM, 13)
	_text(Vector2(x, y + 142), "A/Z las   S/X shd   E shunt   D reset", Color(DIM, 0.55), 10)

func _pip_row(p: Vector2, label: String, pips: int, col: Color) -> void:
	_text(p + Vector2(0, 12), label, DIM, 13)
	for i in PowerSystem.TOTAL_PIPS:
		var r := Rect2(p.x + 44 + i * 26, p.y + 1, 20, 13)
		draw_rect(r, Color(col, 0.9) if i < pips else Color(col, 0.14), true)
		draw_rect(r, Color(col, 0.5), false, 1.0)

func _draw_shields(vp: Vector2) -> void:
	var w := 150.0
	var x := vp.x - w - 24.0
	var y := vp.y - 214.0
	_panel(Rect2(x - 10, y - 22, w + 20, 172))
	_text(Vector2(x, y), "SHIELDS", DIM, 13)
	var maxs := maxf(player.profile.shield_max, 0.001)
	_bar(Rect2(x, y + 20, w, 14), player.shield_fore / maxs, Color(0.45, 0.75, 1.0), "FORE")
	_bar(Rect2(x, y + 56, w, 14), player.shield_aft / maxs, Color(0.45, 0.75, 1.0), "AFT")
	var cfg := "BALANCED"
	if player.shield_bias > 0.5:
		cfg = "FORWARD"
	elif player.shield_bias < -0.5:
		cfg = "AFT"
	_text(Vector2(x, y + 92), "CFG  %s  (F)" % cfg, DIM, 12)
	_bar(Rect2(x, y + 122, w, 14), player.hull / player.profile.hull_max,
		GREEN if player.hull > player.profile.hull_max * 0.4 else RED, "HULL")

func _draw_throttle(vp: Vector2) -> void:
	var x := 24.0
	var y := vp.y - 252.0
	var spd := player.flight.speed
	_text(Vector2(x, y), "SPD %3d" % int(round(spd)), GREEN, 20)
	_text(Vector2(x + 104, y), "THR %3d%%" % int(round(player.throttle_input * 100.0)), DIM, 16)
	var w := 166.0
	draw_rect(Rect2(x, y + 8, w, 6), Color(GREEN, 0.15), true)
	draw_rect(Rect2(x, y + 8, w * clampf(spd / maxf(player.flight.max_speed(), 1.0), 0, 1), 6), GREEN, true)
	var tx := x + w * player.throttle_input
	draw_line(Vector2(tx, y + 3), Vector2(tx, y + 19), AMBER, 2.0)

func _draw_cmd(vp: Vector2) -> void:
	var w := 250.0
	var x := vp.x * 0.5 - w * 0.5
	var y := vp.y - 214.0
	_panel(Rect2(x - 10, y - 22, w + 20, 122))
	var t := player.target
	if t == null or not is_instance_valid(t) or t.dead:
		_text(Vector2(x, y), "NO TARGET", DIM, 14)
		_text(Vector2(x, y + 22), "R nearest   T cycle   G gunsight", Color(DIM, 0.55), 11)
		return
	var dist := player.global_position.distance_to(t.global_position)
	var closure := (player.flight.velocity - t.flight.velocity).dot(
		(t.global_position - player.global_position).normalized())
	_text(Vector2(x, y), t.profile.display_name, RED, 15)
	_text(Vector2(x, y + 18), "%5d m    %+4d m/s" % [int(dist), int(closure)], DIM, 13)
	if t.profile.shield_max > 0.0:
		_bar(Rect2(x, y + 40, w, 10), t.shield_pct(), Color(0.45, 0.75, 1.0), "SHD")
	_bar(Rect2(x, y + 68, w, 10), t.hull / t.profile.hull_max, RED, "HULL")
	if show_debug and t is AIFighter:
		_text(Vector2(x, y + 96), "AI: %s" % (t as AIFighter).state_name(), Color(DIM, 0.8), 12)

func _draw_radar(vp: Vector2) -> void:
	var cy := vp.y - 78.0
	var fore := Vector2(vp.x * 0.5 - 222.0, cy)
	var aft := Vector2(vp.x * 0.5 + 222.0, cy)
	_radar_dish(fore, "FORE")
	_radar_dish(aft, "AFT")
	var inv := player.global_transform.affine_inverse()
	for s in Combat.ships:
		if s == player or not is_instance_valid(s) or s.dead:
			continue
		var local := inv * s.global_position
		var dist := local.length()
		if dist > 12000.0 or dist < 0.01:
			continue
		var dir := local / dist
		var is_fore := dir.z < 0.0
		# Radius is angle off the nose (or tail), so a contact drifting to the
		# rim is one about to slide out of the forward hemisphere.
		var r := (acos(clampf(absf(dir.z), 0.0, 1.0)) / (PI * 0.5)) * RADAR_R
		var flat := Vector2(dir.x, -dir.y)
		flat = flat.normalized() if flat.length() > 0.0001 else Vector2(0, -1)
		if not is_fore:
			flat.x = -flat.x
		var p := (fore if is_fore else aft) + flat * r
		var near := clampf(1.0 - dist / 6000.0, 0.15, 1.0)
		var col := RED if s.faction != player.faction else GREEN
		draw_circle(p, 2.0 + near * 2.5, Color(col, 0.35 + near * 0.65))
		if s == player.target:
			draw_arc(p, 6.5, 0, TAU, 16, AMBER, 1.5)

func _radar_dish(c: Vector2, label: String) -> void:
	draw_circle(c, RADAR_R, Color(0.05, 0.12, 0.14, 0.55))
	draw_arc(c, RADAR_R, 0, TAU, 48, Color(GREEN, 0.45), 1.5)
	draw_arc(c, RADAR_R * 0.5, 0, TAU, 32, Color(GREEN, 0.2), 1.0)
	draw_line(c - Vector2(RADAR_R, 0), c + Vector2(RADAR_R, 0), Color(GREEN, 0.18), 1.0)
	draw_line(c - Vector2(0, RADAR_R), c + Vector2(0, RADAR_R), Color(GREEN, 0.18), 1.0)
	_text(c + Vector2(0, -RADAR_R - 6), label, Color(DIM, 0.8), 11, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_debug(vp: Vector2) -> void:
	var lines := [
		"%d fps" % Engine.get_frames_per_second(),
		"hostiles %d" % Combat.enemies_of(player.faction).size(),
		"pos %.0f %.0f %.0f" % [player.global_position.x, player.global_position.y, player.global_position.z],
		"F1 cockpit   F2 chase   F3 tuning   F5 reset",
	]
	var y := 18.0
	for l in lines:
		_text(Vector2(vp.x - 16, y), l, Color(DIM, 0.7), 12, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 16.0

# --- primitives ---------------------------------------------------------

func _panel(r: Rect2) -> void:
	draw_rect(r, PANEL_BG, true)
	draw_rect(r, Color(GREEN, 0.18), false, 1.0)

func _bar(r: Rect2, frac: float, col: Color, label: String) -> void:
	frac = clampf(frac, 0.0, 1.0)
	draw_rect(r, Color(col, 0.12), true)
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), col, true)
	draw_rect(r, Color(col, 0.45), false, 1.0)
	_text(r.position + Vector2(0, -3), label, Color(DIM, 0.85), 11)

func _text(p: Vector2, s: String, c: Color, size_px: int, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# Wide enough that centred callouts are never clipped mid-word.
	var width := 1400.0
	var pos := p
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		pos.x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		pos.x -= width
	draw_string(_font, pos, s, align, width, size_px, c)
