extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal ship_destroyed
signal ship_level_upgraded(new_level: int, title: String)

@export_group("Ship Movement")
@export var max_speed: float = 14.5
@export var reverse_speed_ratio: float = 0.28
@export var acceleration: float = 4.2
@export var deceleration: float = 2.6
@export var turn_speed: float = 1.45
@export var water_drag: float = 0.35
@export var throttle_response: float = 2.6
@export var rudder_response: float = 3.8

@export_group("Travel Mode")
@export var travel_entry_distance: float = 22.0
@export var travel_speed_multiplier: float = 1.5
@export var travel_heading_tolerance_degrees: float = 30.0
@export var travel_min_speed_ratio: float = 0.55
@export var travel_turn_limit: float = 0.72
@export var travel_transition_time: float = 1.35

@export_group("Wave Simulation")
@export var bobbing_speed: float = 1.7
@export var bobbing_amount: float = 0.10
@export var pitch_amount: float = 0.028
@export var roll_amount: float = 0.045
@export var turn_bank_amount: float = 0.085

@export_group("Ship Durability")
@export var max_health: float = 100.0
@export var reload_time: float = 2.0
@export var cannon_damage: float = 34.0

var health: float = 100.0
var current_forward_speed: float = 0.0
var joystick_input: Vector2 = Vector2.ZERO
var smoothed_throttle: float = 0.0
var smoothed_rudder: float = 0.0
var wave_time: float = 0.0
var current_level: int = 1
var travel_mode: bool = false
var travel_blend: float = 0.0
var travel_progress_distance: float = 0.0
var travel_reference_heading: Vector3 = Vector3.ZERO
var travel_last_position: Vector3 = Vector3.ZERO
var combat_active: bool = false
var travel_sail_nodes: Array[Node3D] = []
var travel_sail_scales: Dictionary = {}
var travel_wind_root: Node3D = null
var travel_wind_strips: Array[MeshInstance3D] = []
var travel_wind_material: StandardMaterial3D = null
var travel_wind_time: float = 0.0
var world_health_anchor: Node3D = null
var world_health_fill: MeshInstance3D = null

var storage: ShipStorage = ShipStorage.new()

@onready var visuals: Node3D = $Visuals
@onready var progressive_parts: Node3D = $Visuals/ProgressiveParts
@onready var mount_slots: Node3D = $Visuals/MountSlots
@onready var port_cannons: Node3D = $Visuals/PortCannons
@onready var starboard_cannons: Node3D = $Visuals/StarboardCannons
@onready var wake_left: MeshInstance3D = $Visuals/WakeLeft
@onready var wake_right: MeshInstance3D = $Visuals/WakeRight

func _ready() -> void:
	add_to_group("player")
	GameManager.register_player(self)
	
	_apply_ship_materials()
	_collect_travel_sails()
	_setup_travel_wind()
	travel_last_position = global_position
	_setup_world_health_bar()
	_ensure_cannon_markers()
	storage.storage_changed.connect(_on_storage_changed)
	apply_ship_level(GameManager.current_ship_level)
	
	health = max_health
	GameManager.update_player_health(health, max_health)
	_update_world_health_bar()

func set_joystick_input(vec: Vector2) -> void:
	joystick_input = vec.limit_length(1.0)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_update_travel_mode(delta)
	_update_travel_effects(delta)
	_handle_wave_bobbing(delta)
	_update_wake(delta)
	_keep_world_health_bar_readable()

