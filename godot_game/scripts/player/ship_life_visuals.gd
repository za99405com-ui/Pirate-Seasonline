class_name ShipLifeVisuals
extends Node3D

var player: Node3D = null
var crew_root: Node3D = null
var captain_root: Node3D = null
var captain_arms: Node3D = null
var sail_workers: Array[Node3D] = []
var sail_worker_arms: Array[Node3D] = []
var cannon_workers: Array[Node3D] = []
var anchor_worker: Node3D = null
var anchor_worker_arms: Node3D = null
var monkey_root: Node3D = null
var stowed_anchor: Node3D = null
var world_anchor_root: Node3D = null
var world_anchor_model: Node3D = null
var world_rope: MeshInstance3D = null
var world_rope_mesh: BoxMesh = null
var anchor_drop_progress: float = 0.0
var life_time: float = 0.0
var level: int = 1

var mat_skin: StandardMaterial3D
var mat_trouser: StandardMaterial3D
var mat_captain: StandardMaterial3D
var mat_cannon: StandardMaterial3D
var mat_sailor: StandardMaterial3D
var mat_anchor: StandardMaterial3D
var mat_rope: StandardMaterial3D
var mat_monkey: StandardMaterial3D

func setup(owner_ship: Node3D) -> void:
	player = owner_ship
	name = "ShipLifeVisuals"
	_build_materials()
	# Crew characters are intentionally disabled. Keep only ship/anchor visuals.
	_build_anchor_visuals()

func set_level(new_level: int) -> void:
	level = new_level
	# No visible crew on the player ship.
	if crew_root:
		crew_root.visible = false

