extends Node

signal gold_changed(new_amount: int)
signal player_health_changed(current: float, maximum: float)
signal enemy_destroyed(enemy_name: String)
signal ship_level_changed(new_level: int, title: String)
signal ship_storage_changed(used: int, capacity: int)

var gold: int = 150
var player_ship: Node3D = null
var current_ship_level: int = 1

func _ready() -> void:
	print("Pirate Seas Online - GameManager Initialized")

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func register_player(ship: Node3D) -> void:
	player_ship = ship

func update_player_health(current: float, maximum: float) -> void:
	player_health_changed.emit(current, maximum)

func update_storage(used: int, capacity: int) -> void:
	ship_storage_changed.emit(used, capacity)

func can_upgrade_ship() -> bool:
	if current_ship_level >= 15:
		return false
	var next_info = ShipProgressionData.get_level_info(current_ship_level + 1)
	return gold >= next_info.upgrade_gold_cost

func get_next_upgrade_cost() -> int:
	if current_ship_level >= 15:
		return 0
	var next_info = ShipProgressionData.get_level_info(current_ship_level + 1)
	return next_info.upgrade_gold_cost

func upgrade_ship() -> bool:
	if current_ship_level >= 15:
		return false
	var next_info = ShipProgressionData.get_level_info(current_ship_level + 1)
	if gold >= next_info.upgrade_gold_cost:
		gold -= next_info.upgrade_gold_cost
		gold_changed.emit(gold)
		set_ship_level(current_ship_level + 1)
		return true
	return false

func set_ship_level(new_level: int) -> void:
	current_ship_level = clamp(new_level, 1, 15)
	var info = ShipProgressionData.get_level_info(current_ship_level)
	ship_level_changed.emit(current_ship_level, info.title)
	if player_ship and is_instance_valid(player_ship) and player_ship.has_method("apply_ship_level"):
		player_ship.apply_ship_level(current_ship_level)