func _handle_movement(delta: float) -> void:
	var raw_rudder: float = joystick_input.x
	var raw_throttle: float = -joystick_input.y

	if absf(raw_throttle) < 0.12:
		raw_throttle = 0.0
	if absf(raw_rudder) < 0.10:
		raw_rudder = 0.0

	# Smooth the controls so the ship has weight instead of reacting like a car.
	smoothed_throttle = move_toward(smoothed_throttle, raw_throttle, throttle_response * delta)
	smoothed_rudder = move_toward(smoothed_rudder, raw_rudder, rudder_response * delta)

	var active_max_speed: float = lerpf(max_speed, max_speed * travel_speed_multiplier, travel_blend)
	var target_speed: float = 0.0
	if smoothed_throttle >= 0.0:
		target_speed = smoothed_throttle * active_max_speed
	else:
		target_speed = smoothed_throttle * max_speed * reverse_speed_ratio

	var rate: float = acceleration if absf(target_speed) > absf(current_forward_speed) else deceleration
	current_forward_speed = move_toward(current_forward_speed, target_speed, rate * delta)

	# Releasing the stick does not stop the ship instantly; water drag bleeds speed slowly.
	if absf(raw_throttle) < 0.01 and absf(smoothed_throttle) < 0.04:
		current_forward_speed = move_toward(current_forward_speed, 0.0, water_drag * delta)

	var steering_speed_base: float = lerpf(max_speed, max_speed * travel_speed_multiplier, travel_blend)
	var speed_ratio: float = clampf(absf(current_forward_speed) / maxf(steering_speed_base, 0.01), 0.0, 1.0)
	var steering_authority: float = lerpf(0.18, 1.0, speed_ratio)

	# Side-only steering makes a tighter circle.
	# Forward/back + side makes a wider sailing arc, like a ship carrying momentum.
	var throttle_load: float = clampf(absf(smoothed_throttle), 0.0, 1.0)
	var turn_arc_factor: float = lerpf(1.28, 0.68, throttle_load)
	if absf(smoothed_rudder) > 0.01:
		rotation.y -= smoothed_rudder * turn_speed * steering_authority * turn_arc_factor * delta

	velocity = -transform.basis.z * current_forward_speed
	velocity.y = 0.0
	move_and_slide()

func _update_travel_mode(_delta: float) -> void:
	var current_position := global_position
	var moved: float = Vector2(
		current_position.x - travel_last_position.x,
		current_position.z - travel_last_position.z
	).length()
	travel_last_position = current_position

	var raw_throttle: float = -joystick_input.y
	var raw_rudder: float = joystick_input.x
	var forward: Vector3 = -transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()

	if combat_active or raw_throttle < 0.45:
		_reset_travel_progress()
		if travel_mode:
			_set_travel_mode(false)
		return

	if travel_mode:
		# Gentle course corrections are allowed. A hard turn cancels travel.
		if absf(raw_rudder) > travel_turn_limit:
			_set_travel_mode(false)
			_reset_travel_progress()
		return

	var speed_ratio: float = absf(current_forward_speed) / maxf(max_speed, 0.01)
	if raw_throttle < 0.78 or speed_ratio < travel_min_speed_ratio:
		return

	if travel_reference_heading.length_squared() < 0.0001:
		travel_reference_heading = forward

	var heading_angle: float = rad_to_deg(travel_reference_heading.angle_to(forward))
	if heading_angle > travel_heading_tolerance_degrees:
		travel_progress_distance = 0.0
		travel_reference_heading = forward
		return

	travel_progress_distance += moved
	# Let the reference heading drift slowly, so small left/right corrections still count as travel.
	travel_reference_heading = travel_reference_heading.lerp(forward, 0.04).normalized()

	if travel_progress_distance >= travel_entry_distance:
		_set_travel_mode(true)

func _reset_travel_progress() -> void:
	travel_progress_distance = 0.0
	travel_reference_heading = Vector3.ZERO

func _set_travel_mode(active: bool) -> void:
	travel_mode = active

func is_travel_mode() -> bool:
	return travel_mode

func get_travel_blend() -> float:
	return travel_blend

func get_travel_progress() -> float:
	return clampf(travel_progress_distance / maxf(travel_entry_distance, 0.01), 0.0, 1.0)

func set_combat_active(active: bool) -> void:
	combat_active = active
	if active and travel_mode:
		_set_travel_mode(false)
		_reset_travel_progress()

