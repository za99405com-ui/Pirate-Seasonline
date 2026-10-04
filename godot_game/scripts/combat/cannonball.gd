extends Area3D

@export var speed: float = 32.0
@export var damage: float = 30.0
@export var lifetime: float = 1.8
@export var is_player_owned: bool = true

var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0

func setup(dir: Vector3, dmg: float, from_player: bool) -> void:
	velocity = dir.normalized() * speed
	# Slight upward arc
	velocity.y += 2.5
	damage = dmg
	is_player_owned = from_player

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Subtle ballistic gravity
	velocity.y -= 4.5 * delta
	global_position += velocity * delta
	
	age += delta
	# Check if hit water level (y <= 0) or lifetime expired
	if age >= lifetime or global_position.y <= -0.2:
		_spawn_splash_and_free()

func _on_body_entered(body: Node) -> void:
	_handle_hit(body)

func _on_area_entered(area: Node) -> void:
	_handle_hit(area)

func _handle_hit(target: Node) -> void:
	# Check ship hit
	if is_player_owned and target.is_in_group("enemies"):
		if target.has_method("take_damage"):
			target.take_damage(damage)
		_spawn_splash_and_free()
	elif not is_player_owned and target.is_in_group("player"):
		if target.has_method("take_damage"):
			target.take_damage(damage)
		_spawn_splash_and_free()

func _spawn_splash_and_free() -> void:
	# Spawn a visual water splash ring before queue_free
	var splash = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 1.2
	cylinder.bottom_radius = 1.2
	cylinder.height = 0.1
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.95, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splash.mesh = cylinder
	splash.material_override = mat
	splash.global_position = Vector3(global_position.x, 0.05, global_position.z)
	
	get_parent().add_child(splash)
	
	# Tween to expand and fade out
	var tween = splash.create_tween()
	tween.tween_property(splash, "scale", Vector3(2.5, 1.0, 2.5), 0.35)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(splash.queue_free)
	
	queue_free()
