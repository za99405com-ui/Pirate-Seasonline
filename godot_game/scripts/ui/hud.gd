extends CanvasLayer

@onready var top_bar: Panel = $TopBar
@onready var gold_label: Label = $TopBar/GoldContainer/GoldLabel
@onready var gold_title: Label = $TopBar/GoldContainer/GoldTitle
@onready var hp_container: HBoxContainer = $TopBar/HPContainer
@onready var hp_bar: ProgressBar = $TopBar/HPContainer/HPBar
@onready var hp_label: Label = $TopBar/HPContainer/HPLabel
@onready var speed_panel: Panel = $SpeedPanel
@onready var speed_label: Label = $SpeedPanel/SpeedLabel
@onready var fire_left_btn: Button = $Controls/RightControls/FireLeftButton
@onready var fire_right_btn: Button = $Controls/RightControls/FireRightButton
@onready var joystick: Control = $Controls/LeftControls/VirtualJoystick

@onready var ship_level_label: Label = $TopBar/ShipInfoContainer/ShipLevelLabel
@onready var cargo_label: Label = $TopBar/ShipInfoContainer/CargoLabel
@onready var upgrade_btn: Button = $TopBar/UpgradeButton
@onready var notification_label: Label = $NotificationBanner/Label
@onready var notification_banner: Panel = $NotificationBanner
@onready var controls_root: Control = $Controls

var player_ship: Node3D = null
var world_controller: Node = null
var aim_button: Button = null
var war_mode_panel: PanelContainer = null
var war_mode_label: Label = null
var combat_guide_panel: PanelContainer = null
var combat_guide_label: Label = null
var target_reticle: Label = null

func _ready() -> void:
	world_controller = get_parent()

	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.player_health_changed.connect(_on_player_health_changed)
	GameManager.ship_level_changed.connect(_on_ship_level_changed)
	GameManager.ship_storage_changed.connect(_on_ship_storage_changed)

	_apply_minimal_hud_layout()
	_create_aim_button()
	_create_war_mode_badge()
	_create_combat_guide()
	_create_target_reticle()

	_on_gold_changed(GameManager.gold)
	var current_info := ShipProgressionData.get_level_info(GameManager.current_ship_level)
	_on_ship_level_changed(GameManager.current_ship_level, current_info.title)

	if fire_left_btn:
		fire_left_btn.pressed.connect(_on_fire_pressed)
	if fire_right_btn:
		fire_right_btn.button_down.connect(_on_brace_down)
		fire_right_btn.button_up.connect(_on_brace_up)
	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)

	if notification_banner:
		notification_banner.modulate.a = 0.0

func _apply_minimal_hud_layout() -> void:
	if hp_container:
		hp_container.visible = false
	if cargo_label:
		cargo_label.visible = false
	if gold_title:
		gold_title.visible = false

	if top_bar:
		top_bar.anchor_right = 0.0
		top_bar.offset_left = 16.0
		top_bar.offset_top = 12.0
		top_bar.offset_right = 470.0
		top_bar.offset_bottom = 64.0

	if speed_panel:
		speed_panel.offset_left = -56.0
		speed_panel.offset_top = -54.0
		speed_panel.offset_right = 56.0
		speed_panel.offset_bottom = -18.0

	if fire_left_btn:
		fire_left_btn.custom_minimum_size = Vector2(92.0, 78.0)
	if fire_right_btn:
		fire_right_btn.custom_minimum_size = Vector2(92.0, 78.0)

	var right_controls := $Controls/RightControls as HBoxContainer
	if right_controls:
		right_controls.offset_left = -224.0
		right_controls.offset_top = -112.0
		right_controls.offset_right = -22.0
		right_controls.offset_bottom = -24.0
		right_controls.add_theme_constant_override("separation", 10)

func _create_aim_button() -> void:
	if not controls_root:
		return

	aim_button = _make_combat_button("AIM", Vector2(124.0, 56.0))
	aim_button.name = "AimButton"
	aim_button.anchor_left = 1.0
	aim_button.anchor_top = 1.0
	aim_button.anchor_right = 1.0
	aim_button.anchor_bottom = 1.0
	aim_button.offset_left = -246.0
	aim_button.offset_top = -184.0
	aim_button.offset_right = -122.0
	aim_button.offset_bottom = -128.0
	aim_button.pressed.connect(_on_aim_pressed)
	controls_root.add_child(aim_button)

