extends Node3D

@onready var player_ship: Node3D = $PlayerShip
@onready var camera: Camera3D = $IsometricCamera
@onready var hud: CanvasLayer = $HUD
@onready var ocean: MeshInstance3D = $OceanPlane

@export_group("Sailing Camera")
@export var camera_distance: float = 27.0
@export var camera_pitch: float = 0.52
@export var camera_fov: float = 58.0
@export var camera_follow_speed: float = 5.2
@export var camera_turn_speed: float = 4.0
@export var camera_orbit_sensitivity: float = 0.006
@export var camera_min_pitch: float = 0.30
@export var camera_max_pitch: float = 0.96
@export var camera_return_delay: float = 0.28

@export_group("Combat Awareness")
@export var combat_enter_distance: float = 68.0
@export var combat_exit_distance: float = 82.0
@export var combat_exit_grace: float = 2.5
@export var combat_camera_distance: float = 31.0
@export var combat_camera_pitch: float = 0.57
@export var combat_camera_fov: float = 62.0
@export var combat_heading_assist: float = 0.22
@export var combat_heading_max_degrees: float = 18.0

@export var enemy_ship_scene: PackedScene = preload("res://scenes/ships/enemy_ship.tscn")

var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.52
var _camera_drag_touch: int = -1
var _mouse_orbiting: bool = false
var _camera_idle_time: float = 0.0

var _in_combat: bool = false
var _combat_enemy: Node3D = null
var _combat_clear_timer: float = 0.0

func _ready() -> void:
	if hud and player_ship:
		hud.set_player(player_ship)

	GameManager.enemy_destroyed.connect(_on_enemy_destroyed)

	if player_ship:
		_camera_yaw = player_ship.global_rotation.y
	_camera_pitch = camera_pitch

	if camera:
		camera.fov = camera_fov

	_snap_camera()

func _physics_process(delta: float) -> void:
	_update_combat_state(delta)
	_update_camera(delta)
	_update_ocean_anchor()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _camera_drag_touch == -1:
			_camera_drag_touch = touch.index
			_camera_idle_time = 0.0
		elif not touch.pressed and touch.index == _camera_drag_touch:
			_camera_drag_touch = -1
			_camera_idle_time = 0.0
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _camera_drag_touch:
			_rotate_camera(drag.relative)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_mouse_orbiting = mouse_button.pressed
			_camera_idle_time = 0.0
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _mouse_orbiting:
			_rotate_camera(motion.relative)

func _rotate_camera(relative: Vector2) -> void:
	_camera_idle_time = 0.0
	_camera_yaw -= relative.x * camera_orbit_sensitivity
	_camera_pitch = clampf(
		_camera_pitch + relative.y * camera_orbit_sensitivity,
		camera_min_pitch,
		camera_max_pitch
	)

func _snap_camera() -> void:
	if not player_ship or not camera:
		return

	var distance: float = combat_camera_distance if _in_combat else camera_distance
	camera.global_position = player_ship.global_position + _camera_offset(distance)
	camera.look_at(player_ship.global_position + Vector3(0.0, 2.0, 0.0), Vector3.UP)

