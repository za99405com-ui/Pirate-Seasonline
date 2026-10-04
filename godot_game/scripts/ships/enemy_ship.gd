extends CharacterBody3D

@export var max_health: float = 100.0
@export var sail_speed: float = 7.0
@export var turn_speed: float = 1.3
@export var aggro_distance: float = 65.0
@export var combat_distance: float = 24.0
@export var fire_cooldown: float = 3.5
@export var cannon_damage: float = 20.0
@export var loot_crate_scene: PackedScene = preload("res://scenes/loot/gold_crate.tscn")
@export var cannonball_scene: PackedScene = preload("res://scenes/combat/cannonball.tscn")

var health: float = 100.0
var reload_timer: float = 1.0
var player_ref: Node3D = null
var is_dead: bool = false

@onready var visuals: Node3D = $Visuals
@onready var health_bar_mesh: MeshInstance3D = $HealthBarAnchor/HealthBarMesh

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = GameManager.player_ship
		if not player_ref:
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player_ref = players[0]
				
	if player_ref and is_instance_valid(player_ref):
		_process_combat_ai(delta)
	else:
		_process_patrol_ai(delta)
		
	move_and_slide()

func _process_combat_ai(delta: float) -> void:
	var to_player = player_ref.global_position - global_position
	to_player.y = 0.0
	var dist = to_player.length()
	
	if dist > aggro_distance:
		_process_patrol_ai(delta)
		return
		
	reload_timer -= delta
	
	if dist > combat_distance:
		# Sail towards player
		var target_angle = atan2(-to_player.x, -to_player.z)
		rotation.y = rotate_toward(rotation.y, target_angle, turn_speed * delta)
		velocity = -transform.basis.z * sail_speed
	else:
		# In combat range: align broadside to player (perpendicular angle)
		var broadside_dir = to_player.normalized().rotated(Vector3.UP, PI / 2.0)
		var broadside_angle = atan2(-broadside_dir.x, -broadside_dir.z)
		rotation.y = rotate_toward(rotation.y, broadside_angle, turn_speed * 1.5 * delta)
		velocity = -transform.basis.z * (sail_speed * 0.45)
		
		# Check if ready to fire cannon volley
		if reload_timer <= 0.0:
			reload_timer = fire_cooldown
			_fire_cannons_at_player(to_player.normalized())

func _process_patrol_ai(delta: float) -> void:
	velocity = -transform.basis.z * (sail_speed * 0.4)
	# Slow random wander
	rotation.y += 0.2 * delta

func _fire_cannons_at_player(dir_to_player: Vector3) -> void:
	if not cannonball_scene:
		return
	
	# Determine which flank faces the player
	var right_flank = transform.basis.x
	var fire_dir = right_flank
	if dir_to_player.dot(right_flank) < 0.0:
		fire_dir = -right_flank
		
	for i in range(2):
		var offset = fire_dir * 1.6 + transform.basis.z * (float(i) * 1.2 - 0.6)
		var spread = fire_dir.rotated(Vector3.UP, randf_range(-0.08, 0.08))
		
		var ball = cannonball_scene.instantiate()
		get_parent().add_child(ball)
		ball.global_position = global_position + offset
		if ball.has_method("setup"):
			ball.setup(spread, cannon_damage, false)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = max(0.0, health - amount)
	_update_health_bar()
	_flash_hit()
	
	if health <= 0.0:
		_sink_and_drop_loot()

func _update_health_bar() -> void:
	if health_bar_mesh:
		var frac = clamp(health / max_health, 0.0, 1.0)
		health_bar_mesh.scale.x = frac
		var mat = health_bar_mesh.material_override as StandardMaterial3D
		if mat:
			if frac > 0.5:
				mat.albedo_color = Color(0.2, 0.85, 0.3)
			elif frac > 0.25:
				mat.albedo_color = Color(0.95, 0.8, 0.1)
			else:
				mat.albedo_color = Color(0.9, 0.2, 0.1)

func _flash_hit() -> void:
	if not visuals:
		return
	var tw = visuals.create_tween()
	tw.tween_property(visuals, "scale", Vector3(1.15, 1.15, 1.15), 0.08)
	tw.tween_property(visuals, "scale", Vector3.ONE, 0.08)

func _sink_and_drop_loot() -> void:
	is_dead = true
	set_physics_process(false)
	
	# Spawn 3 to 5 floating gold crates
	var loot_count = randi_range(3, 5)
	if loot_crate_scene:
		for i in range(loot_count):
			var crate = loot_crate_scene.instantiate()
			get_parent().add_child(crate)
			var scatter = Vector3(randf_range(-4.5, 4.5), 0.0, randf_range(-4.5, 4.5))
			crate.global_position = global_position + scatter
			if crate.has_method("setup_value"):
				crate.setup_value(randi_range(20, 45))
				
	# Explosion particle effect
	_spawn_destruction_effect()
	
	GameManager.enemy_destroyed.emit("Pirate Raider")
	
	# Sink tween
	var tw = create_tween()
	tw.tween_property(visuals, "position:y", -3.0, 1.2)
	tw.parallel().tween_property(visuals, "rotation:z", 0.6, 1.2)
	tw.tween_callback(queue_free)

func _spawn_destruction_effect() -> void:
	var boom = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.8
	sphere.height = 3.6
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.1, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	boom.mesh = sphere
	boom.material_override = mat
	boom.global_position = global_position
	get_parent().add_child(boom)
	
	var tw = boom.create_tween()
	tw.tween_property(boom, "scale", Vector3(2.5, 2.5, 2.5), 0.4)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(boom.queue_free)
