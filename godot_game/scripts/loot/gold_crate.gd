extends Area3D

@export var gold_value: int = 25

var wave_time: float = 0.0
var base_y: float = 0.0
var is_collected: bool = false

@onready var visuals: Node3D = $Visuals

func _ready() -> void:
	base_y = position.y
	wave_time = randf() * TAU
	body_entered.connect(_on_body_entered)

func setup_value(amount: int) -> void:
	gold_value = amount

func _physics_process(delta: float) -> void:
	if is_collected:
		return
	wave_time += delta * 3.0
	position.y = base_y + sin(wave_time) * 0.12
	rotation.y += delta * 0.9

func _on_body_entered(body: Node) -> void:
	if is_collected:
		return
	if body.is_in_group("player"):
		is_collected = true
		GameManager.add_gold(gold_value)
		
		# Collect popup effect
		var tw = create_tween()
		tw.tween_property(visuals, "position:y", visuals.position.y + 1.2, 0.25)
		tw.parallel().tween_property(visuals, "scale", Vector3(1.4, 1.4, 1.4), 0.25)
		tw.parallel().tween_property(visuals, "scale", Vector3.ZERO, 0.25).set_delay(0.1)
		tw.tween_callback(queue_free)
