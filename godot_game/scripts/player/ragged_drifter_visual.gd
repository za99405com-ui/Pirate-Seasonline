class_name RaggedDrifterVisual
extends Node3D

var player: Node3D = null
var sail_root: Node3D = null
var sail_panels: Array[Node3D] = []
var sail_panel_heights: Array[float] = []
var sail_panel_top_y: Array[float] = []
var cannon_root: Node3D = null
var cannon_barrel: Node3D = null
var tiller: Node3D = null
var flag: Node3D = null
var visual_time: float = 0.0
var external_cannon_yaw: float = 999.0

var wood_dark: StandardMaterial3D
var wood_light: StandardMaterial3D
var sail_cloth: StandardMaterial3D
var patch_cloth: StandardMaterial3D
var iron_mat: StandardMaterial3D
var rope_mat: StandardMaterial3D
var flag_mat: StandardMaterial3D

func setup(owner_ship: Node3D) -> void:
	player = owner_ship
	name = "RaggedDrifter"
	_build_materials()
	_build_hull()
	_build_rig()
	_build_cannon()
	_build_stern_details()
	_build_cargo()
	visible = false

func set_cannon_yaw(value: float) -> void:
	external_cannon_yaw = clampf(value, -0.72, 0.72)

func clear_cannon_yaw() -> void:
	external_cannon_yaw = 999.0

func update_visuals(delta: float, sail_progress: float, combat_active: bool, rudder_value: float) -> void:
	if not visible:
		return
	visual_time += delta
	_update_sail(sail_progress)
	_update_cannon(delta, combat_active)
	_update_tiller(delta, rudder_value)
	if flag:
		flag.rotation.y = sin(visual_time * 3.2) * 0.08
		flag.rotation.z = sin(visual_time * 4.1) * 0.05

func _build_materials() -> void:
	wood_dark = _mat(Color(0.30, 0.17, 0.10, 1.0), 0.88)
	wood_light = _mat(Color(0.49, 0.31, 0.18, 1.0), 0.82)
	sail_cloth = _mat(Color(0.84, 0.78, 0.67, 1.0), 0.94)
	sail_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	patch_cloth = _mat(Color(0.49, 0.39, 0.31, 1.0), 0.95)
	patch_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	iron_mat = _mat(Color(0.10, 0.105, 0.12, 1.0), 0.30)
	iron_mat.metallic = 0.82
	rope_mat = _mat(Color(0.55, 0.45, 0.31, 1.0), 0.96)
	flag_mat = _mat(Color(0.055, 0.055, 0.065, 1.0), 0.92)
	flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _build_hull() -> void:
	var hull := Node3D.new()
	hull.name = "Hull"
	add_child(hull)

	# Low-cost layered timber hull: narrow keel, broad deck and angled bow cheeks.
	_add_box(hull, Vector3(1.55, 0.62, 5.45), Vector3(0.0, 0.54, 0.18), Vector3.ZERO, wood_dark)
	_add_box(hull, Vector3(2.05, 0.18, 5.15), Vector3(0.0, 1.00, 0.22), Vector3.ZERO, wood_light)
	_add_box(hull, Vector3(0.26, 0.78, 4.65), Vector3(-1.00, 1.15, 0.25), Vector3(0.0, 0.0, 0.02), wood_dark)
	_add_box(hull, Vector3(0.26, 0.78, 4.65), Vector3(1.00, 1.15, 0.25), Vector3(0.0, 0.0, -0.02), wood_dark)

	_add_box(hull, Vector3(0.28, 0.76, 2.05), Vector3(-0.69, 1.05, -2.72), Vector3(0.0, 0.48, 0.0), wood_dark)
	_add_box(hull, Vector3(0.28, 0.76, 2.05), Vector3(0.69, 1.05, -2.72), Vector3(0.0, -0.48, 0.0), wood_dark)
	_add_box(hull, Vector3(1.92, 0.82, 0.25), Vector3(0.0, 1.22, 2.72), Vector3.ZERO, wood_dark)

	# Raised bow and stern lips add silhouette without heavy geometry.
	_add_box(hull, Vector3(1.55, 0.16, 0.42), Vector3(0.0, 1.44, -2.58), Vector3.ZERO, wood_light)
	_add_box(hull, Vector3(1.70, 0.16, 0.42), Vector3(0.0, 1.48, 2.52), Vector3.ZERO, wood_light)

	# Inner floor planks.
	for z in [-1.7, -0.9, -0.1, 0.7, 1.5]:
		_add_box(hull, Vector3(1.72, 0.055, 0.62), Vector3(0.0, 1.12, float(z)), Vector3.ZERO, wood_light)

