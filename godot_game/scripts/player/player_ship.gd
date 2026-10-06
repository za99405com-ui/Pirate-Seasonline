extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal ship_destroyed
signal ship_level_upgraded(new_level: int, title: String)

@export_group("Ship Movement")
@export var max_speed: float = 14.5
@export var acceleration: float = 4.2
@export var deceleration: float = 1.35
@export var turn_speed: float = 1.45
@export var water_drag: float = 0.42
@export var rudder_response: float = 3.4
@export var steering_min_speed_ratio: float = 0.08
@export var steering_full_speed_ratio: float = 0.48

@export_group("Sailing Controls")
@export var half_sail_power: float = 0.52
@export var sail_response: float = 1.15
@export var full_sail_turn_factor: float = 0.66
@export var furled_turn_factor: float = 1.15
@export var anchor_rope_length: float = 9.0
@export var anchor_set_delay: float = 0.65
@export var anchor_drag: float = 4.8
@export var anchor_speed_limit_ratio: float = 0.42
@export var sail_visual_response: float = 0.58

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
var rudder_input: float = 0.0
var sail_level: int = 0
var sail_power: float = 0.0
var sail_visual_progress: float = 0.0
var smoothed_throttle: float = 0.0
var smoothed_rudder: float = 0.0
var anchor_deployed: bool = false
var anchor_set: bool = false
var anchor_point: Vector3 = Vector3.ZERO
var anchor_timer: float = 0.0
var active_anchor_rope_length: float = 9.0
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
var ship_life_visuals: ShipLifeVisuals = null

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
	ship_life_visuals = ShipLifeVisuals.new()
	visuals.add_child(ship_life_visuals)
	ship_life_visuals.setup(self)
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

func set_rudder_input(value: float) -> void:
	rudder_input = clampf(value, -1.0, 1.0)

func get_rudder_input() -> float:
	return rudder_input

func set_sail_level(level: int) -> void:
	# Two-state propulsion. Levels 1-2 use rowing (stop/go); Level 3+ uses the real sail.
	sail_level = 2 if level > 0 else 0
	if sail_level < 2 and travel_mode:
		_set_travel_mode(false)
		_reset_travel_progress()

func toggle_sail() -> void:
	set_sail_level(0 if sail_level > 0 else 2)

func get_sail_level() -> int:
	return sail_level

func get_sail_power() -> float:
	return sail_power

func has_sail_upgrade() -> bool:
	return current_level >= 3

func has_travel_upgrade() -> bool:
	return current_level >= 3

func toggle_anchor() -> void:
	if anchor_deployed:
		anchor_deployed = false
		anchor_set = false
		anchor_timer = 0.0
		return

	anchor_deployed = true
	anchor_set = false
	anchor_timer = 0.0
	var drop_offset: Vector3 = -global_transform.basis.z * 2.8 - global_transform.basis.x * 1.0
	anchor_point = global_position + drop_offset
	anchor_point.y = 0.0
	active_anchor_rope_length = anchor_rope_length + clampf(absf(current_forward_speed) * 0.18, 0.0, 3.0)
	if travel_mode:
		_set_travel_mode(false)
		_reset_travel_progress()

func is_anchor_deployed() -> bool:
	return anchor_deployed

func is_anchor_set() -> bool:
	return anchor_set

# Legacy bridge kept so old scenes/tests do not break while the D-pad is removed.
func set_joystick_input(vec: Vector2) -> void:
	set_rudder_input(vec.x)
	if vec.y < -0.35:
		set_sail_level(2)
	elif vec.y > 0.35:
		set_sail_level(0)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_update_travel_mode(delta)
	_update_travel_effects(delta)
	if ship_life_visuals:
		ship_life_visuals.update_visuals(delta)
	_handle_wave_bobbing(delta)
	_update_wake(delta)
	_keep_world_health_bar_readable()

