extends SceneTree

func _initialize() -> void:
	call_deferred("_smoke_test")

func _smoke_test() -> void:
	var packed := load("res://scenes/player/player_ship.tscn") as PackedScene
	if not packed:
		push_error("The modular player ship scene did not load")
		quit(1)
		return

	var ship := packed.instantiate() as CharacterBody3D
	root.add_child(ship)
	await process_frame
	var rig := ship.get_node("AnchorRig") as AnchorRig

	if rig.is_set() or rig.is_deployed():
		push_error("Anchor must begin raised")
		quit(1)
		return

	ship.toggle_anchor()
	for i in range(240):
		rig.update_anchor(1.0 / 60.0)
	if not rig.is_set():
		push_error("Anchor failed to reach the seabed")
		quit(1)
		return

	var pivot: Vector3 = rig.get_pivot()
	ship.set_sail_level(2)
	ship.set_rudder_input(0.9)
	var start: Vector3 = ship.global_position
	for i in range(40):
		ship._physics_process(1.0 / 60.0)
	if not rig.get_pivot().is_equal_approx(pivot):
		push_error("The anchor pivot moved while ship rotated")
		quit(1)
		return
	if ship.global_position.distance_to(start) <= 0.001:
		push_error("The ship did not rotate around the seabed point")
		quit(1)
		return

	ship.toggle_anchor()
	for i in range(300):
		rig.update_anchor(1.0 / 60.0)
	if rig.is_deployed():
		push_error("The anchor failed to rise")
		quit(1)
		return

	ship.queue_free()
	await process_frame
	var world_scene := load("res://scenes/world/world.tscn") as PackedScene
	if not world_scene:
		push_error("Main gameplay scene failed to load")
		quit(1)
		return
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	if not world.get_node_or_null("PlayerShip") or not world.get_node_or_null("HUD"):
		push_error("World did not load the player ship and HUD")
		quit(1)
		return
	print("PASS: Level1 ship + world + HUD loaded; anchor dropped, orbited, and raised.")
	quit(0)
