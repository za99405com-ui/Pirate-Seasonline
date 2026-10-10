class_name AnchorRig
extends Node3D
## Rigid anchor + fixed bracket + curved procedural rope. The anchor model lives
## in WORLD space, allowing the hull to drift and then swing around the seabed pin.
## Coordinates: +X starboard, -Z bow, Y=0 average waterline.

enum State { RAISED, LOWERING, SET, RAISING }

@export var anchor_model_path: String = "res://assets/models/Anchor_Mobile_2048.glb"
@export var holder_model_path: String = "res://assets/models/Anchor_Holder_Mobile_2048.glb"
@export var mount_offset: Vector3 = Vector3(2.12, 2.33, -1.38)
@export var sea_floor_y: float = -3.5
@export var lowering_speed: float = 2.6
@export var raising_speed: float = 3.2
@export var initial_rope_slack: float = 1.6

var state: State = State.RAISED
var seabed_point: Vector3 = Vector3.ZERO
var rope_reach: float = 5.0
var _anchor_position: Vector3 = Vector3.ZERO  # Anchor ring, NOT anchor center
var _holder: Node3D
var _anchor: Node3D
var _rope: MeshInstance3D
var _ship: Node3D
var _rope_material: StandardMaterial3D
var _rope_refresh: int = 0
var _splash_life: float = 0.0
var _splash: MeshInstance3D

func _ready() -> void:
	_ship = get_parent() as Node3D
	_holder = Node3D.new()
	_holder.name = "StarboardAnchorHolder"
	_holder.position = mount_offset
	add_child(_holder)
	if not _try_load_asset(_holder, holder_model_path, 1.0):
		_fallback_holder(_holder)
	# Orient holder's hook toward open water, not inside the hull.
	_holder.rotation.y = -0.18

	_anchor = Node3D.new()
	_anchor.name = "WorldAnchor"
	add_child(_anchor)
	_anchor.top_level = true
	if not _try_load_asset(_anchor, anchor_model_path, 1.18):
		_fallback_anchor(_anchor)
	else:
		# Imported anchor local origin is below its top ring. Put its ring at
		# WorldAnchor's pivot so the rope really attaches to the metal eye.
		var model: Node3D = _anchor.get_child(0) as Node3D
		model.position.y = -1.18

	_rope = MeshInstance3D.new()
	_rope.name = "CurvedAnchorRope"
	add_child(_rope)
	_rope.top_level = true
	_rope_material = _material(Color(0.38, 0.29, 0.17), false)
	_rope_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rope.material_override = _rope_material
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_splash = MeshInstance3D.new()
	_splash.name = "AnchorEntryRipple"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.24
	torus.rings = 12
	torus.ring_segments = 16
	_splash.mesh = torus
	var splash_material := _material(Color(0.68, 0.91, 0.95, 0.7), false)
	splash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_splash.material_override = splash_material
	add_child(_splash)
	_splash.top_level = true
	_splash.visible = false
	call_deferred("_reset_visuals")

func _stowed_ring() -> Vector3:
	# Ring is next to the side bracket, with anchor hanging DOWN, beside the hull.
	return _attachment_position() + _ship.global_basis * Vector3(0.28, -0.17, 0.0)

func _reset_visuals() -> void:
	if not is_instance_valid(_ship):
		return
	_anchor_position = _stowed_ring()
	_anchor.global_position = _anchor_position
	_rope_refresh = 0
	_update_rope()