func _collect_travel_sails() -> void:
	travel_sail_nodes.clear()
	travel_sail_scales.clear()
	var ship_model: Node = visuals.get_node_or_null("ShipModel") if visuals else null
	if not ship_model:
		return

	var stack: Array[Node] = [ship_model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is Node3D and "sail" in node.name.to_lower():
			var sail := node as Node3D
			travel_sail_nodes.append(sail)
			travel_sail_scales[sail.get_instance_id()] = sail.scale

func _setup_travel_wind() -> void:
	if travel_wind_root or not visuals:
		return

	travel_wind_root = Node3D.new()
	travel_wind_root.name = "TravelWind"
	visuals.add_child(travel_wind_root)
	travel_wind_root.visible = false

	travel_wind_material = StandardMaterial3D.new()
	travel_wind_material.albedo_color = Color(0.78, 0.94, 1.0, 0.0)
	travel_wind_material.emission_enabled = true
	travel_wind_material.emission = Color(0.45, 0.78, 1.0, 1.0)
	travel_wind_material.emission_energy_multiplier = 0.85
	travel_wind_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	travel_wind_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	travel_wind_material.no_depth_test = true

	for i in range(8):
		var strip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.055, 0.045, 3.8 + float(i % 3) * 0.9)
		strip.mesh = mesh
		strip.material_override = travel_wind_material
		strip.position = Vector3(
			-4.6 + float(i % 4) * 3.0,
			2.2 + float(i % 3) * 1.4,
			-8.0 + float(i / 4) * 5.0
		)
		travel_wind_root.add_child(strip)
		travel_wind_strips.append(strip)

func _update_travel_effects(delta: float) -> void:
	var target_blend: float = 1.0 if travel_mode else 0.0
	var blend_rate: float = 1.0 / maxf(travel_transition_time, 0.05)
	travel_blend = move_toward(travel_blend, target_blend, blend_rate * delta)

	# Open the sails progressively instead of popping instantly.
	for sail in travel_sail_nodes:
		if not is_instance_valid(sail):
			continue
		var base_scale_value: Variant = travel_sail_scales.get(sail.get_instance_id(), sail.scale)
		var base_scale: Vector3 = base_scale_value if base_scale_value is Vector3 else sail.scale
		sail.scale = base_scale * lerpf(1.0, 1.13, travel_blend)

	if not travel_wind_root:
		return

	travel_wind_root.visible = travel_blend > 0.02
	if travel_wind_material:
		var c: Color = travel_wind_material.albedo_color
		c.a = 0.42 * travel_blend
		travel_wind_material.albedo_color = c

	if travel_blend <= 0.02:
		return

	travel_wind_time += delta
	for i in range(travel_wind_strips.size()):
		var strip := travel_wind_strips[i]
		if not is_instance_valid(strip):
			continue
		strip.position.z += delta * (7.0 + 6.0 * travel_blend + float(i % 3) * 1.4)
		if strip.position.z > 7.0:
			strip.position.z = -10.0 - float(i % 4)
		strip.position.x += sin(travel_wind_time * 1.6 + float(i)) * delta * 0.05 * travel_blend

func _handle_wave_bobbing(delta: float) -> void:
	if not visuals:
		return
	wave_time += delta * bobbing_speed

	var speed_ratio: float = clampf(absf(current_forward_speed) / max_speed, 0.0, 1.0)
	var y_offset: float = sin(wave_time) * bobbing_amount + sin(wave_time * 1.73) * bobbing_amount * 0.35
	visuals.position.y = y_offset

	var pitch: float = cos(wave_time * 0.82) * pitch_amount
	var roll: float = sin(wave_time * 1.07) * roll_amount
	roll += -smoothed_rudder * turn_bank_amount * speed_ratio
	visuals.rotation = Vector3(pitch, 0.0, roll)

func _update_wake(_delta: float) -> void:
	var active_max_speed: float = lerpf(max_speed, max_speed * travel_speed_multiplier, travel_blend)
	var speed_ratio: float = clampf(absf(current_forward_speed) / maxf(active_max_speed, 0.01), 0.0, 1.0)
	var max_wake_scale: float = lerpf(1.35, 1.65, travel_blend)
	var wake_scale: float = lerpf(0.35, max_wake_scale, speed_ratio)
	for wake in [wake_left, wake_right]:
		if wake:
			wake.visible = speed_ratio > 0.08
			wake.scale.z = wake_scale
			var mat := wake.material_override as StandardMaterial3D
			if mat:
				var c := mat.albedo_color
				c.a = lerp(0.15, 0.65, speed_ratio)
				mat.albedo_color = c

func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	GameManager.update_player_health(health, max_health)
	_update_world_health_bar()
	_flash_hit()
	if health <= 0.0:
		_destroy_ship()

func _flash_hit() -> void:
	if not visuals:
		return
	var original_scale := visuals.scale
	var tw := visuals.create_tween()
	tw.tween_property(visuals, "scale", original_scale * 1.06, 0.07)
	tw.tween_property(visuals, "scale", original_scale, 0.10)

