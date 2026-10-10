class_name AnchorRig
extends Node3D
## Starboard anchor attached beside the forward-right gunwale.
## The anchor is thrown outward (+X), never backward toward the stern.
## Its world-space pin and curved rope give the bow a real mooring point.

enum State { RAISED, LOWERING, SET, RAISING }

@export var anchor_model_path: String = "res://assets/models/Anchor_Mobile_2048.glb"
@export var holder_model_path: String = "res://assets/models/Anchor_Holder_Mobile_2048.glb"
@export var mount_offset: Vector3 = Vector3(2.06, 1.38, -1.47)
@export var sea_floor_y: float = -3.5
@export var lowering_speed: float = 5.8
@export var raising_speed: float = 4.2
@export var throw_side_distance: float = 2.15
@export var throw_forward_distance: float = 0.55
@export var initial_rope_slack: float = 0.55

var state: State = State.RAISED
var seabed_point: Vector3 = Vector3.ZERO
var rope_reach: float = 2.5
var _anchor_position: Vector3 = Vector3.ZERO
var _drop_progress: float = 0.0
var _throw_start: Vector3 = Vector3.ZERO
var _holder: Node3D
var _anchor: Node3D
var _rope: MeshInstance3D
var _ship: Node3D
var _rope_refresh: int = 0
var _splash_life: float = 0.0
var _splash: MeshInstance3D

func _ready() -> void:
	_ship = get_parent() as Node3D
	_holder = Node3D.new()
	_holder.name = "StarboardAnchorHolder"
	add_child(_holder)
	if not _try_load_asset(_holder, holder_model_path, 0.9):
		_fallback_holder(_holder)
	_holder.rotation.y = -0.18

	_anchor = Node3D.new()
	_anchor.name = "WorldAnchor"
	add_child(_anchor)
	_anchor.top_level = true
	if not _try_load_asset(_anchor, anchor_model_path, 1.22):
		_fallback_anchor(_anchor)
	else:
		# Place the topmost part of the imported mesh right at the rope
		# attachment pivot. The model stays alongside the hull when stowed.
		var model := _anchor.get_child(0) as Node3D
		var mesh: MeshInstance3D = _find_mesh(model)
		if mesh:
			var bounds: AABB = mesh.get_aabb()
			var factor: float = model.scale.y
			model.position = Vector3(
				-bounds.get_center().x * factor,
				-bounds.end.y * factor,
				-bounds.get_center().z * factor
			)

	_rope = MeshInstance3D.new()
	_rope.name = "CurvedAnchorRope"
	add_child(_rope)
	_rope.top_level = true
	var rope_material := _material(Color(0.36, 0.26, 0.16), false)
	rope_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rope.material_override = rope_material
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_splash = MeshInstance3D.new()
	_splash.name = "AnchorEntryRipple"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.19
	torus.outer_radius = 0.25
	torus.rings = 12
	torus.ring_segments = 16
	_splash.mesh = torus
	var splash_material := _material(Color(0.71, 0.91, 0.95, 0.7), false)
	splash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_splash.material_override = splash_material
	add_child(_splash)
	_splash.top_level = true
	_splash.visible = false
	call_deferred("_reset_visuals")

func get_attachment_position() -> Vector3:
	return _attachment_position() + _ship.global_basis * Vector3(0.16, -0.04, 0.0)

func _attachment_position() -> Vector3:
	if not is_instance_valid(_ship):
		return Vector3.ZERO
	var ship_visuals: Node3D = _ship.get_node_or_null("Visuals") as Node3D
	if ship_visuals:
		return ship_visuals.to_global(mount_offset)
	return _ship.to_global(mount_offset)

func _stowed_ring() -> Vector3:
	return _attachment_position() + _ship.global_basis * Vector3(0.18, -0.11, 0.0)

func _reset_visuals() -> void:
	if not is_instance_valid(_ship) or not is_instance_valid(_anchor):
		return
	_anchor_position = _stowed_ring()
	_anchor.global_position = _anchor_position
	_update_holder_position()
	_update_rope()

func toggle() -> void:
	if state == State.RAISED or state == State.RAISING:
		_throw_start = _stowed_ring()
		_anchor_position = _throw_start
		_drop_progress = 0.0
		# Starboard (right) and slightly toward the BOW (-Z), not behind.
		seabed_point = _throw_start + _ship.global_basis.x * throw_side_distance
		seabed_point -= _ship.global_basis.z * throw_forward_distance
		seabed_point.y = sea_floor_y
		state = State.LOWERING
	else:
		state = State.RAISING
	_splash.visible = false
	_splash_life = 0.0