func toggle() -> void:
	if state == State.RAISED or state == State.RAISING:
		var start: Vector3 = _stowed_ring()
		_anchor_position = _anchor.global_position
		# The anchor is cast a SHORT distance toward the ship's heading as it
		# drops; the seabed point stays in world space after the cast.
		var launch: float = 0.0
		if "current_forward_speed" in _ship:
			launch = clampf(float(_ship.current_forward_speed) * 0.26, 0.0, 2.5)
		seabed_point = start + (-_ship.global_basis.z * launch)
		seabed_point.y = sea_floor_y
		state = State.LOWERING
	else:
		state = State.RAISING
	_splash.visible = false

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
	var stowed: Vector3 = _stowed_ring()
	match state:
		State.RAISED:
			_anchor_position = stowed
		State.LOWERING:
			var previous_y: float = _anchor_position.y
			_anchor_position.y = move_toward(_anchor_position.y, sea_floor_y + 0.18, lowering_speed * delta)
			var horizontal_target := Vector3(seabed_point.x, _anchor_position.y, seabed_point.z)
			_anchor_position = _anchor_position.lerp(horizontal_target, minf(1.0, delta * 1.35))
			if previous_y > -0.05 and _anchor_position.y <= -0.05:
				_splash_life = 0.65
				_splash.visible = true
				_splash.global_position = Vector3(_anchor_position.x, -0.09, _anchor_position.z)
			if _anchor_position.y <= sea_floor_y + 0.19:
				_anchor_position = seabed_point + Vector3(0, 0.18, 0)
				state = State.SET
				# Extra payout allows the vessel to drift slightly before it
				# feels the line go taut and then settles.
				var offset: Vector3 = _ship.global_position - seabed_point
				rope_reach = Vector2(offset.x, offset.z).length() + initial_rope_slack
		State.SET:
			_anchor_position = seabed_point + Vector3(0, 0.18, 0)
		State.RAISING:
			_anchor_position = _anchor_position.move_toward(stowed, raising_speed * delta)
			if _anchor_position.distance_to(stowed) <= 0.035:
				_anchor_position = stowed
				state = State.RAISED
	_anchor.global_position = _anchor_position
	_rope_refresh += 1
	if _rope_refresh % 2 == 0 or state == State.RAISED:
		_update_rope()
	if _splash_life > 0.0:
		_splash_life -= delta
		_splash.scale = Vector3.ONE * lerpf(2.0, 0.8, clampf(_splash_life / 0.65, 0.0, 1.0))
		if _splash_life <= 0.0:
			_splash.visible = false

func _attachment_position() -> Vector3:
	return _ship.to_global(mount_offset) if is_instance_valid(_ship) else Vector3.ZERO

func _update_rope() -> void:
	if not is_instance_valid(_rope):
		return
	var start: Vector3 = _attachment_position() + _ship.global_basis * Vector3(0.26, 0.16, 0)
	var finish: Vector3 = _anchor_position
	var straight: float = start.distance_to(finish)
	# The rope pays out from the starboard hook; a gentle catenary-like sag
	# replaces the previous laser-straight, vertical cylinder.
	var droop: float = clampf(straight * 0.095, 0.08, 0.72)
	if state == State.RAISED:
		droop = 0.05
	var sideways := _ship.global_basis.x * minf(straight * 0.12, 0.35)
	var middle: Vector3 = (start + finish) * 0.5 + sideways - Vector3.UP * droop
	var result := SurfaceTool.new()
	result.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 6
	var segments: int = 12
	var radius: float = 0.035
	for step in range(segments):
		var t0: float = float(step) / float(segments)
		var t1: float = float(step + 1) / float(segments)
		var a: Vector3 = _bezier(start, middle, finish, t0)
		var b: Vector3 = _bezier(start, middle, finish, t1)
		var direction: Vector3 = (b - a).normalized()
		var across: Vector3 = direction.cross(Vector3.UP)
		if across.length_squared() < 0.01:
			across = direction.cross(Vector3.FORWARD)
		across = across.normalized()
		var second: Vector3 = direction.cross(across).normalized()
		for side in range(sides):
			var angle0: float = TAU * float(side) / float(sides)
			var angle1: float = TAU * float(side + 1) / float(sides)
			var off0: Vector3 = (across * cos(angle0) + second * sin(angle0)) * radius
			var off1: Vector3 = (across * cos(angle1) + second * sin(angle1)) * radius
			result.add_vertex(a + off0)
			result.add_vertex(b + off0)
			result.add_vertex(a + off1)
			result.add_vertex(a + off1)
			result.add_vertex(b + off0)
			result.add_vertex(b + off1)
	result.generate_normals()
	_rope.mesh = result.commit()
	_rope.global_transform = Transform3D.IDENTITY

func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	return a * u * u + b * 2.0 * t * u + c * t * t

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
