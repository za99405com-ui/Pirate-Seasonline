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
var target_button: Button = null
var zoom_in_button: Button = null
var zoom_out_button: Button = null
var war_mode_panel: PanelContainer = null
var war_mode_label: Label = null

func _ready() -> void:
	world_controller = get_parent()

	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.player_health_changed.connect(_on_player_health_changed)
	GameManager.ship_level_changed.connect(_on_ship_level_changed)
	GameManager.ship_storage_changed.connect(_on_ship_storage_changed)

	_apply_minimal_hud_layout()
	_create_tactical_controls()
	_create_war_mode_badge()

	_on_gold_changed(GameManager.gold)
	var current_info := ShipProgressionData.get_level_info(GameManager.current_ship_level)
	_on_ship_level_changed(GameManager.current_ship_level, current_info.title)

	if fire_left_btn:
		fire_left_btn.pressed.connect(_on_fire_left_pressed)
	if fire_right_btn:
		fire_right_btn.pressed.connect(_on_fire_right_pressed)
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
		right_controls.offset_left = -218.0
		right_controls.offset_top = -112.0
		right_controls.offset_right = -22.0
		right_controls.offset_bottom = -24.0
		right_controls.add_theme_constant_override("separation", 10)

func _create_tactical_controls() -> void:
	if not controls_root:
		return

	var tactical := HBoxContainer.new()
	tactical.name = "TacticalControls"
	tactical.anchor_left = 1.0
	tactical.anchor_top = 1.0
	tactical.anchor_right = 1.0
	tactical.anchor_bottom = 1.0
	tactical.offset_left = -224.0
	tactical.offset_top = -178.0
	tactical.offset_right = -22.0
	tactical.offset_bottom = -126.0
	tactical.add_theme_constant_override("separation", 8)
	controls_root.add_child(tactical)

	zoom_out_button = _make_tactical_button("−", Vector2(52.0, 48.0))
	zoom_in_button = _make_tactical_button("+", Vector2(52.0, 48.0))
	target_button = _make_tactical_button("LOCK", Vector2(82.0, 48.0))

	tactical.add_child(zoom_out_button)
	tactical.add_child(zoom_in_button)
	tactical.add_child(target_button)

	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	target_button.pressed.connect(_on_target_pressed)

func _make_tactical_button(label_text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 14)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.07, 0.12, 0.88)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.82, 0.61, 0.22, 0.70)
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

	if player_ship.port_cooldown > 0.0:
		fire_left_btn.disabled = true
		fire_left_btn.text = "PORT ×%d\n%.1fs" % [cannon_count, player_ship.port_cooldown]
	else:
		fire_left_btn.disabled = false
		fire_left_btn.text = "PORT ×%d\nFIRE" % cannon_count

	if player_ship.starboard_cooldown > 0.0:
		fire_right_btn.disabled = true
		fire_right_btn.text = "STARBOARD ×%d\n%.1fs" % [cannon_count, player_ship.starboard_cooldown]
	else:
		fire_right_btn.disabled = false
		fire_right_btn.text = "STARBOARD ×%d\nFIRE" % cannon_count

	_update_combat_hud()
	_update_upgrade_button()

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

	if target_button and world_controller.has_method("get_combat_target"):
		var target: Variant = world_controller.call("get_combat_target")
		target_button.text = "LOCKED" if target is Node3D and is_instance_valid(target) else "LOCK"

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

func _on_fire_left_pressed() -> void:
	if player_ship and is_instance_valid(player_ship):
		player_ship.fire_left()

func _on_fire_right_pressed() -> void:
	if player_ship and is_instance_valid(player_ship):
		player_ship.fire_right()

func _on_zoom_in_pressed() -> void:
	if world_controller and world_controller.has_method("adjust_camera_zoom"):
		world_controller.call("adjust_camera_zoom", -0.10)

func _on_zoom_out_pressed() -> void:
	if world_controller and world_controller.has_method("adjust_camera_zoom"):
		world_controller.call("adjust_camera_zoom", 0.10)

func _on_target_pressed() -> void:
	if world_controller and world_controller.has_method("toggle_combat_target"):
		world_controller.call("toggle_combat_target")
