extends Area3D

@export var speed: float = 34.0
@export var damage: float = 30.0
@export var lifetime: float = 2.0
@export var is_player_owned: bool = true

var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0
var spent: bool = false

func setup(dir: Vector3, dmg: float, from_player: bool) -> void:
	velocity = dir.normalized() * speed
	velocity.y += 2.8
	damage = dmg
	is_player_owned = from_player

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if spent:
		return

	velocity.y -= 4.8 * delta
	global_position += velocity * delta
	rotation.x += delta * 7.0
	rotation.z += delta * 4.0

	age += delta
	if age >= lifetime or global_position.y <= -0.18:
		_finish_with_splash()

func _on_body_entered(body: Node) -> void:
	_handle_hit(body)

func _on_area_entered(area: Node) -> void:
	_handle_hit(area)

func _handle_hit(target: Node) -> void:
	if spent:
		return

	if is_player_owned and target.is_in_group("enemies"):
		if target.has_method("take_damage"):
			target.take_damage(damage)
			_finish_with_splash()
	elif not is_player_owned and target.is_in_group("player"):
		if target.has_method("take_damage"):
			target.take_damage(damage)
			_finish_with_splash()

func _finish_with_splash() -> void:
	if spent:
		return
	spent = true
	monitoring = false
	_spawn_splash()
	queue_free()

func _spawn_splash() -> void:
	var splash := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.9
	cylinder.bottom_radius = 1.3
	cylinder.height = 0.08
	cylinder.radial_segments = 16

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.95, 1.0, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	splash.mesh = cylinder
	splash.material_override = mat
	splash.global_position = Vector3(global_position.x, 0.04, global_position.z)
	get_parent().add_child(splash)

	var tween := splash.create_tween()
	tween.tween_property(splash, "scale", Vector3(2.4, 1.0, 2.4), 0.30)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.30)
	tween.tween_callback(splash.queue_free)