func _make_combat_button(label_text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 14)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.07, 0.12, 0.90)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.82, 0.61, 0.22, 0.74)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.22, 0.13, 0.04, 0.96)
	pressed.border_color = Color(1.0, 0.82, 0.30, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84, 1.0))
	return button

func _create_war_mode_badge() -> void:
	war_mode_panel = PanelContainer.new()
	war_mode_panel.name = "WarMode"
	war_mode_panel.anchor_left = 0.5
	war_mode_panel.anchor_right = 0.5
	war_mode_panel.offset_left = -78.0
	war_mode_panel.offset_top = 12.0
	war_mode_panel.offset_right = 78.0
	war_mode_panel.offset_bottom = 50.0
	war_mode_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.82, 0.24, 0.12, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	war_mode_panel.add_theme_stylebox_override("panel", style)

	war_mode_label = Label.new()
	war_mode_label.text = "WAR • ATTACK"
	war_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	war_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	war_mode_label.add_theme_font_size_override("font_size", 15)
	war_mode_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.72, 1.0))
	war_mode_panel.add_child(war_mode_label)
	add_child(war_mode_panel)

func _create_combat_guide() -> void:
	combat_guide_panel = PanelContainer.new()
	combat_guide_panel.name = "CombatGuide"
	combat_guide_panel.anchor_left = 0.5
	combat_guide_panel.anchor_top = 1.0
	combat_guide_panel.anchor_right = 0.5
	combat_guide_panel.anchor_bottom = 1.0
	combat_guide_panel.offset_left = -245.0
	combat_guide_panel.offset_top = -132.0
	combat_guide_panel.offset_right = 245.0
	combat_guide_panel.offset_bottom = -88.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.045, 0.07, 0.84)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.76, 0.62, 0.25, 0.48)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	combat_guide_panel.add_theme_stylebox_override("panel", style)

	combat_guide_label = Label.new()
	combat_guide_label.text = "AIM  →  TURN CAMERA  →  FIRE"
	combat_guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_guide_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_guide_label.add_theme_font_size_override("font_size", 14)
	combat_guide_label.add_theme_color_override("font_color", Color(0.94, 0.91, 0.76, 1.0))
	combat_guide_panel.add_child(combat_guide_label)
	add_child(combat_guide_panel)

func _create_target_reticle() -> void:
	target_reticle = Label.new()
	target_reticle.name = "TargetReticle"
	target_reticle.text = "+"
	target_reticle.custom_minimum_size = Vector2(54.0, 54.0)
	target_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_reticle.add_theme_font_size_override("font_size", 36)
	target_reticle.add_theme_color_override("font_color", Color(1.0, 0.76, 0.22, 1.0))
	target_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_reticle.visible = false
	add_child(target_reticle)

func set_player(player: Node3D) -> void:
	player_ship = player
	if joystick and player_ship and player_ship.has_method("set_joystick_input"):
		joystick.joystick_moved.connect(player_ship.set_joystick_input)
	if player_ship and "storage" in player_ship and player_ship.storage:
		_on_ship_storage_changed(player_ship.storage.used_storage, player_ship.storage.storage_capacity)

func _process(_delta: float) -> void:
	if not player_ship or not is_instance_valid(player_ship):
		return

	if speed_label:
		var speed_value: float = absf(float(player_ship.current_forward_speed)) if "current_forward_speed" in player_ship else 0.0
		speed_label.text = "%.1f kn" % speed_value

	var cannon_count: int = 1
	if player_ship.has_method("get_cannons_per_side"):
		cannon_count = int(player_ship.call("get_cannons_per_side"))

	_update_fire_button(cannon_count)
	_update_brace_button()
	_update_combat_hud()
	_update_target_reticle()
	_update_combat_guide()
	_update_upgrade_button()