func _build_rig() -> void:
	var rig := Node3D.new()
	rig.name = "SingleMastRig"
	add_child(rig)

	_add_cylinder(rig, 0.115, 0.15, 7.15, Vector3(0.0, 4.35, 0.28), Vector3.ZERO, wood_light, 8)
	_add_cylinder(rig, 0.075, 0.075, 3.65, Vector3(0.0, 5.72, 0.28), Vector3(0.0, 0.0, PI * 0.5), wood_light, 8)
	_add_cylinder(rig, 0.060, 0.060, 3.35, Vector3(0.0, 2.55, 0.28), Vector3(0.0, 0.0, PI * 0.5), wood_light, 8)

	# Crow's nest.
	var nest := MeshInstance3D.new()
	var nest_mesh := CylinderMesh.new()
	nest_mesh.top_radius = 0.48
	nest_mesh.bottom_radius = 0.40
	nest_mesh.height = 0.55
	nest_mesh.radial_segments = 8
	nest.mesh = nest_mesh
	nest.material_override = wood_dark
	nest.position = Vector3(0.0, 6.86, 0.28)
	rig.add_child(nest)

	# One patched ragged sail, split only for cheap furling animation.
	sail_root = Node3D.new()
	sail_root.name = "MainPatchedSail"
	rig.add_child(sail_root)
	_make_sail_panel(-1.12, 1.03, 3.00, 5.52)
	_make_sail_panel(0.00, 1.18, 3.25, 5.52)
	_make_sail_panel(1.10, 0.96, 2.82, 5.52)

	# Patch sits on the center cloth and follows furling.
	var patch := MeshInstance3D.new()
	var patch_mesh := QuadMesh.new()
	patch_mesh.size = Vector2(0.72, 0.82)
	patch.mesh = patch_mesh
	patch.material_override = patch_cloth
	patch.position = Vector3(0.42, -0.15, 0.035)
	patch.rotation.z = 0.12
	sail_panels[1].add_child(patch)

	# Simple shrouds on each side of the mast.
	_add_shroud(rig, Vector3(-0.93, 1.34, 0.28), Vector3(0.0, 5.78, 0.28))
	_add_shroud(rig, Vector3(0.93, 1.34, 0.28), Vector3(0.0, 5.78, 0.28))

	flag = Node3D.new()
	flag.name = "BlackFlag"
	flag.position = Vector3(0.50, 7.55, 0.28)
	rig.add_child(flag)
	var flag_mesh_instance := MeshInstance3D.new()
	var flag_mesh := QuadMesh.new()
	flag_mesh.size = Vector2(0.95, 0.58)
	flag_mesh_instance.mesh = flag_mesh
	flag_mesh_instance.material_override = flag_mat
	flag_mesh_instance.position.x = 0.44
	flag.add_child(flag_mesh_instance)

func _make_sail_panel(x: float, width: float, height: float, top_y: float) -> void:
	var panel_root := Node3D.new()
	panel_root.position = Vector3(x, top_y - height * 0.5, 0.31)
	sail_root.add_child(panel_root)

	var panel := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	panel.mesh = mesh
	panel.material_override = sail_cloth
	panel_root.add_child(panel)

	sail_panels.append(panel_root)
	sail_panel_heights.append(height)
	sail_panel_top_y.append(top_y)

