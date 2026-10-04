extends CharacterBody3D

@export var max_health: float = 100.0
@export var sail_speed: float = 7.8
@export var turn_speed: float = 1.25
@export var aggro_distance: float = 70.0
@export var combat_distance: float = 25.0
@export var fire_cooldown: float = 3.2
@export var cannon_damage: float = 20.0
@export var loot_crate_scene: PackedScene = preload("res://scenes/loot/gold_crate.tscn")
@export var cannonball_scene: PackedScene = preload("res://scenes/combat/cannonball.tscn")

var health: float = 100.0
var reload_timer: float = 1.0
var player_ref: Node3D = null
var is_dead: bool = false
var wave_time: float = 0.0
var patrol_phase: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var health_bar_anchor: Node3D = $HealthBarAnchor
@onready var health_bar_mesh: MeshInstance3D = $HealthBarAnchor/HealthBarMesh
@onready var wake_left: MeshInstance3D = $Visuals/WakeLeft
@onready var wake_right: MeshInstance3D = $Visuals/WakeRight

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	patrol_phase = randf() * TAU
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	wave_time += delta
	_update_bobbing()
	_keep_health_bar_readable()

	if not player_ref or not is_instance_valid(player_ref):
		player_ref = GameManager.player_ship
		if not player_ref:
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player_ref = players[0]

	if player_ref and is_instance_valid(player_ref):
		_process_combat_ai(delta)
	else:
		_process_patrol_ai(delta)

	move_and_slide()
	_update_wake()

func _process_combat_ai(delta: float) -> void:
	var to_player := player_ref.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist > aggro_distance:
		_process_patrol_ai(delta)
		return

	reload_timer = max(0.0, reload_timer - delta)

	if dist > combat_distance:
		var target_angle := atan2(-to_player.x, -to_player.z)
		rotation.y = rotate_toward(rotation.y, target_angle, turn_speed * delta)
		velocity = -transform.basis.z * sail_speed
	else:
		var side_sign := 1.0 if sin(wave_time * 0.35 + patrol_phase) >= 0.0 else -1.0
		var broadside_dir := to_player.normalized().rotated(Vector3.UP, side_sign * PI / 2.0)
		var broadside_angle := atan2(-broadside_dir.x, -broadside_dir.z)
		rotation.y = rotate_toward(rotation.y, broadside_angle, turn_speed * 1.35 * delta)
		velocity = -transform.basis.z * (sail_speed * 0.52)

		var flank_alignment: float = absf(to_player.normalized().dot(transform.basis.x))
		if reload_timer <= 0.0 and flank_alignment > 0.72:
			reload_timer = fire_cooldown
			_fire_cannons_at_player(to_player.normalized())

func _process_patrol_ai(delta: float) -> void:
	patrol_phase += delta * 0.18
	velocity = -transform.basis.z * (sail_speed * 0.38)
	rotation.y += sin(patrol_phase) * 0.18 * delta

func _fire_cannons_at_player(dir_to_player: Vector3) -> void:
	if not cannonball_scene:
		return

	var right_flank := transform.basis.x
	var fire_dir := right_flank if dir_to_player.dot(right_flank) >= 0.0 else -right_flank

	for i in range(2):
		var longitudinal := float(i) * 1.45 - 0.72
		var offset := fire_dir * 1.65 + transform.basis.z * longitudinal + Vector3.UP * 1.0
		var spread := fire_dir.rotated(Vector3.UP, randf_range(-0.05, 0.05))

		var ball := cannonball_scene.instantiate()
		get_parent().add_child(ball)
		ball.global_position = global_position + offset
		if ball.has_method("setup"):
			ball.setup(spread, cannon_damage, false)

func _update_bobbing() -> void:
	if visuals:
		visuals.position.y = sin(wave_time * 1.55 + patrol_phase) * 0.09
		visuals.rotation.x = cos(wave_time * 1.18 + patrol_phase) * 0.022
		visuals.rotation.z = sin(wave_time * 1.36 + patrol_phase) * 0.035

func _update_wake() -> void:
	var ratio: float = clampf(velocity.length() / sail_speed, 0.0, 1.0)
	for wake in [wake_left, wake_right]:
		if wake:
			wake.visible = ratio > 0.08
			wake.scale.z = lerp(0.3, 1.0, ratio)

func _keep_health_bar_readable() -> void:
	if health_bar_anchor:
		health_bar_anchor.global_rotation = Vector3.ZERO

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = max(0.0, health - amount)
	_update_health_bar()
	_flash_hit()

	if health <= 0.0:
		_sink_and_drop_loot()

func _update_health_bar() -> void:
	if not health_bar_mesh:
		return
	var frac: float = clampf(health / max_health, 0.0, 1.0)
	health_bar_mesh.scale.x = max(0.02, frac)
	health_bar_mesh.position.x = -(1.0 - frac) * 1.15
	var mat := health_bar_mesh.material_override as StandardMaterial3D
	if mat:
		if frac > 0.5:
			mat.albedo_color = Color(0.18, 0.88, 0.33)
		elif frac > 0.25:
			mat.albedo_color = Color(1.0, 0.72, 0.12)
		else:
			mat.albedo_color = Color(0.95, 0.16, 0.12)

func _flash_hit() -> void:
	if not visuals:
		return
	var base_scale := visuals.scale
	var tw := visuals.create_tween()
	tw.tween_property(visuals, "scale", base_scale * 1.07, 0.07)
	tw.tween_property(visuals, "scale", base_scale, 0.10)

func _sink_and_drop_loot() -> void:
	is_dead = true
	set_physics_process(false)

	var loot_count := randi_range(3, 5)
	if loot_crate_scene:
		for i in range(loot_count):
			var crate := loot_crate_scene.instantiate()
			get_parent().add_child(crate)
			var scatter := Vector3(randf_range(-4.5, 4.5), 0.0, randf_range(-4.5, 4.5))
			crate.global_position = global_position + scatter
			if crate.has_method("setup_value"):
				crate.setup_value(randi_range(20, 45))

	_spawn_destruction_effect()
	GameManager.enemy_destroyed.emit("Pirate Raider")

	if health_bar_anchor:
		health_bar_anchor.visible = false

	var tw := create_tween()
	tw.tween_property(visuals, "position:y", -3.2, 1.25)
	tw.parallel().tween_property(visuals, "rotation:z", 0.72, 1.25)
	tw.tween_callback(queue_free)

func _spawn_destruction_effect() -> void:
	var boom := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.42, 0.08, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.22, 0.02)
	boom.mesh = sphere
	boom.material_override = mat
	boom.global_position = global_position + Vector3.UP * 0.8
	get_parent().add_child(boom)

	var tw := boom.create_tween()
	tw.tween_property(boom, "scale", Vector3(2.7, 2.7, 2.7), 0.42)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.42)
	tw.tween_callback(boom.queue_free)