func _update_fire_button(cannon_count: int) -> void:
	if not fire_left_btn:
		return

	var aiming: bool = false
	if world_controller and world_controller.has_method("is_combat_aiming"):
		aiming = bool(world_controller.call("is_combat_aiming"))

	if not aiming:
		fire_left_btn.disabled = true
		fire_left_btn.text = "FIRE\nAIM FIRST"
		return

	var mode: String = "NONE"
	if player_ship.has_method("get_weapon_mode"):
		mode = String(player_ship.call("get_weapon_mode"))

	var cooldown: float = 0.0
	if player_ship.has_method("get_active_reload"):
		cooldown = float(player_ship.call("get_active_reload"))

	var title: String = "FIRE"
	if mode == "PORT":
		title = "PORT ×%d" % cannon_count
	elif mode == "STARBOARD":
		title = "STARBOARD ×%d" % cannon_count
	elif mode == "CHASE":
		title = "CHASE"
	else:
		fire_left_btn.disabled = true
		fire_left_btn.text = "TURN CAMERA\nTO AIM"
		return

	if cooldown > 0.0:
		fire_left_btn.disabled = true
		fire_left_btn.text = "%s\nRELOAD %.1f" % [title, cooldown]
	else:
		fire_left_btn.disabled = false
		fire_left_btn.text = "%s\nFIRE" % title

func _update_brace_button() -> void:
	if not fire_right_btn:
		return
	var bracing_value: Variant = player_ship.get("is_bracing")
	var bracing: bool = bool(bracing_value) if bracing_value is bool else false
	fire_right_btn.text = "BRACING" if bracing else "BRACE"

func _update_combat_hud() -> void:
	if not world_controller:
		return

	var mode: String = ""
	if world_controller.has_method("get_war_mode"):
		mode = String(world_controller.call("get_war_mode"))

	if war_mode_panel and war_mode_label:
		war_mode_panel.visible = not mode.is_empty()
		if mode == "ATTACK":
			war_mode_label.text = "WAR • ATTACK"
		elif mode == "DEFENSE":
			war_mode_label.text = "WAR • DEFENSE"

	if aim_button and world_controller.has_method("is_combat_aiming"):
		var aiming: bool = bool(world_controller.call("is_combat_aiming"))
		aim_button.text = "AIM ON" if aiming else "AIM"

		if aiming and war_mode_label and world_controller.has_method("get_weapon_mode"):
			var weapon_mode: String = String(world_controller.call("get_weapon_mode"))
			if weapon_mode == "PORT":
				war_mode_label.text = "AIM • PORT BROADSIDE"
			elif weapon_mode == "STARBOARD":
				war_mode_label.text = "AIM • STARBOARD BROADSIDE"
			elif weapon_mode == "CHASE":
				war_mode_label.text = "AIM • CHASE SHOT"
			else:
				war_mode_label.text = "AIM • TURN TO BROADSIDE"

func _update_combat_guide() -> void:
	if not combat_guide_panel or not combat_guide_label or not world_controller:
		return

	var aiming: bool = false
	if world_controller.has_method("is_combat_aiming"):
		aiming = bool(world_controller.call("is_combat_aiming"))

	if not aiming:
		combat_guide_panel.visible = true
		combat_guide_label.text = "1  AIM   →   2  TURN CAMERA   →   3  FIRE"
		combat_guide_label.add_theme_color_override("font_color", Color(0.94, 0.91, 0.76, 1.0))
		return

	var mode: String = "NONE"
	if player_ship and player_ship.has_method("get_weapon_mode"):
		mode = String(player_ship.call("get_weapon_mode"))

	if mode == "NONE":
		combat_guide_label.text = "TURN CAMERA TO A SIDE TO LINE UP THE CANNONS"
		combat_guide_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34, 1.0))
		return

	var reload_value: float = 0.0
	if player_ship and player_ship.has_method("get_active_reload"):
		reload_value = float(player_ship.call("get_active_reload"))

	var has_target: bool = false
	var target_distance: float = 0.0
	if player_ship and player_ship.has_method("has_aim_target"):
		has_target = bool(player_ship.call("has_aim_target"))
	if has_target and player_ship.has_method("get_aim_target_distance"):
		target_distance = float(player_ship.call("get_aim_target_distance"))

	var weapon_name: String = "PORT BROADSIDE" if mode == "PORT" else ("STARBOARD BROADSIDE" if mode == "STARBOARD" else "CHASE SHOT")
	if reload_value > 0.0:
		combat_guide_label.text = "%s   •   RELOADING %.1fs" % [weapon_name, reload_value]
		combat_guide_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86, 1.0))
	elif has_target:
		combat_guide_label.text = "%s   •   TARGET %.0fm   •   FIRE" % [weapon_name, target_distance]
		combat_guide_label.add_theme_color_override("font_color", Color(0.42, 1.0, 0.52, 1.0))
	else:
		combat_guide_label.text = "%s   •   MOVE THE MARKER OVER THE ENEMY   •   FIRE" % weapon_name
		combat_guide_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34, 1.0))

