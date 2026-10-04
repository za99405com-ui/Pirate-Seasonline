extends Node

signal gold_changed(new_amount: int)
signal player_health_changed(current: float, maximum: float)
signal enemy_destroyed(enemy_name: String)

var gold: int = 0
var player_ship: Node3D = null

func _ready() -> void:
	print("Pirate Seas Online - GameManager Initialized")

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func register_player(ship: Node3D) -> void:
	player_ship = ship

func update_player_health(current: float, maximum: float) -> void:
	player_health_changed.emit(current, maximum)