func _handle_movement(delta: float) -> void:
	# L1-L2: rowing propulsion. L3+: the same input opens/closes the installed sail.
	var target_sail_power: float = 1.0 if sail_level > 0 else 0.0

	# Propulsion builds and drops progressively; closing the sail never teleports speed.
	sail_power = move_toward(sail_power, target_sail_power, sail_response * delta)
	smoothed_throttle = sail_power
	smoothed_rudder = move_toward(smoothed_rudder, rudder_input, rudder_response * delta)

	var active_max_speed: float = lerpf(max_speed, max_speed * travel_speed_multiplier, travel_blend)
	var target_speed: float = sail_power * active_max_speed

	# When the anchor bites, it resists the ship but does not stop it instantly.
	if anchor_deployed and anchor_set:
		target_speed = minf(target_speed, max_speed * anchor_speed_limit_ratio * maxf(sail_power, 0.35))

	var speed_rate: float = acceleration * lerpf(0.68, 1.0, sail_power) if target_speed > current_forward_speed else deceleration
	if anchor_deployed and anchor_set and target_speed < current_forward_speed:
		speed_rate = maxf(speed_rate, anchor_drag)
	current_forward_speed = move_toward(current_forward_speed, target_speed, speed_rate * delta)

	if sail_power < 0.03 and not anchor_deployed:
		current_forward_speed = move_toward(current_forward_speed, 0.0, water_drag * delta)

	var steering_speed_base: float = maxf(active_max_speed, 0.01)
	var speed_ratio: float = clampf(absf(current_forward_speed) / steering_speed_base, 0.0, 1.0)
	var steering_authority: float = smoothstep(steering_min_speed_ratio, steering_full_speed_ratio, speed_ratio)

	# More canvas = more momentum = wider turn. Furled sails make a tighter coasting arc.
	var turn_arc_factor: float = lerpf(furled_turn_factor, full_sail_turn_factor, sail_power)
	if absf(smoothed_rudder) > 0.01 and steering_authority > 0.001:
		rotation.y -= smoothed_rudder * turn_speed * steering_authority * turn_arc_factor * delta

	var desired_velocity: Vector3 = -transform.basis.z * current_forward_speed
	desired_velocity.y = 0.0

	if anchor_deployed:
		anchor_timer += delta
		if not anchor_set and anchor_timer >= anchor_set_delay:
			anchor_set = true

		if anchor_set:
			var to_ship: Vector3 = global_position - anchor_point
			to_ship.y = 0.0
			var distance_from_anchor: float = to_ship.length()
			if distance_from_anchor > 0.001:
				var radial: Vector3 = to_ship / distance_from_anchor
				# Once the rope is nearly taut, remove outward velocity but keep tangent velocity.
				# With sails still open this makes the ship orbit the anchor instead of freezing.
				if distance_from_anchor >= active_anchor_rope_length * 0.90:
					var outward_speed: float = desired_velocity.dot(radial)
					if outward_speed > 0.0:
						desired_velocity -= radial * outward_speed

	velocity = desired_velocity
	move_and_slide()

	if anchor_deployed and anchor_set:
		var after_offset: Vector3 = global_position - anchor_point
		after_offset.y = 0.0
		var after_distance: float = after_offset.length()
		if after_distance > active_anchor_rope_length and after_distance > 0.001:
			var corrected: Vector3 = anchor_point + after_offset.normalized() * active_anchor_rope_length
			global_position.x = corrected.x
			global_position.z = corrected.z

