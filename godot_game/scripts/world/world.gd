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

@export var enemy_ship_scene: PackedScene = preload("res://scenes/ships/enemy_ship.tscn")

var _current_camera_yaw: float = 0.0
var _is_camera_initialized: bool = false

func _ready() -> void:
	if hud and player_ship:
		hud.set_player(player_ship)
	GameManager.enemy_destroyed.connect(_on_enemy_destroyed)
	
	if camera:
		camera.fov = camera_fov
	
	_snap_camera_to_player()

func _physics_process(delta: float) -> void:
	_update_camera(delta)
	_update_ocean_anchor()

func _snap_camera_to_player() -> void:
	if not player_ship or not is_instance_valid(player_ship) or not camera:
		return
	
	_current_camera_yaw = player_ship.global_rotation.y
	var forward := Vector3(-sin(_current_camera_yaw), 0.0, -cos(_current_camera_yaw)).normalized()
	var backward := -forward
	
	camera.global_position = player_ship.global_position + backward * camera_distance + Vector3(0.0, camera_height, 0.0)
	var look_target := player_ship.global_position + forward * camera_look_ahead + Vector3(0.0, 2.0, 0.0)
	camera.look_at(look_target, Vector3.UP)
	_is_camera_initialized = true

func _update_camera(delta: float) -> void:
	if not player_ship or not is_instance_valid(player_ship) or not camera:
		return

	if not _is_camera_initialized:
		_snap_camera_to_player()
		return

	# Smoothly track ship's yaw angle
	var target_yaw: float = player_ship.global_rotation.y
	var yaw_smoothing: float = 1.0 - exp(-camera_rotation_speed * delta)
	_current_camera_yaw = lerp_angle(_current_camera_yaw, target_yaw, yaw_smoothing)

	var forward := Vector3(-sin(_current_camera_yaw), 0.0, -cos(_current_camera_yaw)).normalized()
	var backward := -forward

	var velocity: Vector3 = player_ship.velocity if "velocity" in player_ship else Vector3.ZERO
	var speed_ratio: float = clampf(velocity.length() / 14.5, 0.0, 1.0)

	# Position camera behind and above the ship based on smoothed yaw
	var ideal_pos := player_ship.global_position + backward * camera_distance + Vector3(0.0, camera_height, 0.0)
	var pos_smoothing: float = 1.0 - exp(-camera_follow_speed * delta)
	camera.global_position = camera.global_position.lerp(ideal_pos, pos_smoothing)

	# Focus ahead of the ship into the open sea for tactical forward combat visibility
	var dynamic_look_ahead: float = camera_look_ahead + speed_ratio * 3.5
	var look_target := player_ship.global_position + forward * dynamic_look_ahead + Vector3(0.0, 2.2, 0.0)
	camera.look_at(look_target, Vector3.UP)

func _update_ocean_anchor() -> void:
	if not ocean or not player_ship:
		return
	ocean.global_position.x = player_ship.global_position.x
	ocean.global_position.z = player_ship.global_position.z

func _on_enemy_destroyed(_enemy_name: String) -> void:
	await get_tree().create_timer(5.0).timeout
	if not enemy_ship_scene:
		return
	var new_enemy := enemy_ship_scene.instantiate()
	add_child(new_enemy)
	var angle := randf() * TAU
	var dist: float = randf_range(52.0, 68.0)
	var spawn_pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	if player_ship and is_instance_valid(player_ship):
		spawn_pos += player_ship.global_position
	new_enemy.global_position = spawn_pos
