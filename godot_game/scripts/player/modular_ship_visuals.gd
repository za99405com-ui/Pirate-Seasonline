class_name ModularShipVisuals
extends Node3D
## Purely visual modular ship: a single static hull, moving sail/helm,
## two low broadside cannons, and Level 2/3 cosmetic upgrades.
## Put generated GLBs in assets/models/. Procedural placeholders remain
## visible until the actual modular assets are committed.

@export var base_hull_path: String = "res://assets/models/Pirate_Boat_A_Level1_Mobile_2048.glb"
@export var level2_sail_path: String = "res://assets/models/Level2_Sail.glb"
@export var level3_hull_path: String = "res://assets/models/Level3_Hull.glb"

var _base_hull: Node3D
var _sail: Node3D
var _sail_fabric: MeshInstance3D
var _level2_marks: Node3D
var _repair_details: Node3D
var _helm: Node3D
var _level: int = 1
var _sail_open: float = 0.0

func _ready() -> void:
	_build_hull()
	_build_sail()
	_build_helm()
	_build_cannons()

func configure_level(level: int) -> void:
	_level = clampi(level, 1, 15)
	_level2_marks.visible = _level >= 2
	_repair_details.visible = _level >= 3

func animate_ship(delta: float, sail_engaged: bool, rudder: float) -> void:
	_sail_open = move_toward(_sail_open, 1.0 if sail_engaged else 0.0, delta * 0.75)
	if _sail_fabric:
		_sail_fabric.scale.y = lerpf(0.08, 1.0, smoothstep(0.0, 1.0, _sail_open))
		_sail_fabric.position.y = lerpf(3.95, 2.62, smoothstep(0.0, 1.0, _sail_open))
	if _level2_marks:
		_level2_marks.scale.y = lerpf(0.1, 1.0, _sail_open)
	if _helm:
		_helm.rotation.z = rudder * 0.9

func _build_hull() -> void:
	_base_hull = Node3D.new()
	_base_hull.name = "BaseHull"
	add_child(_base_hull)
	if not _import_hull(_base_hull, base_hull_path):
		_make_fallback_hull(_base_hull)

	_repair_details = Node3D.new()
	_repair_details.name = "Level3RepairDetails"
	add_child(_repair_details)
	var iron := _mat(Color(0.23, 0.23, 0.24), true)
	for side in [-1.0, 1.0]:
		for z in [-2.8, -0.5, 1.9]:
			_box(_repair_details, Vector3(0.10, 0.70, 0.28),
				Vector3(side * 2.08, 1.10, z), iron)
	_repair_details.visible = false

func _import_hull(parent: Node3D, path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var res: Resource = load(path)
	if not res is PackedScene:
		return false
	var asset := (res as PackedScene).instantiate() as Node3D
	if not asset:
		return false
	parent.add_child(asset)
	var first_mesh := _first_mesh(asset)
	if first_mesh:
		var extents: Vector3 = first_mesh.get_aabb().size
		if extents.x > extents.z:
			asset.rotation.y = -PI * 0.5
		asset.scale = Vector3.ONE * (8.6 / maxf(maxf(extents.x, extents.z), 0.01))
		asset.position.y = -0.65
		# Set the editable pivot once, then keep it fixed across levels.
	return true

func _make_fallback_hull(parent: Node3D) -> void:
	var wood := _mat(Color(0.35, 0.21, 0.12), false)
	var deck := _mat(Color(0.48, 0.31, 0.17), false)
	var metal := _mat(Color(0.18, 0.19, 0.20), true)
	_box(parent, Vector3(3.75, 1.40, 7.80), Vector3(0.0, -0.13, 0.10), wood)
	_box(parent, Vector3(3.8, 0.18, 7.65), Vector3(0.0, 0.64, 0.10), deck)
	_box(parent, Vector3(3.4, 0.86, 1.75), Vector3(0.0, 1.03, 3.00), wood)
	_box(parent, Vector3(3.4, 0.15, 1.75), Vector3(0.0, 1.54, 3.00), deck)
	_box(parent, Vector3(2.7, 0.12, 0.45), Vector3(0.0, 0.84, -3.8), metal)
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(0.19, 0.62, 7.85),
			Vector3(side * 1.90, 0.89, 0.12), wood)
		_box(parent, Vector3(0.18, 0.18, 7.80),
			Vector3(side * 1.90, 1.23, 0.12), metal)
		for z in [-3.0, -1.7, 0.0, 1.6, 3.2]:
			_box(parent, Vector3(0.10, 0.24, 0.13), Vector3(side * 2.0, 0.15, z), metal)

