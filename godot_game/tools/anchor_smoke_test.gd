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

	ship.set_sail_level(2)
	for i in range(90):
		ship._physics_process(1.0 / 60.0)
	var moving_before_drop: Vector3 = ship.global_position
	ship.toggle_anchor()
	for i in range(20):
		ship._physics_process(1.0 / 60.0)
	if ship.global_position.distance_to(moving_before_drop) < 0.05:
		push_error("Anchor dropped but ship movement froze immediately.")
		quit(1)
		return
	ship.toggle_anchor()
	for i in range(200):
		ship.anchor_rig.update_anchor(1.0 / 60.0)

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
	var world_hud := world.get_node("HUD") as CanvasLayer
	var anchor_control := world_hud.get_node_or_null("Controls/SailingActions/AnchorControl") as Button
	if not anchor_control or anchor_control.text != "" or not anchor_control.icon:
		push_error("Anchor button must show icon only, without any text")
		quit(1)
		return
	var anchor_style := anchor_control.get_theme_stylebox("normal") as StyleBoxFlat
	if not anchor_style or anchor_style.bg_color.a > 0.01:
		push_error("Anchor button background must be fully transparent")
		quit(1)
		return
	var raised_icon: Texture2D = anchor_control.icon
	(world.get_node("PlayerShip") as CharacterBody3D).toggle_anchor()
	world_hud.call("_update_sailing_buttons")
	if anchor_control.text != "" or anchor_control.icon == raised_icon:
		push_error("Anchor icon must change when lowering, still with no text")
		quit(1)
		return
	for asset_path in [
		"res://assets/models/Pirate_Boat_A_Level1_Mobile_2048.glb",
		"res://assets/models/Anchor_Mobile_2048.glb",
		"res://assets/models/Anchor_Holder_Mobile_2048.glb"
	]:
		if not ResourceLoader.exists(asset_path):
			push_error("Missing supplied GLB asset: " + asset_path)
			quit(1)
			return
	var base := world.get_node("PlayerShip/Visuals/ModularShipVisuals/BaseHull")
	if base.get_child_count() != 1:
		push_error("The real hull was not instanced: a placeholder is still in use.")
		quit(1)
		return
	var live_rig := world.get_node("PlayerShip/AnchorRig") as AnchorRig
	var holder_node := live_rig.get_node("StarboardAnchorHolder")
	var anchor_node := live_rig.get_node("WorldAnchor")
	if holder_node.get_child_count() != 1 or anchor_node.get_child_count() != 1:
		push_error("Original anchor / holder GLB not instanced; fallback was used.")
		quit(1)
		return
	if world.get_clock_text() != "09:00":
		push_error("Game must start at 09:00")
		quit(1)
		return
	world._process(1.0)
	if world.get_clock_text() != "09:01":
		push_error("One real second must advance clock one game minute.")
		quit(1)
		return
	var sea_material := (world.get_node("OceanPlane") as MeshInstance3D).material_override as ShaderMaterial
	if not sea_material or not sea_material.shader:
		push_error("Animated ocean material not active.")
		quit(1)
		return
	print("PASS: Real GLBs, anchor drift/orbit, icon UI, water waves and 24-minute game day.")
	quit(0)