func _update_travel_mode(_delta: float) -> void:
	var current_position := global_position
	var moved: float = Vector2(
		current_position.x - travel_last_position.x,
		current_position.z - travel_last_position.z
	).length()
	travel_last_position = current_position

	var raw_rudder: float = rudder_input
	var forward: Vector3 = -transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()

	if current_level < 3 or combat_active or anchor_deployed or sail_level < 2:
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
	if sail_power < 0.86 or speed_ratio < travel_min_speed_ratio:
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
	if not visuals:
		return

	var roots: Array[Node] = []
	var ship_model: Node = visuals.get_node_or_null("ShipModel")
	var starter_mast: Node = visuals.get_node_or_null("MastMain")
	if ship_model:
		roots.append(ship_model)
	if starter_mast:
		roots.append(starter_mast)

	for root in roots:
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.append(child)
			if node is MeshInstance3D and "sail" in node.name.to_lower():
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

	# The real sail is unlocked at Level 3 and has a physical OPEN/CLOSED transition.
	var sail_visual_target: float = 1.0 if current_level >= 3 and sail_level > 0 else 0.0
	sail_visual_progress = move_toward(sail_visual_progress, sail_visual_target, sail_visual_response * delta)

	# Open/close sails one after another instead of every sheet popping at once.
	var sail_count: int = maxi(travel_sail_nodes.size(), 1)
	for i in range(travel_sail_nodes.size()):
		var sail := travel_sail_nodes[i]
		if not is_instance_valid(sail):
			continue
		var base_scale_value: Variant = travel_sail_scales.get(sail.get_instance_id(), sail.scale)
		var base_scale: Vector3 = base_scale_value if base_scale_value is Vector3 else sail.scale
		var order_offset: float = (float(i) / float(sail_count)) * 0.24
		var local_open: float = clampf((sail_visual_progress - order_offset) / 0.76, 0.0, 1.0)
		local_open = smoothstep(0.0, 1.0, local_open)
		var vertical_open: float = lerpf(0.10, 1.0, local_open)
		var width_open: float = lerpf(0.72, 1.0, local_open)
		var travel_billow: float = lerpf(1.0, 1.08, travel_blend)
		sail.scale = Vector3(
			base_scale.x * width_open * travel_billow,
			base_scale.y * vertical_open * travel_billow,
			base_scale.z * travel_billow
		)

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
	sail_level = 0
	sail_power = 0.0
	sail_visual_progress = 0.0
	rudder_input = 0.0
	smoothed_rudder = 0.0
	anchor_deployed = false
	anchor_set = false
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

	if current_level < 3 and travel_mode:
		_set_travel_mode(false)
		_reset_travel_progress()

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

	_apply_level_visual_stage()
	if ship_life_visuals:
		ship_life_visuals.set_level(current_level)

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

func _apply_level_visual_stage() -> void:
	if not visuals:
		return

	# The old handmade ship is permanently removed.
	# Every level uses the same imported Ragged Drifter hull.
	var ship_model := visuals.get_node_or_null("ShipModel") as Node3D
	var base_hull := visuals.get_node_or_null("BaseHull") as Node3D
	var mast_main := visuals.get_node_or_null("MastMain") as Node3D

	if ship_model:
		ship_model.visible = true
	if base_hull:
		base_hull.visible = false
	if mast_main:
		mast_main.visible = false

	# Keep only upgrade add-ons that belong to the new progression.
	if progressive_parts:
		progressive_parts.visible = true
		for child in progressive_parts.get_children():
			child.visible = false
		var first_cannons := progressive_parts.get_node_or_null("cannons_pair_1") as Node3D
		if first_cannons:
			first_cannons.visible = current_level >= 2

	_apply_imported_level_look()

func _apply_imported_level_look() -> void:
	# Same mesh at every level; only its condition changes.
	# L1 is dark, rough and neglected. L2 is partly repaired. L3 restores the authored texture.
	var ship_model_node: Node = visuals.get_node_or_null("ShipModel") if visuals else null
	if not ship_model_node:
		return

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

		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			# Level 3+ goes back to the GLB's original baked material.
			if current_level >= 3:
				mesh_instance.set_surface_override_material(surface_index, null)
				continue

			var source := mesh_instance.mesh.surface_get_material(surface_index)
			if not source is StandardMaterial3D:
				continue

			var worn := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			if current_level == 1:
				worn.albedo_color *= Color(0.58, 0.54, 0.48, 1.0)
				worn.roughness = maxf(worn.roughness, 0.94)
			else:
				worn.albedo_color *= Color(0.80, 0.77, 0.70, 1.0)
				worn.roughness = maxf(worn.roughness, 0.82)
			mesh_instance.set_surface_override_material(surface_index, worn)

func _play_upgrade_celebration() -> void:
	if not visuals:
		return
	var tw := visuals.create_tween()
	tw.tween_property(visuals, "scale", Vector3(1.15, 1.15, 1.15), 0.18)
	tw.tween_property(visuals, "scale", Vector3.ONE, 0.22)

func _on_storage_changed(used: int, capacity: int) -> void:
	GameManager.update_storage(used, capacity)

func get_cannons_per_side() -> int:
	if current_level < 2:
		return 0
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
	# The imported Level 3 GLB already has its own baked PBR texture.
	# Keep that original material so the wood, sails, metal and lantern colours
	# render as authored instead of being flattened into one dark hull material.
	return
