extends Node3D

@onready var player_ship: Node3D = $PlayerShip
@onready var camera: Camera3D = $IsometricCamera
@onready var hud: CanvasLayer = $HUD
@onready var ocean: MeshInstance3D = $OceanPlane

@export var camera_offset: Vector3 = Vector3(0.0, 24.0, 21.0)
@export var camera_follow_speed: float = 4.8
@export var camera_look_ahead: float = 5.0
@export var enemy_ship_scene: PackedScene = preload("res://scenes/ships/enemy_ship.tscn")

func _ready() -> void:
	if hud and player_ship:
		hud.set_player(player_ship)
	GameManager.enemy_destroyed.connect(_on_enemy_destroyed)

func _physics_process(delta: float) -> void:
	_update_camera(delta)
	_update_ocean_anchor()

func _update_camera(delta: float) -> void:
	if not player_ship or not is_instance_valid(player_ship) or not camera:
		return

	var velocity: Vector3 = player_ship.velocity if "velocity" in player_ship else Vector3.ZERO
	var speed_ratio: float = clampf(velocity.length() / 14.5, 0.0, 1.0)
	var forward: Vector3 = -player_ship.global_transform.basis.z
	var look_ahead: Vector3 = forward * camera_look_ahead * speed_ratio
	var target_pos: Vector3 = player_ship.global_position + camera_offset + look_ahead * 0.35
	var smoothing: float = 1.0 - exp(-camera_follow_speed * delta)
	camera.global_position = camera.global_position.lerp(target_pos, smoothing)

	var look_target: Vector3 = player_ship.global_position + look_ahead
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
