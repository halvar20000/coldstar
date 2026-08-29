extends Node3D
## Hosts the world and runs whichever Mission is loaded. The M0 scenario is gone:
## everything that used to be hardcoded here now lives in a .tres under
## data/missions, which is the point of M1.

const CAMPAIGN_PATH := "res://data/campaigns/accord.tres"
## Direct mission access for testing (--mission=N); the campaign decides the
## order in normal play.
const MISSIONS := [
	"res://data/missions/01_intercept.tres",
	"res://data/missions/02_escort.tres",
	"res://data/missions/03_regroup.tres",
]

var mission: Mission
var mission_index := 0
var campaign: Campaign
var state: CampaignState
var campaign_mode := true
var _last_result_complete := false
var runner: MissionRunner
var player: PlayerShip
var hud: HUD
var cockpit: Cockpit
var chase_cam: Camera3D
var tuning: TuningPanel
var briefing: BriefingScreen
var starfield: Starfield
var ui_layer: CanvasLayer

var _cockpit_view := true
var _shot_path := ""
var _shot_after := 2.5
var _shot_taken := false
var _boot_chase := false
var _selftest_seconds := 0.0
var _verbose := false
var _seed := 1
var _padtest := false
var _skip_briefing := false

func _ready() -> void:
	# The briefing and debrief pause the tree, so Main itself must keep
	# processing — otherwise nothing can drive the screen that unpauses it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_cmdline()
	_build_environment()
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	briefing = BriefingScreen.new()
	ui_layer.add_child(briefing)
	briefing.launch_requested.connect(func() -> void:
		if briefing.mode == BriefingScreen.Mode.CAMPAIGN_END:
			_restart_campaign()
		else:
			_launch())
	briefing.next_mission_requested.connect(_next_mission)
	campaign = load(CAMPAIGN_PATH) as Campaign
	if campaign_mode:
		state = CampaignState.load_or_new(campaign)
		_load_campaign_mission()
	else:
		state = CampaignState.fresh(campaign)
		_load_mission(mission_index)
	if _skip_briefing:
		_launch()
	else:
		get_tree().paused = true
		briefing.show_briefing(mission, state.roster)

func _parse_cmdline() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--shot-after="):
			_shot_after = float(a.split("=")[-1])
		elif a == "--chase":
			_boot_chase = true
		elif a.begins_with("--selftest"):
			_selftest_seconds = float(a.split("=")[-1]) if "=" in a else 180.0
			_skip_briefing = true
		elif a == "--verbose":
			_verbose = true
		elif a == "--padtest":
			_padtest = true
			_skip_briefing = true
		elif a.begins_with("--seed="):
			_seed = int(a.split("=")[-1])
		elif a.begins_with("--mission="):
			var v := a.split("=")[-1]
			mission_index = int(v) - 1 if v.is_valid_int() else 0
			campaign_mode = false
		elif a == "--newcampaign":
			CampaignState.wipe()
		elif a == "--nobrief":
			_skip_briefing = true

func _load_campaign_mission() -> void:
	var node := campaign.node(state.node_id)
	if node == null:
		state = CampaignState.fresh(campaign)
		node = campaign.node(state.node_id)
	mission = load(node.mission_path) as Mission

## What the branch will do with this result — shown before you commit to it.
func _branch_preview(complete: bool) -> String:
	if not campaign_mode:
		return ""
	var node := campaign.node(state.node_id)
	if node == null:
		return ""
	var next_id := node.on_complete if complete else node.on_fail
	if next_id == "":
		return "This ends the campaign." if complete else "There is nothing left to fall back to."
	var next_node := campaign.node(next_id)
	if next_node == null:
		return ""
	var next_mission := load(next_node.mission_path) as Mission
	var lead := "Next:" if complete else "Falling back to:"
	return "%s  %s" % [lead, next_mission.title]

func _load_mission(index: int) -> void:
	mission_index = clampi(index, 0, MISSIONS.size() - 1)
	mission = load(MISSIONS[mission_index]) as Mission

# --- world ---------------------------------------------------------------

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
		var pos := Vector3(rng.randf_range(-3000, 3000), rng.randf_range(-900, 900), rng.randf_range(-3000, 3000))
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var s := rng.randf_range(6.0, 30.0)
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(s, s * 0.8, s * 1.2)), pos))
	debris.multimesh = mm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.20, 0.19, 0.18)
	rmat.roughness = 1.0
	debris.material_override = rmat
	add_child(debris)