func _build_cannon() -> void:
	cannon_root = Node3D.new()
	cannon_root.name = "SingleBowCannon"
	cannon_root.position = Vector3(0.0, 1.25, -2.05)
	add_child(cannon_root)

	_add_box(cannon_root, Vector3(0.72, 0.26, 0.85), Vector3(0.0, 0.02, 0.10), Vector3.ZERO, wood_dark)
	for x in [-0.31, 0.31]:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.16
		wheel_mesh.bottom_radius = 0.16
		wheel_mesh.height = 0.10
		wheel_mesh.radial_segments = 8
		wheel.mesh = wheel_mesh
		wheel.material_override = wood_light
		wheel.position = Vector3(float(x), -0.10, 0.16)
		wheel.rotation.z = PI * 0.5
		cannon_root.add_child(wheel)

	cannon_barrel = Node3D.new()
	cannon_barrel.name = "MovingBarrel"
	cannon_barrel.position = Vector3(0.0, 0.23, -0.30)
	cannon_root.add_child(cannon_barrel)
	_add_cylinder(cannon_barrel, 0.12, 0.20, 1.45, Vector3(0.0, 0.0, -0.46), Vector3(PI * 0.5 + 0.08, 0.0, 0.0), iron_mat, 12)

func _build_stern_details() -> void:
	tiller = Node3D.new()
	tiller.name = "RearTiller"
	tiller.position = Vector3(0.0, 1.42, 2.25)
	add_child(tiller)
	_add_box(tiller, Vector3(0.12, 0.14, 1.20), Vector3(0.0, 0.0, 0.0), Vector3(-0.28, 0.0, 0.0), wood_light)

func _build_cargo() -> void:
	for pos in [Vector3(0.60, 1.45, 1.38), Vector3(-0.58, 1.45, 1.12)]:
		var barrel := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.28
		mesh.bottom_radius = 0.30
		mesh.height = 0.66
		mesh.radial_segments = 8
		barrel.mesh = mesh
		barrel.material_override = wood_dark
		barrel.position = pos
		add_child(barrel)
		var hoop_top := _ring_barrel(pos + Vector3(0.0, 0.20, 0.0))
		var hoop_bottom := _ring_barrel(pos + Vector3(0.0, -0.20, 0.0))
		add_child(hoop_top)
		add_child(hoop_bottom)

func _ring_barrel(pos: Vector3) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.305
	mesh.bottom_radius = 0.305
	mesh.height = 0.045
	mesh.radial_segments = 8
	ring.mesh = mesh
	ring.material_override = iron_mat
	ring.position = pos
	return ring

func _update_sail(progress: float) -> void:
	var p: float = clampf(progress, 0.0, 1.0)
	for i in range(sail_panels.size()):
		var stagger: float = float(i) * 0.045
		var local: float = clampf((p - stagger) / maxf(0.01, 1.0 - stagger), 0.0, 1.0)
		local = smoothstep(0.0, 1.0, local)
		var panel := sail_panels[i]
		var open_y: float = lerpf(0.07, 1.0, local)
		panel.scale = Vector3(lerpf(0.78, 1.0, local), open_y, 1.0)
		panel.position.y = sail_panel_top_y[i] - (sail_panel_heights[i] * open_y) * 0.5
		panel.position.z = 0.31 + sin(visual_time * 2.0 + float(i)) * 0.035 * local

func _update_cannon(delta: float, combat_active: bool) -> void:
	if not cannon_root:
		return
	var target_yaw: float = 0.0
	if external_cannon_yaw < 900.0:
		target_yaw = external_cannon_yaw
	elif combat_active:
		target_yaw = sin(visual_time * 0.65) * 0.44
	cannon_root.rotation.y = lerp_angle(cannon_root.rotation.y, target_yaw, 1.0 - exp(-3.8 * delta))
	if cannon_barrel:
		var target_pitch: float = -0.04 + (0.035 * sin(visual_time * 0.8) if combat_active else 0.0)
		cannon_barrel.rotation.x = lerpf(cannon_barrel.rotation.x, target_pitch, 1.0 - exp(-4.0 * delta))

func _update_tiller(delta: float, rudder_value: float) -> void:
	if not tiller:
		return
	tiller.rotation.y = lerpf(tiller.rotation.y, -rudder_value * 0.62, 1.0 - exp(-7.0 * delta))

func _add_shroud(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var dx := b.x - a.x
	var dy := b.y - a.y
	var rope := _add_box(parent, Vector3(0.032, length, 0.032), mid, Vector3(0.0, 0.0, -atan2(dx, dy)), rope_mat)
	rope.position.z = a.z

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node

func _add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3, rot: Vector3, mat: Material, segments: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node
