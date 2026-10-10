extends CharacterBody3D
## Clean Godot 4 player boat. Level 1-3 share ONE modular hull.
## The anchor rig is self-contained and remains connected by a world-space rope.

signal health_changed(current: float, maximum: float)
signal ship_destroyed
signal ship_level_upgraded(new_level: int, title: String)

@export_group("Navigation")
@export var max_speed: float = 10.0
@export var acceleration: float = 3.8
@export var deceleration: float = 1.4
@export var turn_speed: float = 1.5
@export var sail_response: float = 1.2
@export var rudder_response: float = 3.5
@export var travel_speed_multiplier: float = 1.5

@export_group("Ship")
@export var max_health: float = 90.0
@export var cannon_damage: float = 25.0
@export var reload_time: float = 2.5

var health: float = 90.0
var current_forward_speed: float = 0.0
var rudder_input: float = 0.0
var smoothed_rudder: float = 0.0
var sail_level: int = 0
var sail_power: float = 0.0
var current_level: int = 1
var travel_mode: bool = false
var travel_blend: float = 0.0
var combat_active: bool = false
var anchor_deployed: bool = false
var anchor_set: bool = false
var anchor_point: Vector3 = Vector3.ZERO
var storage: ShipStorage = ShipStorage.new()

var _travel_progress: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _wave_time: float = 0.0
var _anchor_yaw_velocity: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var modular_visuals: ModularShipVisuals = $Visuals/ModularShipVisuals
@onready var anchor_rig: AnchorRig = $AnchorRig

func _ready() -> void:
	add_to_group("player")
	GameManager.register_player(self)
	storage.storage_changed.connect(_on_storage_changed)
	apply_ship_level(GameManager.current_ship_level)
	health = max_health
	_last_position = global_position
	GameManager.update_player_health(health, max_health)

func _physics_process(delta: float) -> void:
	var target_power: float = 1.0 if sail_level > 0 else 0.0
	sail_power = move_toward(sail_power, target_power, sail_response * delta)
	smoothed_rudder = move_toward(smoothed_rudder, rudder_input, rudder_response * delta)

	anchor_deployed = anchor_rig.is_deployed()
	anchor_set = anchor_rig.is_set()
	if anchor_deployed:
		# Continue coasting during the anchor throw; this is a heavy ship,
		# not a motorboat with an instant stop button.
		var drag: float = 0.95 if not anchor_set else 1.65
		current_forward_speed = move_toward(current_forward_speed, 0.0, drag * delta)
		velocity = -global_transform.basis.z * current_forward_speed
		velocity.y = 0.0
		if current_forward_speed > 0.015:
			move_and_slide()
		if anchor_set:
			_apply_anchor_tension(delta)
	else:
		_anchor_yaw_velocity = 0.0
		var desired_speed: float = sail_power * max_speed * lerpf(1.0, travel_speed_multiplier, travel_blend)
		current_forward_speed = move_toward(
			current_forward_speed, desired_speed,
			(acceleration if desired_speed > current_forward_speed else deceleration) * delta
		)
		if current_forward_speed > 0.06:
			rotation.y -= smoothed_rudder * turn_speed * clampf(
				current_forward_speed / maxf(max_speed, 0.1), 0.12, 1.0) * delta
		velocity = -global_transform.basis.z * current_forward_speed
		velocity.y = 0.0
		move_and_slide()

	# Four separate wave samples apply buoyancy to the *boat*, not just to
	# the animated water texture. Rope holder follows these visual motions.
	_update_buoyancy(delta)
	anchor_rig.update_anchor(delta)
	anchor_deployed = anchor_rig.is_deployed()
	anchor_set = anchor_rig.is_set()
	if anchor_deployed:
		anchor_point = anchor_rig.get_pivot()
	_update_travel(delta)
	modular_visuals.animate_ship(delta, sail_level > 0, smoothed_rudder)

func _apply_anchor_tension(delta: float) -> void:
	var pivot: Vector3 = anchor_rig.get_pivot()
	anchor_point = pivot
	var attachment: Vector3 = anchor_rig.get_attachment_position()
	var direction: Vector3 = pivot - attachment
	direction.y = 0.0
	var separation: float = direction.length()
	if separation < 0.001:
		return
	var reach: float = anchor_rig.get_rope_reach()
	var tether_vector: Vector3 = direction / separation
	var overstretch: float = maxf(0.0, separation - reach)

	if overstretch > 0.0:
		# Pull the front-right ATTACHMENT point toward the dropped anchor.
		# Correction is rate-limited so the bow swings, not teleports.
		var correction: float = minf(overstretch, (0.85 + overstretch * 2.8) * delta)
		global_position += tether_vector * correction
		current_forward_speed = move_toward(current_forward_speed, 0.0, 1.9 * delta)
		var lever_arm: Vector3 = attachment - global_position
		lever_arm.y = 0.0
		# Torque around the vessel center depends on the side of the bow
		# that carries the rope. No fake "rotate in place" anchored mode.
		var y_torque: float = lever_arm.cross(tether_vector).y
		_anchor_yaw_velocity += clampf(y_torque * overstretch * 2.4, -3.1, 3.1) * delta
	elif sail_power > 0.1:
		# A little wind fills any spare rope; the vessel then naturally
		# pulls sideways at the bow as the tether becomes taut.
		global_position += -global_transform.basis.z * sail_power * 0.46 * delta

	# Helm input still influences the swing, without pulling the anchor
	# itself along with the hull.
	if sail_power > 0.05:
		_anchor_yaw_velocity -= smoothed_rudder * 0.44 * sail_power * delta
	_anchor_yaw_velocity = clampf(_anchor_yaw_velocity, -1.5, 1.5)
	rotation.y += _anchor_yaw_velocity * delta
	_anchor_yaw_velocity *= exp(-1.12 * delta)

