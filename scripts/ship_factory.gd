class_name ShipFactory
extends RefCounted
## Procedural hulls. M0 deliberately ships no modelled art: the point of this
## milestone is whether flying feels right, and blocky originals answer that
## just as well as finished models would. When the Blender pipeline lands,
## replace the mesh children here and nothing else changes.

static func build(ship: Node3D, profile: ShipProfile) -> Array[Vector3]:
	var accent := Color(0.45, 0.72, 1.0) if profile.faction == "accord" else Color(0.95, 0.25, 0.2)
	var hull := Color(0.70, 0.72, 0.76) if profile.faction == "accord" else Color(0.26, 0.27, 0.31)
	match profile.silhouette:
		"vex":
			return _vex(ship, hull, accent)
		_:
			return _lancet(ship, hull, accent)

## AF-4 Lancet - Accord light strike fighter. Long spine, forward-swept wings,
## four wingtip cannons, twin nacelles.
static func _lancet(ship: Node3D, hull: Color, accent: Color) -> Array[Vector3]:
	_box(ship, Vector3(2.4, 1.9, 13.0), Vector3(0, 0, 0), Vector3.ZERO, hull, "Fuselage")
	_prism(ship, Vector3(2.2, 1.6, 4.5), Vector3(0, 0, -8.2), Vector3(-90, 0, 0), hull, "Nose")
	_box(ship, Vector3(1.6, 1.0, 2.4), Vector3(0, 1.2, -2.6), Vector3.ZERO, accent * 0.6, "Canopy")
	for side in [-1.0, 1.0]:
		# Wing: swept FORWARD and given dihedral, so the planform is legible
		# from dead astern — which is the angle you see your own ship from.
		_box(ship, Vector3(8.4, 0.30, 3.0), Vector3(side * 5.2, 0.55, 1.6),
			Vector3(0, side * -16.0, side * 10.0), hull)
		# wing root pylon tying it into the spine
		_box(ship, Vector3(2.0, 0.7, 3.4), Vector3(side * 1.5, 0.25, 1.6), Vector3(0, 0, side * 6.0), hull * 0.85)
		# cannon barrel at the tip, pointing where the bolts actually come from
		_cyl(ship, 0.30, 4.6, Vector3(side * 9.0, 1.05, -1.0), accent * 0.8)
		_box(ship, Vector3(0.7, 0.7, 1.6), Vector3(side * 9.0, 1.05, 1.0), Vector3.ZERO, hull * 0.7)
		# engine nacelle low and inboard, exhaust facing aft
		_box(ship, Vector3(1.1, 1.1, 5.4), Vector3(side * 2.2, -1.0, 3.0), Vector3.ZERO, hull * 0.8)
		_cyl(ship, 0.75, 1.4, Vector3(side * 2.2, -1.0, 5.9), accent)
		# ventral fin
		_prism(ship, Vector3(0.2, 1.6, 2.4), Vector3(side * 2.2, -2.1, 4.2), Vector3(0, 0, 180), hull * 0.7)
	# dorsal fin
	_prism(ship, Vector3(0.25, 2.4, 3.0), Vector3(0, 2.1, 4.6), Vector3.ZERO, hull * 0.9)
	var hp: Array[Vector3] = [
		Vector3(-9.0, 1.05, -3.3), Vector3(9.0, 1.05, -3.3),
		Vector3(-9.0, 1.05, -3.3), Vector3(9.0, 1.05, -3.3),
	]
	return hp

## Vex - Dominion interceptor. Wide unshielded delta, fast, fragile, two guns.
static func _vex(ship: Node3D, hull: Color, accent: Color) -> Array[Vector3]:
	_box(ship, Vector3(2.0, 1.4, 9.0), Vector3.ZERO, Vector3.ZERO, hull)
	_prism(ship, Vector3(2.0, 1.2, 3.0), Vector3(0, 0, -5.8), Vector3(-90, 0, 0), hull)
	_box(ship, Vector3(1.3, 0.9, 2.0), Vector3(0, 0.9, -1.4), Vector3.ZERO, accent * 0.5)
	for side in [-1.0, 1.0]:
		_prism(ship, Vector3(7.0, 0.3, 7.5), Vector3(side * 3.9, 0, 0.6), Vector3(-90, 0, side * 90.0), hull)
		_box(ship, Vector3(0.5, 1.6, 2.0), Vector3(side * 7.0, 0.7, 2.6), Vector3.ZERO, accent)
	_cyl(ship, 1.0, 3.0, Vector3(0, 0, 4.2), accent)
	var hp: Array[Vector3] = [Vector3(-6.6, 0.0, -2.0), Vector3(6.6, 0.0, -2.0)]
	return hp

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.35
	m.roughness = 0.55
	return m

static func _add(ship: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, c: Color, node_name := "Part") -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	ship.add_child(mi)

static func _box(ship: Node3D, size: Vector3, pos: Vector3, rot: Vector3, c: Color, node_name := "Part") -> void:
	var m := BoxMesh.new()
	m.size = size
	_add(ship, m, pos, rot, c, node_name)

static func _prism(ship: Node3D, size: Vector3, pos: Vector3, rot: Vector3, c: Color, node_name := "Part") -> void:
	var m := PrismMesh.new()
	m.size = size
	_add(ship, m, pos, rot, c, node_name)

static func _cyl(ship: Node3D, radius: float, height: float, pos: Vector3, c: Color, node_name := "Part") -> void:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius * 0.8
	m.height = height
	_add(ship, m, pos, Vector3(90, 0, 0), c, node_name)
