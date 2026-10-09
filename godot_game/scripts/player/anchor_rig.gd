extends Node3D
## Modular starboard anchor. The world anchor and rope are NOT children of the
## ship's moving transform: top_level nodes preserve the seabed pivot.
## Coordinate convention: ship bow = -Z, starboard = +X, water = Y 0.

enum State { RAISED, LOWERING, SET, RAISING }

@export var anchor_model_path: String = "res://assets/models/Anchor.glb"
@export var holder_model_path: String = "res://assets/models/Anchor_Holder.glb"
@export var mount_offset: Vector3 = Vector3(2.35, 1.08, -1.45)
@export var sea_floor_y: float = -3.5
@export var lowering_speed: float = 2.3
@export var raising_speed: float = 2.6

var state: State = State.RAISED
var seabed_point: Vector3 = Vector3.ZERO
var _anchor_position: Vector3 = Vector3.ZERO
var _holder: Node3D
var _anchor: Node3D
var _rope: MeshInstance3D
var _ship: Node3D

func _ready() -> void:
	_ship = get_parent() as Node3D
	_holder = Node3D.new()
	_holder.name = "StarboardAnchorHolder"
	_holder.position = mount_offset
	add_child(_holder)
	if not _try_load_asset(_holder, holder_model_path, 0.95):
		_fallback_holder(_holder)

	_anchor = Node3D.new()
	_anchor.name = "WorldAnchor"
	add_child(_anchor)
	_anchor.top_level = true
	if not _try_load_asset(_anchor, anchor_model_path, 1.12):
		_fallback_anchor(_anchor)

	_rope = MeshInstance3D.new()
	_rope.name = "DynamicRope"
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.042
	rope_mesh.bottom_radius = 0.042
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 8
	_rope.mesh = rope_mesh
	_rope.material_override = _material(Color(0.52, 0.38, 0.22), false)
	add_child(_rope)
	_rope.top_level = true
	call_deferred("_reset_visuals")

func _reset_visuals() -> void:
	if not is_instance_valid(_ship):
		return
	_anchor_position = _attachment_position() - Vector3(0.0, 0.55, 0.0)
	_anchor.global_position = _anchor_position
	_update_rope()

func toggle() -> void:
	if state == State.RAISED or state == State.RAISING:
		seabed_point = _attachment_position()
		seabed_point.y = sea_floor_y
		_anchor_position = _anchor.global_position
		state = State.LOWERING
	else:
		state = State.RAISING

func reset_anchor() -> void:
	state = State.RAISED
	call_deferred("_reset_visuals")

func is_deployed() -> bool:
	return state != State.RAISED

func is_set() -> bool:
	return state == State.SET

func get_pivot() -> Vector3:
	return seabed_point

func update_anchor(delta: float) -> void:
	if not is_instance_valid(_anchor):
		return
	var stowed: Vector3 = _attachment_position() - Vector3(0.0, 0.55, 0.0)
	match state:
		State.RAISED:
			_anchor_position = stowed
		State.LOWERING:
			_anchor_position = _anchor_position.move_toward(seabed_point, lowering_speed * delta)
			if _anchor_position.distance_to(seabed_point) < 0.025:
				_anchor_position = seabed_point
				state = State.SET
		State.SET:
			_anchor_position = seabed_point
		State.RAISING:
			_anchor_position = _anchor_position.move_toward(stowed, raising_speed * delta)
			if _anchor_position.distance_to(stowed) < 0.03:
				_anchor_position = stowed
				state = State.RAISED
	_anchor.global_position = _anchor_position
	_update_rope()

func _attachment_position() -> Vector3:
	return _ship.to_global(mount_offset) if is_instance_valid(_ship) else Vector3.ZERO

func _update_rope() -> void:
	var from_point: Vector3 = _attachment_position()
	var to_point: Vector3 = _anchor_position + Vector3(0.0, 0.44, 0.0)
	var offset: Vector3 = to_point - from_point
	var length: float = maxf(offset.length(), 0.01)
	_rope.global_position = (from_point + to_point) * 0.5
	_rope.global_basis = Basis(Quaternion(Vector3.UP, offset.normalized()))
	_rope.scale = Vector3(1.0, length, 1.0)

func _try_load_asset(parent: Node3D, path: String, target_span: float) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var resource: Resource = load(path)
	if not resource is PackedScene:
		return false
	var instance := (resource as PackedScene).instantiate() as Node3D
	if not instance:
		return false
	parent.add_child(instance)
	var mesh := _find_mesh(instance)
	if mesh:
		var sizes: Vector3 = mesh.get_aabb().size
		instance.scale = Vector3.ONE * (target_span / maxf(maxf(sizes.x, sizes.y), maxf(sizes.z, 0.0001)))
	return true

func _find_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var mesh := _find_mesh(child)
		if mesh:
			return mesh
	return null

func _fallback_anchor(root: Node3D) -> void:
	var iron := _material(Color(0.13, 0.14, 0.16), true)
	_box(root, Vector3(0.13, 0.86, 0.13), Vector3.ZERO, iron)
	_box(root, Vector3(0.72, 0.10, 0.12), Vector3(0.0, 0.27, 0.0), iron)
	_box(root, Vector3(0.65, 0.12, 0.12), Vector3(0.0, -0.38, 0.0), iron)
	for side in [-1.0, 1.0]:
		var tip := _box(root, Vector3(0.12, 0.28, 0.19), Vector3(side * 0.34, -0.30, 0.0), iron)
		tip.rotation.z = -side * 0.48
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12
	torus.outer_radius = 0.17
	ring.mesh = torus
	ring.material_override = iron
	ring.position.y = 0.50
	root.add_child(ring)

func _fallback_holder(root: Node3D) -> void:
	var wood := _material(Color(0.29, 0.18, 0.095), false)
	var iron := _material(Color(0.12, 0.13, 0.14), true)
	_box(root, Vector3(0.30, 0.90, 0.50), Vector3(-0.10, 0.0, 0.0), wood)
	_box(root, Vector3(0.95, 0.18, 0.20), Vector3(0.35, 0.36, 0.0), wood)
	_box(root, Vector3(0.18, 0.42, 0.18), Vector3(0.80, 0.12, 0.0), iron)

func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var child := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	child.mesh = mesh
	child.material_override = mat
	child.position = pos
	root.add_child(child)
	return child

func _material(color: Color, metal: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	material.metallic = 0.72 if metal else 0.0
	return material
