extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal ship_destroyed

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
@export var cannonball_scene: PackedScene = preload("res://scenes/combat/cannonball.tscn")

var health: float = 100.0
var current_forward_speed: float = 0.0
var joystick_input: Vector2 = Vector2.ZERO
var port_cooldown: float = 0.0
var starboard_cooldown: float = 0.0
var wave_time: float = 0.0
var _last_move_dir: Vector3 = Vector3.FORWARD

@onready var visuals: Node3D = $Visuals
@onready var port_cannons: Node3D = $Visuals/PortCannons
@onready var starboard_cannons: Node3D = $Visuals/StarboardCannons
@onready var wake_left: MeshInstance3D = $Visuals/WakeLeft
@onready var wake_right: MeshInstance3D = $Visuals/WakeRight

func _ready() -> void:
	add_to_group("player")
	health = max_health
	GameManager.register_player(self)
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
	if velocity.length_squared() > 0.01:
		_last_move_dir = velocity.normalized()
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
	var wake_scale := lerp(0.35, 1.25, speed_ratio)
	for wake in [wake_left, wake_right]:
		if wake:
			wake.visible = speed_ratio > 0.08
			wake.scale.z = wake_scale
			var mat := wake.material_override as StandardMaterial3D
			if mat:
				var c := mat.albedo_color
				c.a = lerp(0.15, 0.62, speed_ratio)
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

	var spawn_points: Array[Node] = marker_parent.get_children() if marker_parent else []
	if spawn_points.is_empty():
		_spawn_single_ball(global_position + direction * 1.5 + Vector3.UP * 0.7, direction)
		return

	for marker in spawn_points:
		if marker is Node3D:
			var spread_angle := randf_range(-0.045, 0.045)
			var spread_dir := direction.rotated(Vector3.UP, spread_angle)
			_spawn_single_ball(marker.global_position, spread_dir)

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
	sphere.radius = 0.28
	sphere.height = 0.56
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.72, 0.24, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.42, 0.08)
	flash.mesh = sphere
	flash.material_override = mat
	flash.global_position = pos
	get_parent().add_child(flash)

	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector3(2.2, 2.2, 2.2), 0.16)
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
