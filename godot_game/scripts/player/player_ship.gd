extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal ship_destroyed

@export_group("Ship Movement")
@export var max_speed: float = 13.0
@export var acceleration: float = 3.2
@export var deceleration: float = 1.8
@export var turn_speed: float = 1.7

@export_group("Wave Simulation")
@export var bobbing_speed: float = 2.0
@export var bobbing_amount: float = 0.08
@export var roll_amount: float = 0.05

@export_group("Combat Attributes")
@export var max_health: float = 100.0
@export var reload_time: float = 2.2
@export var cannon_damage: float = 35.0
@export var cannonball_scene: PackedScene = preload("res://scenes/combat/cannonball.tscn")

var health: float = 100.0
var current_forward_speed: float = 0.0
var joystick_input: Vector2 = Vector2.ZERO
var port_cooldown: float = 0.0
var starboard_cooldown: float = 0.0
var wave_time: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var port_cannons: Node3D = $Visuals/PortCannons
@onready var starboard_cannons: Node3D = $Visuals/StarboardCannons

func _ready() -> void:
	add_to_group("player")
	health = max_health
	GameManager.register_player(self)
	GameManager.update_player_health(health, max_health)

func set_joystick_input(vec: Vector2) -> void:
	joystick_input = vec

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_wave_bobbing(delta)
	_update_cooldowns(delta)

func _handle_movement(delta: float) -> void:
	var input_len = joystick_input.length()
	
	if input_len > 0.15:
		# Calculate desired heading from 2D screen joystick (X = right/left, Y = down/up)
		# In Godot 3D: -Z is forward, +X is right, +Z is back
		var target_angle = atan2(joystick_input.x, joystick_input.y)
		# Smooth rotational interpolation (nautical rudder)
		rotation.y = rotate_toward(rotation.y, target_angle + PI, turn_speed * delta)
		
		# Smooth acceleration with water inertia
		var target_speed = input_len * max_speed
		current_forward_speed = move_toward(current_forward_speed, target_speed, acceleration * delta)
	else:
		# Nautical water drag deceleration
		current_forward_speed = move_toward(current_forward_speed, 0.0, deceleration * delta)
	
	# Ship moves in its forward direction (-basis.z)
	velocity = -transform.basis.z * current_forward_speed
	velocity.y = 0.0
	
	move_and_slide()

func _handle_wave_bobbing(delta: float) -> void:
	if not visuals:
		return
	wave_time += delta * bobbing_speed
	
	# Gentle vertical float
	var y_offset = sin(wave_time) * bobbing_amount
	visuals.position.y = y_offset
	
	# Gentle nautical pitch & roll
	var pitch = cos(wave_time * 0.8) * (roll_amount * 0.6)
	var roll = sin(wave_time) * roll_amount
	
	# Add slight banking lean when turning
	if abs(joystick_input.x) > 0.1:
		roll += -joystick_input.x * 0.06
		
	visuals.rotation = Vector3(pitch, 0.0, roll)

func _update_cooldowns(delta: float) -> void:
	if port_cooldown > 0.0:
		port_cooldown = max(0.0, port_cooldown - delta)
	if starboard_cooldown > 0.0:
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
		
	var spawn_points: Array[Node] = []
	if marker_parent:
		spawn_points = marker_parent.get_children()
		
	if spawn_points.is_empty():
		_spawn_single_ball(global_position + direction * 1.5, direction)
	else:
		for marker in spawn_points:
			if marker is Node3D:
				# Slight spread angle for volley realism
				var spread_angle = randf_range(-0.06, 0.06)
				var spread_dir = direction.rotated(Vector3.UP, spread_angle)
				_spawn_single_ball(marker.global_position, spread_dir)

func _spawn_single_ball(pos: Vector3, dir: Vector3) -> void:
	var ball = cannonball_scene.instantiate()
	get_parent().add_child(ball)
	ball.global_position = pos
	if ball.has_method("setup"):
		ball.setup(dir, cannon_damage, true)
	
	# Muzzle smoke puff
	_spawn_muzzle_flash(pos)

func _spawn_muzzle_flash(pos: Vector3) -> void:
	var flash = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.2, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	flash.mesh = sphere
	flash.material_override = mat
	flash.global_position = pos
	get_parent().add_child(flash)
	
	var tw = flash.create_tween()
	tw.tween_property(flash, "scale", Vector3(2.0, 2.0, 2.0), 0.2)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(flash.queue_free)

func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	GameManager.update_player_health(health, max_health)
	
	# Red flash on ship
	_flash_red()
	
	if health <= 0.0:
		_destroy_ship()

func _flash_red() -> void:
	if not visuals:
		return
	var tw = visuals.create_tween()
	tw.tween_property(visuals, "scale", Vector3(1.1, 1.1, 1.1), 0.1)
	tw.tween_property(visuals, "scale", Vector3.ONE, 0.1)

func _destroy_ship() -> void:
	ship_destroyed.emit()
	# Respawn after 2 seconds with full health
	current_forward_speed = 0.0
	visible = false
	set_physics_process(false)
	
	await get_tree().create_timer(2.0).timeout
	global_position = Vector3(0.0, 0.0, 0.0)
	health = max_health
	GameManager.update_player_health(health, max_health)
	visible = true
	set_physics_process(true)
