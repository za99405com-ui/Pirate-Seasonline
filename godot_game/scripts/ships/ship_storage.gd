class_name ShipStorage
extends RefCounted

signal storage_changed(used: int, capacity: int)

var storage_capacity: int = 20
var used_storage: int = 0
var unlocked_storage_slots: int = 1
var visible_storage_level: int = 1

func configure_for_level(level: int, capacity: int) -> void:
	storage_capacity = capacity
	visible_storage_level = level
	unlocked_storage_slots = 1 + int(float(level) / 3.0)
	storage_changed.emit(used_storage, storage_capacity)

func add_cargo(amount: int) -> bool:
	if used_storage + amount <= storage_capacity:
		used_storage += amount
		storage_changed.emit(used_storage, storage_capacity)
		return true
	return false

func remove_cargo(amount: int) -> int:
	var actual_removed = min(used_storage, amount)
	used_storage -= actual_removed
	storage_changed.emit(used_storage, storage_capacity)
	return actual_removed

func can_fit(amount: int) -> bool:
	return used_storage + amount <= storage_capacity

func get_free_capacity() -> int:
	return max(0, storage_capacity - used_storage)
