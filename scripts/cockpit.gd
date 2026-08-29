class_name Cockpit
extends Node3D
## The pilot's office. Built from primitives for M0 — a canopy bow, side
## pillars, a dash lip and a control column — so the view out of the glass is
## framed rather than borderless. A framed view is what makes roll and pitch
## legible; a floating camera in empty space reads as nothing moving.
##
## The parts of the exterior hull that would sit inside the pilot's head are
## hidden while this view is active (HIDE_PARTS), the wings deliberately are
## not: seeing your own wingtips sweep past is half the sensation of a turn.

const HIDE_PARTS := ["Fuselage", "Nose", "Canopy"]
const EYE := Vector3(0.0, 1.25, -2.0)

var camera: Camera3D
var _ship: Ship

func setup(ship: Ship) -> void:
	_ship = ship
	ship.add_child(self)
	position = Vector3.ZERO
	_build_frame()
	camera = Camera3D.new()
	camera.position = EYE
	camera.fov = 78.0
	camera.near = 0.05
	camera.far = 30000.0
	add_child(camera)

func set_active(active: bool) -> void:
	visible = active
	if active:
		camera.make_current()
	for part_name in HIDE_PARTS:
		var n := _ship.get_node_or_null(NodePath(part_name))
		if n is MeshInstance3D:
			(n as MeshInstance3D).visible = not active

## All frame geometry is authored in EYE-relative metres: distances from the
## pilot's head are what decide how much of the screen a strut eats, and
## authoring in ship space made every part twice the size it looked on paper.
func _build_frame() -> void:
	var frame := Color(0.13, 0.14, 0.17)
	var trim := Color(0.19, 0.22, 0.26)
	var glass_w := 0.60      # half-width of the canopy opening
	# dash below the glass
	_part(Vector3(1.45, 0.34, 0.55), Vector3(0, -0.66, -0.80), Vector3(-12, 0, 0), frame)
	_part(Vector3(1.30, 0.08, 0.06), Vector3(0, -0.47, -1.02), Vector3(-12, 0, 0), trim)
	# canopy bow ahead, and the overhead spine running back over the pilot
	_part(Vector3(1.34, 0.06, 0.06), Vector3(0, 0.50, -1.04), Vector3.ZERO, frame)
	_part(Vector3(0.06, 0.06, 1.30), Vector3(0, 0.56, -0.35), Vector3.ZERO, frame)
	for side in [-1.0, 1.0]:
		# A-pillar: from the dash corner up to the bow
		_part(Vector3(0.055, 0.90, 0.055), Vector3(side * glass_w, 0.00, -1.02), Vector3(6, 0, side * 4.0), frame)
		# roof rail running back from the bow
		_part(Vector3(0.055, 0.055, 1.25), Vector3(side * glass_w, 0.50, -0.42), Vector3.ZERO, frame)
		# lower rail along the coaming
		_part(Vector3(0.055, 0.055, 1.05), Vector3(side * glass_w, -0.44, -0.52), Vector3.ZERO, trim)
	# stick, just in the bottom of the view
	_part(Vector3(0.055, 0.30, 0.055), Vector3(0, -0.82, -0.48), Vector3(-8, 0, 0), trim)
	_part(Vector3(0.16, 0.07, 0.11), Vector3(0, -0.66, -0.50), Vector3.ZERO, Color(0.25, 0.28, 0.33))

func _part(size: Vector3, pos: Vector3, rot: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.8
	mat.metallic = 0.1
	mi.material_override = mat
	mi.position = EYE + pos
	mi.rotation_degrees = rot
	add_child(mi)
