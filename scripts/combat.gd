extends Node
## Tiny global registry so bolts, AI and the HUD can find every live craft
## without walking the scene tree each frame. Autoloaded as `Combat`.

var ships: Array[Ship] = []
var player: Ship = null

func register(s: Ship) -> void:
	if s not in ships:
		ships.append(s)

func unregister(s: Ship) -> void:
	ships.erase(s)
	if player == s:
		player = null

func clear() -> void:
	ships.clear()
	player = null

func enemies_of(faction: String) -> Array[Ship]:
	var out: Array[Ship] = []
	for s in ships:
		if is_instance_valid(s) and not s.dead and s.faction != faction:
			out.append(s)
	return out

func spawn_bolt(parent: Node, from: Vector3, dir: Vector3, shooter: Ship) -> void:
	var p := shooter.profile
	var bolt := LaserBolt.new()
	var mesh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 14.0
	mesh.mesh = cap
	mesh.rotation_degrees.x = 90.0     # capsule is Y-up, bolt flies down -Z
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.2) if shooter.faction == "dominion" else Color(0.4, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	bolt.add_child(mesh)
	parent.add_child(bolt)
	bolt.setup(from, dir, p.bolt_speed, p.laser_damage, shooter, shooter.faction, p.bolt_life)

func spawn_impact(parent: Node, at: Vector3) -> void:
	_flash(parent, at, Color(1.0, 0.88, 0.5), 3.0, 3.0, 0.14)

func spawn_explosion(parent: Node, at: Vector3) -> void:
	# Two shells: a hot core that dies fast and a slower orange bloom. Additive
	# blending keeps it reading as light rather than as a painted ball.
	_flash(parent, at, Color(1.0, 0.95, 0.75), 7.0, 3.2, 0.35)
	_flash(parent, at, Color(1.0, 0.45, 0.12), 10.0, 4.5, 0.85)

func _flash(parent: Node, at: Vector3, colour: Color, size: float, grow: float, dur: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var m := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = size
	sph.height = size * 2.0
	m.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = colour
	m.material_override = mat
	parent.add_child(m)
	m.global_position = at
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * grow, dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(m.queue_free)