# --- flight --------------------------------------------------------------

func _launch() -> void:
	_teardown()
	get_tree().paused = false
	briefing.visible = false

	runner = MissionRunner.new()
	runner.name = "MissionRunner"
	runner.roster = state.roster
	add_child(runner)
	player = runner.setup(mission, self)
	runner.state_changed.connect(_on_mission_ended)
	runner.pilot_lost.connect(func(_p: Pilot) -> void:
		if campaign_mode:
			state.save())
	runner.announce.connect(func(text: String, secs: float) -> void: hud.message(text, secs))
	player.damaged.connect(func(_s, _a, _f) -> void: hud.flash_damage())
	player.wing_command.connect(func(cmd: AIFighter.WingOrder) -> void: runner.command_wing(cmd, player))
	player.invert_toggled.connect(_announce_pitch)

	starfield = Starfield.new()
	add_child(starfield)
	starfield.setup(player)

	cockpit = Cockpit.new()
	cockpit.setup(player)
	chase_cam = Camera3D.new()
	chase_cam.name = "ChaseCam"
	chase_cam.fov = 70.0
	chase_cam.far = 30000.0
	add_child(chase_cam)

	hud = HUD.new()
	hud.player = player
	hud.runner = runner
	ui_layer.add_child(hud)
	ui_layer.move_child(briefing, ui_layer.get_child_count() - 1)
	tuning = TuningPanel.new()
	ui_layer.add_child(tuning)
	tuning.setup(player)

	_set_view(not _boot_chase)
	hud.message(mission.title.to_upper(), 3.0)

	if _padtest:
		var pt := PadTest.new()
		add_child(pt)
		pt.run(player)
	if _selftest_seconds > 0.0:
		var st := SelfTest.new()
		add_child(st)
		st.start(player, _selftest_seconds, _verbose, _seed, runner)

func _teardown() -> void:
	for s in Combat.ships.duplicate():
		if is_instance_valid(s):
			s.queue_free()
	Combat.clear()
	for node in [runner, starfield, chase_cam, hud, tuning]:
		if is_instance_valid(node):
			node.queue_free()
	runner = null
	starfield = null
	chase_cam = null
	hud = null
	tuning = null

func _on_mission_ended(result: MissionRunner.State) -> void:
	get_tree().paused = true
	_last_result_complete = result == MissionRunner.State.COMPLETE
	briefing.show_debrief(mission, _last_result_complete,
		_branch_preview(_last_result_complete), state.roster)

## N at the debrief. Only here does the campaign actually move — so you can
## replay a mission you botched before committing to the branch it sends you down.
func _next_mission() -> void:
	get_tree().paused = true
	if not campaign_mode:
		_load_mission((mission_index + 1) % MISSIONS.size())
		briefing.show_briefing(mission, state.roster)
		return
	var next_id := state.advance(campaign, _last_result_complete)
	if next_id == "":
		briefing.show_campaign_end(campaign.title, _last_result_complete, state.roster)
		return
	_load_campaign_mission()
	briefing.show_briefing(mission, state.roster)

func _restart_campaign() -> void:
	CampaignState.wipe()
	state = CampaignState.fresh(campaign)
	_load_campaign_mission()
	get_tree().paused = true
	briefing.show_briefing(mission, state.roster)

func _process(dt: float) -> void:
	if is_instance_valid(player) and not player.dead and is_instance_valid(chase_cam):
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
	if event.is_action("quit"):
		get_tree().quit()
	elif briefing.visible:
		return
	elif event.is_action("view_cockpit"):
		_set_view(true)
	elif event.is_action("view_chase"):
		_set_view(false)
	elif event.is_action("view_toggle"):
		_set_view(not _cockpit_view)
	elif event.is_action("toggle_invert"):
		_announce_pitch()
	elif event.is_action("view_tuning"):
		tuning.visible = not tuning.visible
	elif event.is_action("scenario_reset"):
		_launch()

## Say out loud what the setting now is. A silent inversion toggle is how you
## end up flying a whole mission fighting your own controls.
func _announce_pitch() -> void:
	Settings.toggle_invert_pitch()
	if hud != null:
		hud.message("PITCH: %s" % Settings.pitch_label(), 3.0)

func _set_view(cockpit_view: bool) -> void:
	_cockpit_view = cockpit_view
	cockpit.set_active(cockpit_view)
	if cockpit_view:
		hud.camera = cockpit.camera
	else:
		chase_cam.make_current()
		hud.camera = chase_cam