func _destroy_ship() -> void:
	ship_destroyed.emit()
	current_forward_speed = 0.0
	visible = false
	set_physics_process(false)

	await get_tree().create_timer(2.0).timeout
	global_position = Vector3.ZERO
	rotation = Vector3.ZERO
	health = max_health
	GameManager.update_player_health(health, max_health)
	_update_world_health_bar()
	visible = true
	set_physics_process(true)

# ==========================================
# LEVEL PROGRESSION & VISUAL CUSTOMIZATION
# ==========================================

func apply_ship_level(lvl: int) -> void:
	current_level = clamp(lvl, 1, 15)
	var info := ShipProgressionData.get_level_info(current_level)

	# 1. Update functional stats
	var prev_max_hp := max_health
	max_health = info.max_health
	if prev_max_hp > 0.0:
		health = clamp(health + (max_health - prev_max_hp), 1.0, max_health)
	else:
		health = max_health

	max_speed = info.max_speed
	turn_speed = info.turn_speed
	acceleration = info.acceleration
	cannon_damage = info.cannon_damage
	reload_time = info.reload_time

	# 2. Configure storage capacity
	storage.configure_for_level(current_level, info.storage_capacity)
	GameManager.update_storage(storage.used_storage, storage.storage_capacity)
	GameManager.update_player_health(health, max_health)
	_update_world_health_bar()

	# 3. Update progressive visual parts
	if progressive_parts:
		for child in progressive_parts.get_children():
			var feature_id := child.name.to_snake_case()
			child.visible = info.visible_parts.has(feature_id) or info.visible_parts.has(child.name)

	# 4. Update mount slots
	if mount_slots:
		for slot in mount_slots.get_children():
			if slot is ShipMountSlot:
				var is_slot_open := info.unlocked_slots.has(slot.slot_id) or info.unlocked_slots.has(slot.name.to_snake_case())
				slot.set_unlocked(is_slot_open)

	# 5. Cannon count is a real functional upgrade: 1 / 2 / 3 / 4 guns per side.
	_update_cannon_marker_visibility()

	ship_level_upgraded.emit(current_level, info.title)
	_play_upgrade_celebration()

func _play_upgrade_celebration() -> void:
	if not visuals:
		return
	var tw := visuals.create_tween()
	tw.tween_property(visuals, "scale", Vector3(1.15, 1.15, 1.15), 0.18)
	tw.tween_property(visuals, "scale", Vector3.ONE, 0.22)

func _on_storage_changed(used: int, capacity: int) -> void:
	GameManager.update_storage(used, capacity)

func get_cannons_per_side() -> int:
	if current_level >= 15:
		return 4
	if current_level >= 12:
		return 3
	if current_level >= 8:
		return 2
	return 1

func _ensure_cannon_markers() -> void:
	var z_positions: Array[float] = [-1.8, -0.6, 0.6, 1.8]
	for i in range(4):
		var marker_index: int = i + 1
		var port_name := "PortMarker%d" % marker_index
		var starboard_name := "StarboardMarker%d" % marker_index
		var port_marker := port_cannons.get_node_or_null(port_name) as Marker3D
		var starboard_marker := starboard_cannons.get_node_or_null(starboard_name) as Marker3D

		if not port_marker:
			port_marker = Marker3D.new()
			port_marker.name = port_name
			port_cannons.add_child(port_marker)

		if not starboard_marker:
			starboard_marker = Marker3D.new()
			starboard_marker.name = starboard_name
			starboard_cannons.add_child(starboard_marker)

		port_marker.position = Vector3(-1.55, 0.90, z_positions[i])
		starboard_marker.position = Vector3(1.55, 0.90, z_positions[i])

	_update_cannon_marker_visibility()

func _update_cannon_marker_visibility() -> void:
	var active_count: int = get_cannons_per_side()
	for i in range(4):
		var marker_index: int = i + 1
		var visible_now: bool = marker_index <= active_count
		var port_marker := port_cannons.get_node_or_null("PortMarker%d" % marker_index) as Node3D
		var starboard_marker := starboard_cannons.get_node_or_null("StarboardMarker%d" % marker_index) as Node3D
		if port_marker:
			port_marker.visible = visible_now
		if starboard_marker:
			starboard_marker.visible = visible_now

