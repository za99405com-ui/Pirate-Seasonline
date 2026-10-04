extends Node3D

@onready var player_ship: Node3D = $PlayerShip
@onready var camera: Camera3D = $IsometricCamera
@onready var hud: CanvasLayer = $HUD

@export var camera_offset: Vector3 = Vector3(0.0, 18.0, 15.0)
@export var camera_follow_speed: float = 4.0
@export var enemy_ship_scene: PackedScene = preload("res://scenes/ships/enemy_ship.tscn")

func _ready() -> void:
	if hud and player_ship:
		hud.set_player(player_ship)
		
	GameManager.enemy_destroyed.connect(_on_enemy_destroyed)

func _physics_process(delta: float) -> void:
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	if not player_ship or not is_instance_valid(player_ship) or not camera:
		return
		
	var target_pos = player_ship.global_position + camera_offset
	camera.global_position = camera.global_position.lerp(target_pos, camera_follow_speed * delta)
	camera.look_at(player_ship.global_position, Vector3.UP)

func _on_enemy_destroyed(_enemy_name: String) -> void:
	# Respawn a new enemy after 5 seconds at a distant coordinate
	await get_tree().create_timer(5.0).timeout
	if enemy_ship_scene:
		var new_enemy = enemy_ship_scene.instantiate()
		add_child(new_enemy)
		var angle = randf() * TAU
		var dist = randf_range(35.0, 50.0)
		var spawn_pos = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if player_ship and is_instance_valid(player_ship):
			spawn_pos += player_ship.global_position
		new_enemy.global_position = spawn_pos
