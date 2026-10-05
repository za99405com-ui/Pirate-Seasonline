extends Node3D

@onready var player_ship: Node3D = $PlayerShip
@onready var camera: Camera3D = $IsometricCamera
@onready var hud: CanvasLayer = $HUD
@onready var ocean: MeshInstance3D = $OceanPlane

@export_group("Combat Camera")
@export var camera_distance: float = 25.0
@export var camera_height: float = 14.0
@export var camera_look_ahead: float = 7.5
@export var camera_follow_speed: float = 4.2
@export var camera_rotation_speed: float = 3.4
@export var camera_fov: float = 58.0
@export var defense_alert_distance: float = 52.0
@export var target_lock_distance: float = 90.0

@export var enemy_ship_scene: PackedScene = preload("res://scenes/ships/enemy_ship.tscn")

var _current_camera_yaw: float = 0.0
var _is_camera_initialized: bool = false
var _camera_zoom: float = 1.0
var _combat_target: Node3D = null

func _ready() -> void:
	if hud and player_ship:
		hud.set_player(player_ship)
	GameManager.enemy_destroyed.connect(_on_enemy_destroyed)

	if camera:
		camera.fov = camera_fov

	_snap_camera_to_player()

func _physics_process(delta: float) -> void:
	_validate_combat_target()
	_update_camera(delta)
	_update_ocean_anchor()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_camera_zoom(-0.10)
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_camera_zoom(0.10)
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_try_select_target_at_screen(mouse_event.position)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_try_select_target_at_screen(touch_event.position)

func _snap_camera_to_player() -> void:
	if not player_ship or not is_instance_valid(player_ship) or not camera:
		return

	_current_camera_yaw = player_ship.global_rotation.y
	var forward: Vector3 = -player_ship.global_transform.basis.z.normalized()
	var backward: Vector3 = -forward
	var distance: float = camera_distance * _camera_zoom
	var height: float = camera_height * _camera_zoom

	camera.global_position = player_ship.global_position + backward * distance + Vector3(0.0, height, 0.0)
	var look_target: Vector3 = player_ship.global_position + forward * camera_look_ahead + Vector3(0.0, 2.0, 0.0)
	camera.look_at(look_target, Vector3.UP)
	_is_camera_initialized = true

func _update_camera(delta: float) -> void:
	if not player_ship or not is_instance_valid(player_ship) or not camera:
		return

	if not _is_camera_initialized:
		_snap_camera_to_player()
		return

	var target_yaw: float = player_ship.global_rotation.y
	var yaw_smoothing: float = 1.0 - exp(-camera_rotation_speed * delta)
	_current_camera_yaw = lerp_angle(_current_camera_yaw, target_yaw, yaw_smoothing)

	var forward: Vector3 = Vector3(-sin(_current_camera_yaw), 0.0, -cos(_current_camera_yaw)).normalized()
	var backward: Vector3 = -forward
	var speed_ratio: float = 0.0
	if player_ship is CharacterBody3D:
		var player_body := player_ship as CharacterBody3D
		speed_ratio = clampf(player_body.velocity.length() / 14.5, 0.0, 1.0)

	var desired_distance: float = camera_distance * _camera_zoom
	var desired_height: float = camera_height * _camera_zoom
	var look_target: Vector3

	if _combat_target and is_instance_valid(_combat_target):
		var target_distance: float = player_ship.global_position.distance_to(_combat_target.global_position)
		var framing_extra: float = clampf(target_distance * 0.16, 0.0, 12.0)
		desired_distance = maxf(desired_distance, 18.0 + framing_extra)
		desired_height = maxf(desired_height, 11.0 + framing_extra * 0.48)
		look_target = player_ship.global_position.lerp(_combat_target.global_position, 0.46) + Vector3(0.0, 2.0, 0.0)
		camera.fov = lerpf(camera.fov, minf(66.0, camera_fov + target_distance * 0.10), 1.0 - exp(-4.0 * delta))
	else:
		var dynamic_look_ahead: float = camera_look_ahead + speed_ratio * 3.5
		look_target = player_ship.global_position + forward * dynamic_look_ahead + Vector3(0.0, 2.2, 0.0)
		camera.fov = lerpf(camera.fov, camera_fov, 1.0 - exp(-4.0 * delta))

	var ideal_pos: Vector3 = player_ship.global_position + backward * desired_distance + Vector3(0.0, desired_height, 0.0)
	var pos_smoothing: float = 1.0 - exp(-camera_follow_speed * delta)
	camera.global_position = camera.global_position.lerp(ideal_pos, pos_smoothing)
	camera.look_at(look_target, Vector3.UP)

func adjust_camera_zoom(amount: float) -> void:
	_camera_zoom = clampf(_camera_zoom + amount, 0.62, 1.45)

func get_camera_zoom() -> float:
	return _camera_zoom

func toggle_combat_target() -> void:
	if _combat_target and is_instance_valid(_combat_target):
		_set_combat_target(null)
		return

	var nearest: Node3D = _find_nearest_enemy(target_lock_distance)
	if nearest:
		_set_combat_target(nearest)

func get_combat_target() -> Node3D:
	return _combat_target

func get_war_mode() -> String:
	if _combat_target and is_instance_valid(_combat_target):
		return "ATTACK"

	if _find_nearest_enemy(defense_alert_distance):
		return "DEFENSE"

	return ""

func _set_combat_target(target: Node3D) -> void:
	if _combat_target and is_instance_valid(_combat_target) and _combat_target.has_method("set_targeted"):
		_combat_target.call("set_targeted", false)

	_combat_target = target

	if _combat_target and is_instance_valid(_combat_target) and _combat_target.has_method("set_targeted"):
		_combat_target.call("set_targeted", true)

	if player_ship and is_instance_valid(player_ship) and player_ship.has_method("set_combat_target"):
		player_ship.call("set_combat_target", _combat_target)

func _validate_combat_target() -> void:
	if not _combat_target:
		return
	if not is_instance_valid(_combat_target):
		_combat_target = null
		if player_ship and is_instance_valid(player_ship) and player_ship.has_method("set_combat_target"):
			player_ship.call("set_combat_target", null)
		return

	var dead_value: Variant = _combat_target.get("is_dead")
	if dead_value is bool and bool(dead_value):
		_set_combat_target(null)
		return

	if player_ship and player_ship.global_position.distance_to(_combat_target.global_position) > target_lock_distance * 1.25:
		_set_combat_target(null)

func _find_nearest_enemy(max_distance: float) -> Node3D:
	if not player_ship or not is_instance_valid(player_ship):
		return null

	var best_enemy: Node3D = null
	var best_distance: float = max_distance

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

func _try_select_target_at_screen(screen_position: Vector2) -> void:
	if not camera:
		return

	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 500.0)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Variant = result.get("collider")
	if collider is Node3D:
		var target_node := collider as Node3D
		if target_node.is_in_group("enemies"):
			_set_combat_target(target_node)

func _update_ocean_anchor() -> void:
	if not ocean or not player_ship:
		return
	ocean.global_position.x = player_ship.global_position.x
	ocean.global_position.z = player_ship.global_position.z

func _on_enemy_destroyed(_enemy_name: String) -> void:
	_validate_combat_target()
	await get_tree().create_timer(5.0).timeout
	if not enemy_ship_scene:
		return

	var new_enemy := enemy_ship_scene.instantiate()
	add_child(new_enemy)
	var angle: float = randf() * TAU
	var dist: float = randf_range(52.0, 68.0)
	var spawn_pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	if player_ship and is_instance_valid(player_ship):
		spawn_pos += player_ship.global_position
	new_enemy.global_position = spawn_pos
