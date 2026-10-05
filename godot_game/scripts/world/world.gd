extends Node3D

@onready var player_ship: Node3D = $PlayerShip
@onready var camera: Camera3D = $IsometricCamera
@onready var hud: CanvasLayer = $HUD
@onready var ocean: MeshInstance3D = $OceanPlane

@export_group("Free Combat Camera")
@export var camera_distance: float = 28.0
@export var camera_follow_speed: float = 5.0
@export var camera_fov: float = 58.0
@export var camera_orbit_sensitivity: float = 0.006
@export var camera_min_pitch: float = 0.28
@export var camera_max_pitch: float = 1.05
@export var camera_default_pitch: float = 0.52
@export var camera_return_delay: float = 0.45
@export var camera_return_speed: float = 3.6
@export var camera_move_return_delay: float = 0.12
@export var defense_alert_distance: float = 52.0
@export var target_lock_distance: float = 90.0

@export var enemy_ship_scene: PackedScene = preload("res://scenes/ships/enemy_ship.tscn")

var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.52
var _camera_drag_touch: int = -1
var _mouse_orbiting: bool = false
var _camera_idle_time: float = 0.0
var _combat_target: Node3D = null

func _ready() -> void:
	if hud and player_ship:
		hud.set_player(player_ship)
	GameManager.enemy_destroyed.connect(_on_enemy_destroyed)

	if camera:
		camera.fov = camera_fov

	# Start from a useful rear-quarter angle, then leave camera control fully to the player.
	_camera_yaw = player_ship.global_rotation.y if player_ship else 0.0
	_camera_pitch = camera_default_pitch
	_snap_camera_to_player()

func _physics_process(delta: float) -> void:
	_validate_combat_target()
	_update_camera(delta)
	_update_ocean_anchor()

func _unhandled_input(event: InputEvent) -> void:
	# Empty-screen drag rotates the camera freely around the player's ship.
	# GUI controls consume their own touches, so movement/aim/fire controls do not fight the camera.
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
			_apply_camera_drag(drag.relative)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_mouse_orbiting = mouse_button.pressed
			_camera_idle_time = 0.0
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _mouse_orbiting:
			_apply_camera_drag(motion.relative)

func _apply_camera_drag(relative: Vector2) -> void:
	_camera_idle_time = 0.0
	_camera_yaw -= relative.x * camera_orbit_sensitivity
	_camera_pitch = clampf(
		_camera_pitch + relative.y * camera_orbit_sensitivity,
		camera_min_pitch,
		camera_max_pitch
	)

func _snap_camera_to_player() -> void:
	if not player_ship or not is_instance_valid(player_ship) or not camera:
		return

	camera.global_position = player_ship.global_position + _get_camera_offset()
	camera.look_at(player_ship.global_position + Vector3(0.0, 2.0, 0.0), Vector3.UP)

func _update_camera(delta: float) -> void:
	if not player_ship or not is_instance_valid(player_ship) or not camera:
		return

	var camera_is_held: bool = _camera_drag_touch != -1 or _mouse_orbiting

	# "Magnetic" rear camera:
	# while the player is touching the camera it is fully free.
	# once released, it smoothly returns behind the ship.
	# target lock intentionally disables this auto-return so combat framing stays where the player left it.
	if camera_is_held:
		_camera_idle_time = 0.0
	elif not (_combat_target and is_instance_valid(_combat_target)):
		_camera_idle_time += delta

		var ship_is_moving: bool = false
		if player_ship is CharacterBody3D:
			var body := player_ship as CharacterBody3D
			ship_is_moving = body.velocity.length() > 0.35

		var active_delay: float = camera_move_return_delay if ship_is_moving else camera_return_delay
		if _camera_idle_time >= active_delay:
			var return_blend: float = 1.0 - exp(-camera_return_speed * delta)
			_camera_yaw = lerp_angle(_camera_yaw, player_ship.global_rotation.y, return_blend)
			_camera_pitch = lerpf(_camera_pitch, camera_default_pitch, return_blend)
	else:
		_camera_idle_time = 0.0

	var ideal_pos: Vector3 = player_ship.global_position + _get_camera_offset()
	var smoothing: float = 1.0 - exp(-camera_follow_speed * delta)
	camera.global_position = camera.global_position.lerp(ideal_pos, smoothing)

	var look_target: Vector3 = player_ship.global_position + Vector3(0.0, 2.0, 0.0)
	camera.look_at(look_target, Vector3.UP)
	camera.fov = lerpf(camera.fov, camera_fov, 1.0 - exp(-5.0 * delta))

func _get_camera_offset() -> Vector3:
	var horizontal: float = cos(_camera_pitch) * camera_distance
	var height: float = sin(_camera_pitch) * camera_distance
	return Vector3(
		sin(_camera_yaw) * horizontal,
		height,
		cos(_camera_yaw) * horizontal
	)

func screen_aim_to_world(input_vector: Vector2) -> Vector3:
	if not camera or input_vector.length() < 0.08:
		return Vector3.ZERO

	var cam_forward: Vector3 = -camera.global_transform.basis.z
	cam_forward.y = 0.0
	if cam_forward.length_squared() < 0.0001:
		cam_forward = Vector3.FORWARD
	else:
		cam_forward = cam_forward.normalized()

	var cam_right: Vector3 = camera.global_transform.basis.x
	cam_right.y = 0.0
	if cam_right.length_squared() < 0.0001:
		cam_right = Vector3.RIGHT
	else:
		cam_right = cam_right.normalized()

	# Up on the aim stick means "toward the top of the screen".
	var result: Vector3 = cam_right * input_vector.x + cam_forward * -input_vector.y
	return result.normalized() if result.length_squared() > 0.0001 else Vector3.ZERO

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