func _setup_world_health_bar() -> void:
	if world_health_anchor:
		return

	world_health_anchor = Node3D.new()
	world_health_anchor.name = "WorldHealthBar"
	world_health_anchor.position = Vector3(0.0, 6.8, 0.0)
	add_child(world_health_anchor)

	var background := MeshInstance3D.new()
	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(3.2, 0.28, 0.08)
	var background_mat := StandardMaterial3D.new()
	background_mat.albedo_color = Color(0.03, 0.04, 0.05, 0.88)
	background_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	background_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background.mesh = background_mesh
	background.material_override = background_mat
	world_health_anchor.add_child(background)

	world_health_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(3.0, 0.20, 0.10)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.18, 0.88, 0.33, 1.0)
	fill_mat.emission_enabled = true
	fill_mat.emission = Color(0.05, 0.28, 0.08, 1.0)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	world_health_fill.mesh = fill_mesh
	world_health_fill.material_override = fill_mat
	world_health_fill.position.z = -0.05
	world_health_anchor.add_child(world_health_fill)

	_update_world_health_bar()

func _keep_world_health_bar_readable() -> void:
	if not world_health_anchor:
		return
	var active_camera: Camera3D = get_viewport().get_camera_3d()
	if active_camera:
		world_health_anchor.look_at(active_camera.global_position, Vector3.UP)

func _update_world_health_bar() -> void:
	if not world_health_fill or max_health <= 0.0:
		return
	var frac: float = clampf(health / max_health, 0.0, 1.0)
	world_health_fill.scale.x = maxf(0.02, frac)
	world_health_fill.position.x = -(1.0 - frac) * 1.5
	var mat := world_health_fill.material_override as StandardMaterial3D
	if mat:
		if frac > 0.5:
			mat.albedo_color = Color(0.18, 0.88, 0.33, 1.0)
		elif frac > 0.25:
			mat.albedo_color = Color(1.0, 0.72, 0.12, 1.0)
		else:
			mat.albedo_color = Color(0.95, 0.16, 0.12, 1.0)