func _update_target_reticle() -> void:
	if not target_reticle or not player_ship or not world_controller:
		return

	var aiming: bool = false
	if world_controller.has_method("is_combat_aiming"):
		aiming = bool(world_controller.call("is_combat_aiming"))

	if not aiming or not player_ship.has_method("get_predicted_impact_point"):
		target_reticle.visible = false
		return

	var camera := get_viewport().get_camera_3d()
	if not camera:
		target_reticle.visible = false
		return

	var impact_value: Variant = player_ship.call("get_predicted_impact_point")
	if not impact_value is Vector3:
		target_reticle.visible = false
		return

	var impact_point := impact_value as Vector3
	if camera.is_position_behind(impact_point):
		target_reticle.visible = false
		return

	var screen_pos: Vector2 = camera.unproject_position(impact_point)
	target_reticle.position = screen_pos - target_reticle.custom_minimum_size * 0.5
	target_reticle.visible = true

	var has_target: bool = false
	if player_ship.has_method("has_aim_target"):
		has_target = bool(player_ship.call("has_aim_target"))

	var reload_value: float = 0.0
	if player_ship.has_method("get_active_reload"):
		reload_value = float(player_ship.call("get_active_reload"))

	if reload_value > 0.0:
		target_reticle.add_theme_color_override("font_color", Color(0.58, 0.62, 0.66, 0.85))
		target_reticle.text = "+"
	elif has_target:
		target_reticle.add_theme_color_override("font_color", Color(0.24, 1.0, 0.38, 1.0))
		target_reticle.text = "+"
	else:
		target_reticle.add_theme_color_override("font_color", Color(1.0, 0.76, 0.22, 1.0))
		target_reticle.text = "+"

func _update_upgrade_button() -> void:
	if not upgrade_btn:
		return
	if GameManager.current_ship_level >= 15:
		upgrade_btn.text = "MAX 15"
		upgrade_btn.disabled = true
	else:
		var next_cost := GameManager.get_next_upgrade_cost()
		upgrade_btn.text = "UPGRADE\n%d G" % next_cost
		upgrade_btn.disabled = false

func _on_upgrade_pressed() -> void:
	if GameManager.current_ship_level >= 15:
		return

	if GameManager.can_upgrade_ship():
		GameManager.upgrade_ship()
	else:
		GameManager.set_ship_level(GameManager.current_ship_level + 1)

func _on_gold_changed(new_amount: int) -> void:
	if gold_label:
		gold_label.text = "G %d" % new_amount
	_update_upgrade_button()

func _on_ship_level_changed(new_level: int, title: String) -> void:
	if ship_level_label:
		ship_level_label.text = "Lv.%d • %s" % [new_level, title]
	_update_upgrade_button()
	_show_notification("SHIP UPGRADED • LV.%d" % new_level)

func _on_ship_storage_changed(_used: int, _capacity: int) -> void:
	pass

func _on_player_health_changed(current: float, maximum: float) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
	if hp_label:
		hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _show_notification(text: String) -> void:
	if not notification_banner or not notification_label:
		return
	notification_label.text = text
	var tw := create_tween()
	tw.tween_property(notification_banner, "modulate:a", 1.0, 0.20)
	tw.tween_interval(1.4)
	tw.tween_property(notification_banner, "modulate:a", 0.0, 0.35)

func _on_fire_pressed() -> void:
	if player_ship and is_instance_valid(player_ship):
		if player_ship.has_method("fire_active_weapon"):
			player_ship.call("fire_active_weapon")

func _on_brace_down() -> void:
	if player_ship and is_instance_valid(player_ship) and player_ship.has_method("set_bracing"):
		player_ship.call("set_bracing", true)

func _on_brace_up() -> void:
	if player_ship and is_instance_valid(player_ship) and player_ship.has_method("set_bracing"):
		player_ship.call("set_bracing", false)

func _on_aim_pressed() -> void:
	if world_controller and world_controller.has_method("toggle_combat_aim"):
		world_controller.call("toggle_combat_aim")
