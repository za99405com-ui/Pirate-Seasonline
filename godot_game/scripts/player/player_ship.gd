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

@export_group("Wave Simulation")
@export var bobbing_speed: float = 1.7
@export var bobbing_amount: float = 0.10
@export var pitch_amount: float = 0.028
@export var roll_amount: float = 0.045
@export var turn_bank_amount: float = 0.085

@export_group("Combat Attributes")
@export var max_health: float = 100.0
@export var reload_time: float = 2.0
@export var cannon_damage: float = 34.0
@export var aim_assist_range: float = 42.0
@export var aim_assist_degrees: float = 24.0
@export var cannonball_scene: PackedScene = preload("res://scenes/combat/cannonball.tscn")

var health: float = 100.0
var current_forward_speed: float = 0.0
var joystick_input: Vector2 = Vector2.ZERO
var port_cooldown: float = 0.0
var starboard_cooldown: float = 0.0
var wave_time: float = 0.0
var current_level: int = 1

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
	
	storage.storage_changed.connect(_on_storage_changed)
	apply_ship_level(GameManager.current_ship_level)
	
	health = max_health
	GameManager.update_player_health(health, max_health)

func set_joystick_input(vec: Vector2) -> void:
	joystick_input = vec.limit_length(1.0)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_wave_bobbing(delta)
	_update_wake(delta)
	_update_cooldowns(delta)

func _handle_movement(delta: float) -> void:
	var rudder := joystick_input.x
	var throttle := -joystick_input.y

	if abs(throttle) < 0.12:
		throttle = 0.0
	if abs(rudder) < 0.10:
		rudder = 0.0

	var target_speed := 0.0
	if throttle >= 0.0:
		target_speed = throttle * max_speed
	else:
		target_speed = throttle * max_speed * reverse_speed_ratio

	var rate := acceleration if abs(target_speed) > abs(current_forward_speed) else deceleration
	current_forward_speed = move_toward(current_forward_speed, target_speed, rate * delta)

	if throttle == 0.0:
		current_forward_speed = move_toward(current_forward_speed, 0.0, water_drag * delta)

	var speed_ratio := clamp(abs(current_forward_speed) / max_speed, 0.0, 1.0)
	var steering_authority := lerp(0.28, 1.0, speed_ratio)
	if abs(rudder) > 0.0:
		rotation.y -= rudder * turn_speed * steering_authority * delta

	velocity = -transform.basis.z * current_forward_speed
	velocity.y = 0.0
	move_and_slide()

func _handle_wave_bobbing(delta: float) -> void:
	if not visuals:
		return
	wave_time += delta * bobbing_speed

	var speed_ratio := clamp(abs(current_forward_speed) / max_speed, 0.0, 1.0)
	var y_offset := sin(wave_time) * bobbing_amount + sin(wave_time * 1.73) * bobbing_amount * 0.35
	visuals.position.y = y_offset

	var pitch := cos(wave_time * 0.82) * pitch_amount
	var roll := sin(wave_time * 1.07) * roll_amount
	roll += -joystick_input.x * turn_bank_amount * speed_ratio
	visuals.rotation = Vector3(pitch, 0.0, roll)

func _update_wake(_delta: float) -> void:
	var speed_ratio := clamp(abs(current_forward_speed) / max_speed, 0.0, 1.0)
	var wake_scale := lerp(0.35, 1.35, speed_ratio)
	for wake in [wake_left, wake_right]:
		if wake:
			wake.visible = speed_ratio > 0.08
			wake.scale.z = wake_scale
			var mat := wake.material_override as StandardMaterial3D
			if mat:
				var c := mat.albedo_color
				c.a = lerp(0.15, 0.65, speed_ratio)
				mat.albedo_color = c

func _update_cooldowns(delta: float) -> void:
	port_cooldown = max(0.0, port_cooldown - delta)
	starboard_cooldown = max(0.0, starboard_cooldown - delta)

func fire_left() -> bool:
	if port_cooldown > 0.0:
		return false
	port_cooldown = reload_time
	_fire_broadside(-transform.basis.x, port_cannons)
	return true

func fire_right() -> bool:
	if starboard_cooldown > 0.0:
		return false
	starboard_cooldown = reload_time
	_fire_broadside(transform.basis.x, starboard_cannons)
	return true

func _fire_broadside(direction: Vector3, marker_parent: Node3D) -> void:
	if not cannonball_scene:
		return

	var assisted_direction := _get_aim_assisted_direction(direction)
	var spawn_points: Array[Node] = []
	
	if marker_parent:
		for marker in marker_parent.get_children():
			if marker is Node3D and marker.visible:
				spawn_points.append(marker)

	if spawn_points.is_empty():
		_spawn_single_ball(global_position + assisted_direction * 1.6 + Vector3.UP * 0.7, assisted_direction)
		return

	for marker in spawn_points:
		if marker is Node3D:
			var spread_angle := randf_range(-0.035, 0.035)
			var spread_dir := assisted_direction.rotated(Vector3.UP, spread_angle)
			_spawn_single_ball(marker.global_position, spread_dir)

func _get_aim_assisted_direction(base_direction: Vector3) -> Vector3:
	var flat_base := Vector3(base_direction.x, 0.0, base_direction.z).normalized()
	var best_direction := flat_base
	var best_angle := deg_to_rad(aim_assist_degrees)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or not is_instance_valid(enemy):
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance <= 0.01 or distance > aim_assist_range:
			continue
		var candidate := to_enemy / distance
		var angle := flat_base.angle_to(candidate)
		if angle < best_angle:
			best_angle = angle
			best_direction = candidate

	return best_direction

func _spawn_single_ball(pos: Vector3, dir: Vector3) -> void:
	var ball := cannonball_scene.instantiate()
	get_parent().add_child(ball)
	ball.global_position = pos
	if ball.has_method("setup"):
		ball.setup(dir, cannon_damage, true)
	_spawn_muzzle_flash(pos)

func _spawn_muzzle_flash(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.72, 0.24, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.42, 0.08)
	flash.mesh = sphere
	flash.material_override = mat
	flash.global_position = pos
	get_parent().add_child(flash)

	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector3(2.4, 2.4, 2.4), 0.16)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(flash.queue_free)

func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	GameManager.update_player_health(health, max_health)
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

	# 5. Enable dual cannon firing markers at Level 8+
	if port_cannons and port_cannons.has_node("PortMarker2"):
		port_cannons.get_node("PortMarker2").visible = (current_level >= 8)
	if starboard_cannons and starboard_cannons.has_node("StarboardMarker2"):
		starboard_cannons.get_node("StarboardMarker2").visible = (current_level >= 8)

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
