extends Node3D
## M0 scenario: one Lancet, three Vex interceptors, empty space. No mission
## system yet — that is M1, and it is the piece that decides whether this
## project survives past mission four, so it gets built properly rather than
## smuggled in here.

const PLAYER_PROFILE := preload("res://data/lancet.tres")
const ENEMY_PROFILE := preload("res://data/vex.tres")
const ENEMY_COUNT := 3

var player: PlayerShip
var hud: HUD
var cockpit: Cockpit
var chase_cam: Camera3D
var tuning: TuningPanel
var _cockpit_view := true

var _shot_path := ""
var _boot_chase := false
var _selftest_seconds := 0.0
var _verbose := false
var _seed := 1
var _padtest := false
var _shot_after := 2.5
var _shot_taken := false

func _ready() -> void:
	_parse_cmdline()
	_build_environment()
	_spawn_scenario()

func _parse_cmdline() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--shot-after="):
			_shot_after = float(a.split("=")[-1])
		elif a == "--chase":
			_boot_chase = true
		elif a.begins_with("--selftest"):
			_selftest_seconds = float(a.split("=")[-1]) if "=" in a else 90.0
		elif a == "--verbose":
			_verbose = true
		elif a == "--padtest":
			_padtest = true
		elif a.begins_with("--seed="):
			_seed = int(a.split("=")[-1])

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.010, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.19, 0.26)
	env.ambient_light_energy = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.rotation_degrees = Vector3(-28, 140, 0)
	add_child(sun)

	# Fill from the opposite side. Without it a ship viewed from astern with the
	# sun ahead is a black cutout, and you cannot judge your own attitude.
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.light_color = Color(0.62, 0.72, 0.95)
	fill.rotation_degrees = Vector3(35, -40, 0)
	fill.shadow_enabled = false
	add_child(fill)

	var debris := MultiMeshInstance3D.new()
	debris.name = "Debris"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 8
	rock.rings = 5
	mm.mesh = rock
	mm.instance_count = 90
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in mm.instance_count:
		var pos := Vector3(rng.randf_range(-2500, 2500), rng.randf_range(-900, 900), rng.randf_range(-2500, 2500))
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var s := rng.randf_range(6.0, 34.0)
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(s, s * 0.8, s * 1.2)), pos))
	debris.multimesh = mm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.20, 0.19, 0.18)
	rmat.roughness = 1.0
	debris.material_override = rmat
	add_child(debris)

func _spawn_scenario() -> void:
	player = PlayerShip.new()
	player.name = "Player"
	add_child(player)
	player.setup(PLAYER_PROFILE.duplicate(true))
	player.throttle_input = 0.66
	player.flight.speed = player.flight.max_speed() * 0.66
	player.damaged.connect(_on_player_damaged)
	player.destroyed.connect(_on_player_destroyed)

	var starfield := Starfield.new()
	add_child(starfield)
	starfield.setup(player)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in ENEMY_COUNT:
		var e := AIFighter.new()
		e.name = "Vex%d" % (i + 1)
		add_child(e)
		e.setup(ENEMY_PROFILE.duplicate(true))
		e.skill = 0.45 + 0.2 * i
		e.global_position = Vector3(rng.randf_range(-400, 400), rng.randf_range(-200, 200), -2400.0 - i * 260.0)
		e.look_at(player.global_position, Vector3.UP)
		e.flight.throttle = 1.0
		e.flight.speed = e.profile.rated_speed

	cockpit = Cockpit.new()
	cockpit.setup(player)

	chase_cam = Camera3D.new()
	chase_cam.fov = 70.0
	chase_cam.far = 30000.0
	add_child(chase_cam)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	hud.player = player
	layer.add_child(hud)
	tuning = TuningPanel.new()
	layer.add_child(tuning)
	tuning.setup(player)

	if _padtest:
		var pt := PadTest.new()
		add_child(pt)
		pt.run(player)

	if _selftest_seconds > 0.0:
		var st := SelfTest.new()
		add_child(st)
		st.start(player, _selftest_seconds, _verbose, _seed)

	_set_view(not _boot_chase)
	hud.message("THREE DOMINION INTERCEPTORS INBOUND", 4.0)

func _process(dt: float) -> void:
	if is_instance_valid(player) and not player.dead:
		_update_chase(dt)
	if _shot_path != "" and not _shot_taken:
		_shot_after -= dt
		if _shot_after <= 0.0:
			_shot_taken = true
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_path)
			print("screenshot -> ", _shot_path)
			get_tree().quit()

func _update_chase(dt: float) -> void:
	var back := player.global_transform.basis.z * 34.0 + player.global_transform.basis.y * 9.0
	var want := player.global_position + back
	chase_cam.global_position = chase_cam.global_position.lerp(want, clampf(dt * 6.0, 0, 1))
	chase_cam.look_at(player.global_position + player.global_transform.basis.y * 2.0,
		player.global_transform.basis.y)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("view_cockpit"):
		_set_view(true)
	elif event.is_action("view_chase"):
		_set_view(false)
	elif event.is_action("view_toggle"):
		_set_view(not _cockpit_view)
	elif event.is_action("view_tuning"):
		tuning.visible = not tuning.visible
	elif event.is_action("scenario_reset"):
		_reset()
	elif event.is_action("quit"):
		get_tree().quit()

func _set_view(cockpit_view: bool) -> void:
	_cockpit_view = cockpit_view
	cockpit.set_active(cockpit_view)
	if cockpit_view:
		hud.camera = cockpit.camera
	else:
		chase_cam.make_current()
		hud.camera = chase_cam

func _on_player_damaged(_s: Ship, _amount: float, _fore: bool) -> void:
	hud.flash_damage()

func _on_player_destroyed(_s: Ship) -> void:
	hud.message("", 0.0)

func _reset() -> void:
	for s in Combat.ships.duplicate():
		if is_instance_valid(s):
			s.queue_free()
	Combat.clear()
	for child in get_children():
		if child is Starfield or child is CanvasLayer or child is Camera3D:
			child.queue_free()
	await get_tree().process_frame
	_spawn_scenario()