func update_visuals(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	life_time += delta
	_update_captain(delta)
	_update_workers(delta)
	_update_anchor_visual(delta)

func _build_materials() -> void:
	mat_skin = _mat(Color(0.76, 0.52, 0.34, 1.0), 0.82)
	mat_trouser = _mat(Color(0.09, 0.12, 0.15, 1.0), 0.86)
	mat_captain = _mat(Color(0.36, 0.06, 0.045, 1.0), 0.78)
	mat_cannon = _mat(Color(0.20, 0.24, 0.30, 1.0), 0.85)
	mat_sailor = _mat(Color(0.72, 0.63, 0.39, 1.0), 0.84)
	mat_anchor = _mat(Color(0.10, 0.11, 0.13, 1.0), 0.45)
	mat_anchor.metallic = 0.72
	mat_rope = _mat(Color(0.52, 0.36, 0.20, 1.0), 0.95)
	mat_monkey = _mat(Color(0.30, 0.18, 0.10, 1.0), 0.92)

func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _build_crew() -> void:
	crew_root = Node3D.new()
	crew_root.name = "Level1Crew"
	add_child(crew_root)

	captain_root = _make_person("Captain", Vector3(0.0, 1.45, 2.55), mat_captain, true)
	captain_arms = captain_root.get_node_or_null("Arms") as Node3D

	# Four cannon crew: two hands for the port gun and two for starboard.
	for data in [
		[Vector3(-0.72, 1.16, -0.52), 0.12],
		[Vector3(-0.70, 1.16, -1.28), -0.08],
		[Vector3(0.72, 1.16, -0.52), -0.12],
		[Vector3(0.70, 1.16, -1.28), 0.08]
	]:
		var p := _make_person("CannonCrew", data[0], mat_cannon, false)
		p.rotation.y = float(data[1])
		cannon_workers.append(p)

	# Two riggers work the Level 1 sail.
	for pos in [Vector3(-0.52, 1.18, -0.18), Vector3(0.52, 1.18, -0.08)]:
		var sailor := _make_person("SailCrew", pos, mat_sailor, false)
		sail_workers.append(sailor)
		var arms := sailor.get_node_or_null("Arms") as Node3D
		if arms:
			sail_worker_arms.append(arms)

	anchor_worker = _make_person("AnchorCrew", Vector3(-0.62, 1.18, -2.45), mat_sailor, false)
	anchor_worker_arms = anchor_worker.get_node_or_null("Arms") as Node3D

	monkey_root = _make_monkey(Vector3(0.88, 1.28, -0.12))

func _make_person(person_name: String, base_position: Vector3, shirt_mat: StandardMaterial3D, captain: bool) -> Node3D:
	var root := Node3D.new()
	root.name = person_name
	root.position = base_position
	root.set_meta("base_y", base_position.y)
	crew_root.add_child(root)

	var legs := _box(Vector3(0.26, 0.42, 0.20), mat_trouser)
	legs.position.y = 0.22
	root.add_child(legs)

	var torso := _box(Vector3(0.38, 0.52, 0.24), shirt_mat)
	torso.position.y = 0.66
	root.add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	head.mesh = head_mesh
	head.material_override = mat_skin
	head.position.y = 1.08
	root.add_child(head)

	var arms := Node3D.new()
	arms.name = "Arms"
	arms.position.y = 0.72
	root.add_child(arms)
	for side in [-1.0, 1.0]:
		var arm := _box(Vector3(0.11, 0.42, 0.11), mat_skin)
		arm.position = Vector3(0.25 * side, -0.03, -0.02)
		arm.rotation.z = 0.18 * side
		arms.add_child(arm)

	if captain:
		var hat_brim := MeshInstance3D.new()
		var brim_mesh := CylinderMesh.new()
		brim_mesh.top_radius = 0.27
		brim_mesh.bottom_radius = 0.27
		brim_mesh.height = 0.05
		hat_brim.mesh = brim_mesh
		hat_brim.material_override = mat_trouser
		hat_brim.position.y = 1.27
		root.add_child(hat_brim)
		var hat_top := _box(Vector3(0.28, 0.12, 0.22), mat_trouser)
		hat_top.position.y = 1.34
		root.add_child(hat_top)

	return root

func _make_monkey(base_position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "RiggingMonkey"
	root.position = base_position
	root.set_meta("base_y", base_position.y)
	crew_root.add_child(root)

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.13
	body_mesh.height = 0.28
	body.mesh = body_mesh
	body.material_override = mat_monkey
	body.position.y = 0.18
	root.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.10
	head_mesh.height = 0.20
	head.mesh = head_mesh
	head.material_override = mat_monkey
	head.position = Vector3(0.0, 0.40, -0.02)
	root.add_child(head)

	var tail := _box(Vector3(0.055, 0.055, 0.46), mat_monkey)
	tail.position = Vector3(0.0, 0.20, 0.24)
	tail.rotation.x = 0.45
	root.add_child(tail)
	return root

func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	return mi

func _build_anchor_visuals() -> void:
	stowed_anchor = Node3D.new()
	stowed_anchor.name = "StowedAnchor"
	stowed_anchor.position = Vector3(-1.20, 1.18, -2.70)
	stowed_anchor.rotation = Vector3(0.0, 0.0, -0.22)
	add_child(stowed_anchor)
	_add_anchor_geometry(stowed_anchor, 0.52)

	if not player.get_parent():
		return

	world_anchor_root = Node3D.new()
	world_anchor_root.name = "PlayerAnchorWorldVisual"
	player.get_parent().add_child(world_anchor_root)

	world_anchor_model = Node3D.new()
	world_anchor_root.add_child(world_anchor_model)
	_add_anchor_geometry(world_anchor_model, 0.62)

	world_rope = MeshInstance3D.new()
	world_rope_mesh = BoxMesh.new()
	world_rope_mesh.size = Vector3(0.055, 0.055, 1.0)
	world_rope.mesh = world_rope_mesh
	world_rope.material_override = mat_rope
	world_anchor_root.add_child(world_rope)
	world_anchor_root.visible = false

func _add_anchor_geometry(root: Node3D, scale_factor: float) -> void:
	var shank := _box(Vector3(0.11, 0.95, 0.11) * scale_factor, mat_anchor)
	shank.position.y = -0.05
	root.add_child(shank)

	var stock := _box(Vector3(0.78, 0.10, 0.10) * scale_factor, mat_anchor)
	stock.position.y = 0.26 * scale_factor
	root.add_child(stock)

	var crown := _box(Vector3(0.58, 0.10, 0.10) * scale_factor, mat_anchor)
	crown.position.y = -0.50 * scale_factor
	root.add_child(crown)

	for side in [-1.0, 1.0]:
		var fluke := _box(Vector3(0.28, 0.10, 0.22) * scale_factor, mat_anchor)
		fluke.position = Vector3(0.30 * side * scale_factor, -0.54 * scale_factor, 0.0)
		fluke.rotation.z = -0.45 * side
		root.add_child(fluke)

func _update_captain(delta: float) -> void:
	if not captain_root:
		return
	var rudder: float = float(player.call("get_rudder_input")) if player.has_method("get_rudder_input") else 0.0
	captain_root.rotation.y = lerp_angle(captain_root.rotation.y, -rudder * 0.18, 1.0 - exp(-6.0 * delta))
	if captain_arms:
		captain_arms.rotation.z = lerpf(captain_arms.rotation.z, -rudder * 0.42, 1.0 - exp(-8.0 * delta))

	# Also turn the visible Level 1 deck wheel with the same rudder input.
	var deck_wheel := get_parent().get_node_or_null("BaseHull/ShipWheel") as Node3D
	if deck_wheel:
		deck_wheel.rotation.y = rudder * 1.10

func _update_workers(_delta: float) -> void:
	var sail_target: float = 0.0
	var sail_progress: float = 0.0
	if "sail_visual_progress" in player:
		sail_progress = float(player.sail_visual_progress)
	if player.has_method("get_sail_level"):
		match int(player.call("get_sail_level")):
			1:
				sail_target = 0.55
			2:
				sail_target = 1.0
	var sail_busy: bool = absf(sail_target - sail_progress) > 0.035

	for i in range(sail_workers.size()):
		var worker := sail_workers[i]
		var base_y: float = float(worker.get_meta("base_y"))
		worker.position.y = base_y + sin(life_time * 3.0 + float(i)) * 0.018
	for i in range(sail_worker_arms.size()):
		var arms := sail_worker_arms[i]
		arms.rotation.x = sin(life_time * 7.5 + float(i) * 1.4) * 0.52 if sail_busy else sin(life_time * 1.7 + float(i)) * 0.05

	for i in range(cannon_workers.size()):
		var crew := cannon_workers[i]
		var base_y: float = float(crew.get_meta("base_y"))
		crew.position.y = base_y + sin(life_time * 1.5 + float(i) * 0.9) * 0.012
		crew.rotation.z = sin(life_time * 1.2 + float(i)) * 0.018

	if anchor_worker and anchor_worker_arms:
		var working_anchor: bool = bool(player.anchor_deployed) and not bool(player.anchor_set)
		anchor_worker_arms.rotation.x = sin(life_time * 8.0) * 0.50 if working_anchor else 0.0

	if monkey_root:
		var monkey_base_y: float = float(monkey_root.get_meta("base_y"))
		monkey_root.position.y = monkey_base_y + sin(life_time * (5.0 if sail_busy else 2.0)) * (0.045 if sail_busy else 0.018)
		monkey_root.rotation.y = sin(life_time * 2.3) * 0.16

func _update_anchor_visual(delta: float) -> void:
	if not world_anchor_root or not stowed_anchor:
		return

	var deployed: bool = bool(player.anchor_deployed)
	var target: float = 1.0 if deployed else 0.0
	var rate: float = 0.78 if deployed else 1.15
	anchor_drop_progress = move_toward(anchor_drop_progress, target, rate * delta)

	var ship_attach: Vector3 = player.to_global(Vector3(-1.18, 1.34, -2.62))
	var sea_target: Vector3 = player.anchor_point
	sea_target.y = 0.03
	var anchor_position: Vector3 = ship_attach.lerp(sea_target, smoothstep(0.0, 1.0, anchor_drop_progress))

	if anchor_drop_progress <= 0.001 and not deployed:
		world_anchor_root.visible = false
		stowed_anchor.visible = true
		return

	stowed_anchor.visible = false
	world_anchor_root.visible = true
	world_anchor_model.global_position = anchor_position
	world_anchor_model.rotation.y = 0.18 * sin(life_time * 1.3) if not bool(player.anchor_set) else 0.0
	_update_rope(ship_attach, anchor_position)

func _update_rope(from_pos: Vector3, to_pos: Vector3) -> void:
	if not world_rope or not world_rope_mesh:
		return
	var length: float = from_pos.distance_to(to_pos)
	if length < 0.05:
		world_rope.visible = false
		return
	world_rope.visible = true
	world_rope_mesh.size = Vector3(0.055, 0.055, length)
	world_rope.global_position = (from_pos + to_pos) * 0.5
	world_rope.look_at(to_pos, Vector3.UP)