func _update_camera(delta: float) -> void:
	if not player_ship or not is_instance_valid(player_ship) or not camera:
		return

	var camera_is_held: bool = _camera_drag_touch != -1 or _mouse_orbiting
	var desired_yaw: float = player_ship.global_rotation.y
	var desired_pitch: float = combat_camera_pitch if _in_combat else camera_pitch

	if _in_combat and _combat_enemy and is_instance_valid(_combat_enemy):
		var to_enemy: Vector3 = _combat_enemy.global_position - player_ship.global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.001:
			var ship_forward: Vector3 = -player_ship.global_transform.basis.z
			ship_forward.y = 0.0
			ship_forward = ship_forward.normalized()
			var enemy_dir: Vector3 = to_enemy.normalized()
			var enemy_angle: float = ship_forward.signed_angle_to(enemy_dir, Vector3.UP)
			var max_assist: float = deg_to_rad(combat_heading_max_degrees)
			desired_yaw += clampf(enemy_angle * combat_heading_assist, -max_assist, max_assist)

	if camera_is_held:
		_camera_idle_time = 0.0
	else:
		_camera_idle_time += delta
		if _camera_idle_time >= camera_return_delay:
			var turn_blend: float = 1.0 - exp(-camera_turn_speed * delta)
			_camera_yaw = lerp_angle(_camera_yaw, desired_yaw, turn_blend)
			_camera_pitch = lerpf(_camera_pitch, desired_pitch, turn_blend)

	var desired_distance: float = combat_camera_distance if _in_combat else camera_distance
	var desired_fov: float = combat_camera_fov if _in_combat else camera_fov
	var ideal_position: Vector3 = player_ship.global_position + _camera_offset(desired_distance)
	var follow_blend: float = 1.0 - exp(-camera_follow_speed * delta)
	camera.global_position = camera.global_position.lerp(ideal_position, follow_blend)

	var look_target: Vector3 = player_ship.global_position + Vector3(0.0, 2.0, 0.0)

	if _in_combat and _combat_enemy and is_instance_valid(_combat_enemy) and not camera_is_held:
		var enemy_offset: Vector3 = _combat_enemy.global_position - player_ship.global_position
		enemy_offset.y = 0.0
		var bias: Vector3 = enemy_offset.limit_length(16.0) * 0.20
		look_target += bias

	camera.look_at(look_target, Vector3.UP)
	camera.fov = lerpf(camera.fov, desired_fov, 1.0 - exp(-4.5 * delta))

func _camera_offset(distance: float) -> Vector3:
	var horizontal: float = cos(_camera_pitch) * distance
	var height: float = sin(_camera_pitch) * distance
	return Vector3(
		sin(_camera_yaw) * horizontal,
		height,
		cos(_camera_yaw) * horizontal
	)

func _update_combat_state(delta: float) -> void:
	if not player_ship or not is_instance_valid(player_ship):
		return

	var nearest_enemy: Node3D = _find_nearest_enemy()
	var nearest_distance: float = INF
	if nearest_enemy:
		nearest_distance = player_ship.global_position.distance_to(nearest_enemy.global_position)

	if not _in_combat:
		if nearest_enemy and nearest_distance <= combat_enter_distance:
			_enter_combat(nearest_enemy)
		return

	if nearest_enemy and nearest_distance <= combat_exit_distance:
		_combat_enemy = nearest_enemy
		_combat_clear_timer = 0.0
	else:
		_combat_clear_timer += delta
		if _combat_clear_timer >= combat_exit_grace:
			_exit_combat()

func _enter_combat(enemy: Node3D) -> void:
	_in_combat = true
	_combat_enemy = enemy
	_combat_clear_timer = 0.0
	_camera_idle_time = camera_return_delay

func _exit_combat() -> void:
	_in_combat = false
	_combat_enemy = null
	_combat_clear_timer = 0.0
	_camera_idle_time = camera_return_delay

func is_in_combat() -> bool:
	return _in_combat

func get_combat_enemy() -> Node3D:
	return _combat_enemy

func get_combat_distance() -> float:
	if not _combat_enemy or not is_instance_valid(_combat_enemy) or not player_ship:
		return 0.0
	return player_ship.global_position.distance_to(_combat_enemy.global_position)

func _find_nearest_enemy() -> Node3D:
	var best_enemy: Node3D = null
	var best_distance: float = INF

	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue

		var enemy := candidate as Node3D
		var dead_value: Variant = enemy.get("is_dead")
		if dead_value is bool and bool(dead_value):
			continue

		var distance: float = player_ship.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best_enemy = enemy

	return best_enemy

func _update_ocean_anchor() -> void:
	if not ocean or not player_ship:
		return

	ocean.global_position.x = player_ship.global_position.x
	ocean.global_position.z = player_ship.global_position.z

func _on_enemy_destroyed(_enemy_name: String) -> void:
	if _combat_enemy and not is_instance_valid(_combat_enemy):
		_exit_combat()

	await get_tree().create_timer(5.0).timeout
	if not enemy_ship_scene:
		return

	var new_enemy := enemy_ship_scene.instantiate()
	add_child(new_enemy)

	var angle: float = randf() * TAU
	var distance: float = randf_range(54.0, 70.0)
	var spawn_position := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	if player_ship and is_instance_valid(player_ship):
		spawn_position += player_ship.global_position

	new_enemy.global_position = spawn_position