func _wave_at(local_point: Vector3) -> float:
	var world: Node = get_parent()
	if world and world.has_method("get_wave_height"):
		return float(world.call("get_wave_height", to_global(local_point)))
	# Fallback for headless player-only tests (without a world node).
	return sin(_wave_time + local_point.x * 0.5 - local_point.z * 0.22) * 0.12

func _update_buoyancy(delta: float) -> void:
	_wave_time += delta * 0.55
	var bow: float = _wave_at(Vector3(0.0, 0.0, -2.95))
	var stern: float = _wave_at(Vector3(0.0, 0.0, 2.95))
	var starboard: float = _wave_at(Vector3(1.7, 0.0, -0.5))
	var port: float = _wave_at(Vector3(-1.7, 0.0, -0.5))
	var surface: float = (bow + stern + starboard + port) * 0.25
	var buoyancy_lerp: float = minf(1.0, delta * 4.0)
	visuals.position.y = lerpf(visuals.position.y, surface + 0.18, buoyancy_lerp)
	var pitch: float = clampf(atan2(bow - stern, 5.9) * 1.55, -0.18, 0.18)
	var roll: float = clampf(atan2(starboard - port, 3.4) * 1.9, -0.21, 0.21)
	visuals.rotation.x = lerp_angle(visuals.rotation.x, pitch, minf(1.0, delta * 3.0))
	visuals.rotation.z = lerp_angle(visuals.rotation.z, roll, minf(1.0, delta * 3.0))
	if not anchor_deployed and current_forward_speed < 0.8:
		var world: Node = get_parent()
		if world and world.has_method("get_wave_push"):
			var drift: Vector2 = world.call("get_wave_push", global_position)
			global_position += Vector3(drift.x, 0.0, drift.y) * delta

func set_rudder_input(value: float) -> void:
	rudder_input = clampf(value, -1.0, 1.0)

func get_rudder_input() -> float:
	return rudder_input

func set_sail_level(level: int) -> void:
	# Sailing is available at Level 1; Level 2 improves sail geometry.
	sail_level = 2 if level > 0 else 0
	if sail_level == 0:
		travel_mode = false

func toggle_sail() -> void:
	set_sail_level(0 if sail_level > 0 else 2)

func get_sail_level() -> int:
	return sail_level

func get_sail_power() -> float:
	return sail_power

func has_sail_upgrade() -> bool:
	return true

func has_travel_upgrade() -> bool:
	return current_level >= 3

func toggle_anchor() -> void:
	anchor_rig.toggle()
	anchor_deployed = anchor_rig.is_deployed()
	anchor_set = anchor_rig.is_set()
	travel_mode = false
	_travel_progress = 0.0

func is_anchor_deployed() -> bool:
	return anchor_rig.is_deployed()

func is_anchor_set() -> bool:
	return anchor_rig.is_set()

func set_joystick_input(vec: Vector2) -> void:
	set_rudder_input(vec.x)
	if vec.y < -0.35:
		set_sail_level(2)
	elif vec.y > 0.35:
		set_sail_level(0)

func _update_travel(delta: float) -> void:
	travel_blend = move_toward(travel_blend, 1.0 if travel_mode else 0.0, delta)
	var moved: float = global_position.distance_to(_last_position)
	_last_position = global_position
	if current_level < 3 or anchor_deployed or combat_active or sail_level == 0 or absf(smoothed_rudder) > 0.2:
		travel_mode = false
		_travel_progress = 0.0
		return
	if sail_power < 0.90:
		return
	_travel_progress += moved
	if _travel_progress > 24.0:
		travel_mode = true

func is_travel_mode() -> bool:
	return travel_mode

func get_travel_blend() -> float:
	return travel_blend

func get_travel_progress() -> float:
	return clampf(_travel_progress / 24.0, 0.0, 1.0)

func set_combat_active(active: bool) -> void:
	combat_active = active
	if combat_active:
		travel_mode = false
		_travel_progress = 0.0

func apply_ship_level(level: int) -> void:
	current_level = clampi(level, 1, 15)
	var info := ShipProgressionData.get_level_info(current_level)
	max_health = info.max_health
	max_speed = info.max_speed
	turn_speed = info.turn_speed
	acceleration = info.acceleration
	cannon_damage = info.cannon_damage
	reload_time = info.reload_time
	health = clampf(health + 15.0, 1.0, max_health)
	storage.configure_for_level(current_level, info.storage_capacity)
	GameManager.update_player_health(health, max_health)
	if is_instance_valid(modular_visuals):
		modular_visuals.configure_level(current_level)
	ship_level_upgraded.emit(current_level, info.title)

func get_cannons_per_side() -> int:
	return 1 # one below-deck cannon on each side in Level 1-3

func _on_storage_changed(used: int, capacity: int) -> void:
	GameManager.update_storage(used, capacity)

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	GameManager.update_player_health(health, max_health)
	if health <= 0.0:
		_respawn()

func _respawn() -> void:
	ship_destroyed.emit()
	set_physics_process(false)
	visible = false
	await get_tree().create_timer(2.0).timeout
	anchor_rig.reset_anchor()
	global_position = Vector3.ZERO
	rotation = Vector3.ZERO
	current_forward_speed = 0.0
	sail_power = 0.0
	sail_level = 0
	travel_mode = false
	travel_blend = 0.0
	health = max_health
	GameManager.update_player_health(health, max_health)
	visible = true
	set_physics_process(true)