func reset_anchor() -> void:
	state = State.RAISED
	call_deferred("_reset_visuals")

func is_deployed() -> bool:
	return state != State.RAISED

func is_set() -> bool:
	return state == State.SET

func get_pivot() -> Vector3:
	return seabed_point

func get_rope_reach() -> float:
	return rope_reach

func update_anchor(delta: float) -> void:
	if not is_instance_valid(_anchor):
		return
	_update_holder_position()
	var stowed: Vector3 = _stowed_ring()
	match state:
		State.RAISED:
			_anchor_position = stowed
		State.LOWERING:
			_drop_progress = minf(_drop_progress + delta * 2.5, 1.0)
			var throw_blend: float = smoothstep(0.0, 1.0, _drop_progress)
			_anchor_position.x = lerpf(_throw_start.x, seabed_point.x, throw_blend)
			_anchor_position.z = lerpf(_throw_start.z, seabed_point.z, throw_blend)
			var old_y: float = _anchor_position.y
			_anchor_position.y = move_toward(_anchor_position.y, sea_floor_y + 0.13, lowering_speed * delta)
			if old_y > -0.10 and _anchor_position.y <= -0.10:
				_splash_life = 0.58
				_splash.visible = true
				_splash.global_position = Vector3(_anchor_position.x, -0.10, _anchor_position.z)
			if _drop_progress >= 1.0 and _anchor_position.y <= sea_floor_y + 0.14:
				_anchor_position = seabed_point + Vector3(0.0, 0.13, 0.0)
				state = State.SET
				var ring_offset: Vector3 = get_attachment_position() - seabed_point
				rope_reach = Vector2(ring_offset.x, ring_offset.z).length() + initial_rope_slack
		State.SET:
			_anchor_position = seabed_point + Vector3(0.0, 0.13, 0.0)
		State.RAISING:
			_anchor_position = _anchor_position.move_toward(stowed, raising_speed * delta)
			if _anchor_position.distance_to(stowed) <= 0.045:
				_anchor_position = stowed
				state = State.RAISED
	_anchor.global_position = _anchor_position
	_rope_refresh += 1
	if (_rope_refresh % 2) == 0 or state == State.RAISED:
		_update_rope()
	if _splash_life > 0.0:
		_splash_life -= delta
		_splash.scale = Vector3.ONE * (1.0 + (0.58 - _splash_life) * 2.0)
		if _splash_life <= 0.0:
			_splash.visible = false

func _update_holder_position() -> void:
	if is_instance_valid(_holder):
		_holder.global_position = _attachment_position()

func _update_rope() -> void:
	if not is_instance_valid(_rope):
		return
	var start: Vector3 = get_attachment_position()
	var finish: Vector3 = _anchor_position
	var straight: float = start.distance_to(finish)
	var droop: float = clampf(straight * 0.14, 0.05, 0.9)
	if state == State.RAISED:
		droop = 0.035
	var sideways: Vector3 = _ship.global_basis.x * minf(straight * 0.14, 0.35)
	var middle: Vector3 = (start + finish) * 0.5 + sideways - Vector3.UP * droop
	# Curved rope generated in world coordinates; parent boat can rotate
	# without dragging the seabed anchor along with it.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 6
	var segments: int = 14
	var radius: float = 0.040
	for step in range(segments):
		var t0: float = float(step) / float(segments)
		var t1: float = float(step + 1) / float(segments)
		var a: Vector3 = _bezier(start, middle, finish, t0)
		var b: Vector3 = _bezier(start, middle, finish, t1)
		var tangent: Vector3 = (b - a).normalized()
		var across: Vector3 = tangent.cross(Vector3.UP)
		if across.length_squared() < 0.01:
			across = tangent.cross(Vector3.FORWARD)
		across = across.normalized()
		var second: Vector3 = tangent.cross(across).normalized()
		for side in range(sides):
			var a0: float = TAU * float(side) / float(sides)
			var a1: float = TAU * float(side + 1) / float(sides)
			var off0: Vector3 = (across * cos(a0) + second * sin(a0)) * radius
			var off1: Vector3 = (across * cos(a1) + second * sin(a1)) * radius
			surface.add_vertex(a + off0)
			surface.add_vertex(b + off0)
			surface.add_vertex(a + off1)
			surface.add_vertex(a + off1)
			surface.add_vertex(b + off0)
			surface.add_vertex(b + off1)
	surface.generate_normals()
	_rope.mesh = surface.commit()
	_rope.global_transform = Transform3D.IDENTITY

func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var one_minus: float = 1.0 - t
	return a * one_minus * one_minus + b * 2.0 * t * one_minus + c * t * t

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
