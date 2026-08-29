class_name Starfield
extends Node3D
## Stars, a distant sun and one planet. Pure empty space gives the eye nothing
## to judge rotation against, and a flight-feel test with no motion cues is
## unreadable — so M0 gets a horizon substitute even though "space is free".

const STAR_COUNT := 2200
const SHELL_RADIUS := 9000.0

var _follow: Node3D

func setup(follow: Node3D) -> void:
	_follow = follow
	_build_stars()
	_build_planet()

func _process(_dt: float) -> void:
	if is_instance_valid(_follow):
		global_position = _follow.global_position

func _build_stars() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(30.0, 30.0)
	mm.mesh = quad
	mm.instance_count = STAR_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260829
	for i in STAR_COUNT:
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var pos := dir * SHELL_RADIUS
		# Orientation is irrelevant: the material billboards every quad.
		var s := rng.randf_range(0.4, 2.2)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), pos))
		var warmth := rng.randf()
		var c := Color(1.0, 0.92 + warmth * 0.08, 0.85 + warmth * 0.15)
		mm.set_instance_color(i, c * rng.randf_range(0.35, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_receive_shadows = true
	mmi.material_override = mat
	mmi.extra_cull_margin = 16384.0
	add_child(mmi)

func _build_planet() -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1400.0
	sph.height = 2800.0
	sph.radial_segments = 48
	sph.rings = 24
	mi.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.30, 0.42)
	mat.roughness = 0.9
	mat.rim_enabled = true
	mat.rim = 0.8
	mat.rim_tint = 0.6
	mi.material_override = mat
	mi.position = Vector3(-4200.0, -1600.0, -6500.0)
	mi.extra_cull_margin = 16384.0
	add_child(mi)
