class_name ShipMountSlot
extends Node3D

enum SlotType {
	CANNON,
	STORAGE,
	SAIL,
	UTILITY,
	COSMETIC
}

@export var slot_id: String = ""
@export var slot_type: SlotType = SlotType.UTILITY
@export var slot_title: String = "Mount Slot"

var is_unlocked: bool = false
var equipped_item_id: String = ""

func set_unlocked(unlocked: bool) -> void:
	is_unlocked = unlocked
	# Can toggle visibility of slotted items or mount gizmo
	for child in get_children():
		if child is Node3D and child.name != "SlotIndicator":
			child.visible = is_unlocked

func equip_item(item_id: String, item_scene: PackedScene = null) -> bool:
	if not is_unlocked:
		return false
	equipped_item_id = item_id
	if item_scene:
		# Clear previous items
		for child in get_children():
			if child.name != "SlotIndicator":
				child.queue_free()
		var instance = item_scene.instantiate()
		add_child(instance)
	return true