func _build_sail() -> void:
	_sail = Node3D.new()
	_sail.name = "SailRig"
	_sail.position.y = 0.75
	add_child(_sail)
	var mast_mat := _mat(Color(0.37, 0.23, 0.12), false)
	var fabric_mat := _mat(Color(0.83, 0.79, 0.67), false)
	_cylinder(_sail, 0.15, 5.6, Vector3(0, 2.1, 0), mast_mat)
	_box(_sail, Vector3(3.1, 0.16, 0.15), Vector3(0, 4.30, 0), mast_mat)
	_sail_fabric = _box(_sail, Vector3(2.90, 2.70, 0.07), Vector3(0, 3.0, 0), fabric_mat)
	_sail_fabric.name = "AnimatedSail"
	_sail_fabric.scale.y = 0.08
	_level2_marks = Node3D.new()
	_level2_marks.name = "Level2SailCutDetails"
	_sail.add_child(_level2_marks)
	var detail_mat := _mat(Color(0.30, 0.23, 0.14), false)
	# Subtle reinforced slits / seams visually identify Level 2.
	for x in [-1.0, 0.0, 1.0]:
		_box(_level2_marks, Vector3(0.075, 0.95, 0.09),
			Vector3(x, 3.18, -0.08), detail_mat)
	_level2_marks.visible = false

func _build_helm() -> void:
	_helm = Node3D.new()
	_helm.name = "SteeringWheel"
	_helm.position = Vector3(0.0, 2.89, 3.05)
	add_child(_helm)
	var wood := _mat(Color(0.40, 0.24, 0.12), false)
	_cylinder(_helm, 0.10, 0.52, Vector3(0, -0.22, 0), wood)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.49
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = wood
	ring.rotation.x = PI * 0.5
	_helm.add_child(ring)
	for i in range(8):
		var spoke := _box(_helm, Vector3(0.065, 0.92, 0.075), Vector3.ZERO, wood)
		spoke.rotation.z = float(i) * PI / 8.0

func _build_cannons() -> void:
	var iron := _mat(Color(0.17, 0.18, 0.20), true)
	var wood := _mat(Color(0.29, 0.18, 0.10), false)
	for side in [-1.0, 1.0]:
		var cannon := Node3D.new()
		cannon.name = "StarboardCannon" if side > 0.0 else "PortCannon"
		cannon.position = Vector3(side * 1.80, 0.97, 0.35)
		add_child(cannon)
		_box(cannon, Vector3(0.64, 0.35, 0.72), Vector3(-side * 0.05, -0.19, 0), wood)
		var barrel := _cylinder(cannon, 0.18, 0.94,
			Vector3(side * 0.22, 0.09, 0.0), iron)
		barrel.rotation.z = PI * 0.5

func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var candidate := _first_mesh(child)
		if candidate:
			return candidate
	return null

func _box(parent: Node3D, dims: Vector3, where: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dims
	instance.mesh = box
	instance.material_override = mat
	instance.position = where
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, radius: float, height: float, where: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	instance.mesh = shape
	instance.material_override = mat
	instance.position = where
	parent.add_child(instance)
	return instance

func _mat(color: Color, metallic: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	material.metallic = 0.55 if metallic else 0.0
	return material