func _apply_ship_materials() -> void:
	var ship_model_node: Node = visuals.get_node_or_null("ShipModel") if visuals else null
	if not ship_model_node:
		return

	# 1. Create high-quality stylized pirate ship materials
	var mat_hull := StandardMaterial3D.new()
	mat_hull.resource_name = "StylizedHull"
	mat_hull.albedo_color = Color(0.28, 0.16, 0.09, 1.0) # Deep rich pirate dark timber
	mat_hull.roughness = 0.72

	var mat_deck := StandardMaterial3D.new()
	mat_deck.resource_name = "StylizedDeck"
	mat_deck.albedo_color = Color(0.48, 0.32, 0.18, 1.0) # Aged wooden deck planks & stairs
	mat_deck.roughness = 0.68

	var mat_masts := StandardMaterial3D.new()
	mat_masts.resource_name = "StylizedMasts"
	mat_masts.albedo_color = Color(0.38, 0.24, 0.13, 1.0) # Sturdy wooden masts
	mat_masts.roughness = 0.70

	var mat_crows := StandardMaterial3D.new()
	mat_crows.resource_name = "StylizedCrowsNest"
	mat_crows.albedo_color = Color(0.24, 0.14, 0.08, 1.0) # Dark timber crow's nest
	mat_crows.roughness = 0.75

	var mat_sails := StandardMaterial3D.new()
	mat_sails.resource_name = "StylizedSails"
	mat_sails.albedo_color = Color(0.93, 0.90, 0.82, 1.0) # Warm canvas linen off-white/cream
	mat_sails.roughness = 0.85
	mat_sails.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mat_cannons := StandardMaterial3D.new()
	mat_cannons.resource_name = "StylizedCannons"
	mat_cannons.albedo_color = Color(0.12, 0.13, 0.15, 1.0) # Forged dark iron
	mat_cannons.metallic = 0.88
	mat_cannons.roughness = 0.28

	var mat_metal := StandardMaterial3D.new()
	mat_metal.resource_name = "StylizedMetal"
	mat_metal.albedo_color = Color(0.16, 0.17, 0.19, 1.0) # Dark iron fixtures and hull bands
	mat_metal.metallic = 0.80
	mat_metal.roughness = 0.35

	var mat_railings := StandardMaterial3D.new()
	mat_railings.resource_name = "StylizedRailings"
	mat_railings.albedo_color = Color(0.46, 0.30, 0.17, 1.0) # Carved wood railings & helm wheel
	mat_railings.roughness = 0.68

	var mat_trim := StandardMaterial3D.new()
	mat_trim.resource_name = "StylizedTrim"
	mat_trim.albedo_color = Color(0.86, 0.70, 0.24, 1.0) # Burnished gold/brass trim molding
	mat_trim.metallic = 0.75
	mat_trim.roughness = 0.35

	var mat_rope := StandardMaterial3D.new()
	mat_rope.resource_name = "StylizedRope"
	mat_rope.albedo_color = Color(0.72, 0.62, 0.44, 1.0) # Natural tan hemp rigging
	mat_rope.roughness = 0.90

	var mat_flags := StandardMaterial3D.new()
	mat_flags.resource_name = "StylizedFlags"
	mat_flags.albedo_color = Color(0.12, 0.12, 0.14, 1.0) # Jolly Roger dark flag cloth
	mat_flags.roughness = 0.85
	mat_flags.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mat_windows := StandardMaterial3D.new()
	mat_windows.resource_name = "StylizedWindows"
	mat_windows.albedo_color = Color(1.0, 0.84, 0.45, 1.0) # Captain's cabin warm lantern glow
	mat_windows.emission_enabled = true
	mat_windows.emission = Color(0.95, 0.65, 0.18, 1.0)
	mat_windows.emission_energy_multiplier = 1.8
	mat_windows.roughness = 0.20

	var material_name_map := {
		"cannons": mat_cannons,
		"boat planks": mat_hull,
		"sails": mat_sails,
		"rope": mat_rope,
		"masts": mat_masts,
		"metal": mat_metal,
		"railings": mat_railings,
		"railings.001": mat_railings,
		"stairs": mat_deck,
		"trim": mat_trim,
		"crows nest": mat_crows,
		"windows": mat_windows,
		"material": mat_flags
	}

	# 2. Traverse all child nodes in the imported GLB model and apply styling
	var stack: Array[Node] = [ship_model_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)

		if not node is MeshInstance3D:
			continue

		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.mesh:
			continue

		var node_name_lower := node.name.to_lower()
		var surface_count := mesh_instance.mesh.get_surface_count()

		for s in range(surface_count):
			var assigned_material: StandardMaterial3D = null

			# Try matching surface material name first
			var existing_mat := mesh_instance.mesh.surface_get_material(s)
			if existing_mat:
				var mat_name_lower := existing_mat.resource_name.to_lower()
				for key in material_name_map:
					if key in mat_name_lower:
						assigned_material = material_name_map[key]
						break

			# If not resolved by material name, resolve by node name semantics
			if not assigned_material:
				if "cannon" in node_name_lower:
					assigned_material = mat_cannons
				elif "sail" in node_name_lower:
					assigned_material = mat_sails
				elif "crows" in node_name_lower:
					assigned_material = mat_crows
				elif "flag" in node_name_lower:
					assigned_material = mat_flags
				elif "stair" in node_name_lower:
					assigned_material = mat_deck
				elif "trim" in node_name_lower:
					assigned_material = mat_trim
				elif "railing" in node_name_lower or "wheel" in node_name_lower:
					assigned_material = mat_railings
				elif "rope" in node_name_lower or "tie" in node_name_lower:
					assigned_material = mat_rope
				elif "mast" in node_name_lower:
					assigned_material = mat_metal if s == 1 else mat_masts
				elif "ship body" in node_name_lower or "body" in node_name_lower or "hull" in node_name_lower:
					assigned_material = mat_windows if s == 1 else mat_hull
				elif "plane" in node_name_lower:
					assigned_material = mat_rope
				else:
					assigned_material = mat_hull

			# Apply surface override to eliminate flat white model appearance
			mesh_instance.set_surface_override_material(s, assigned_material)

		# For single-surface meshes, also set material_override for robust rendering
		if surface_count == 1:
			var single_mat := mesh_instance.get_surface_override_material(0)
			if single_mat:
				mesh_instance.material_override = single_mat
