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

var player_ship: Node3D = null
var world_controller: Node = null
var combat_panel: PanelContainer = null
var combat_label: Label = null

func _ready() -> void:
	world_controller = get_parent()

	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.player_health_changed.connect(_on_player_health_changed)
	GameManager.ship_level_changed.connect(_on_ship_level_changed)
	GameManager.ship_storage_changed.connect(_on_ship_storage_changed)

	_apply_clean_layout()
	_create_combat_indicator()

	_on_gold_changed(GameManager.gold)
	var current_info := ShipProgressionData.get_level_info(GameManager.current_ship_level)
	_on_ship_level_changed(GameManager.current_ship_level, current_info.title)

	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)

	if notification_banner:
		notification_banner.modulate.a = 0.0

func _apply_clean_layout() -> void:
	if hp_container:
		hp_container.visible = false
	if cargo_label:
		cargo_label.visible = false
	if gold_title:
		gold_title.visible = false

	# No aiming / firing UI in this clean foundation build.
	# We are validating sailing, automatic combat detection and combat camera first.
	if fire_left_btn:
		fire_left_btn.visible = false
	if fire_right_btn:
		fire_right_btn.visible = false

	var right_controls := $Controls/RightControls as Control
	if right_controls:
		right_controls.visible = false

	if top_bar:
		top_bar.anchor_right = 0.0
		top_bar.offset_left = 16.0
		top_bar.offset_top = 12.0
		top_bar.offset_right = 470.0
		top_bar.offset_bottom = 64.0

	if speed_panel:
		speed_panel.offset_left = -64.0
		speed_panel.offset_top = -58.0
		speed_panel.offset_right = 64.0
		speed_panel.offset_bottom = -18.0

func _create_combat_indicator() -> void:
	combat_panel = PanelContainer.new()
	combat_panel.name = "CombatState"
	combat_panel.anchor_left = 0.5
	combat_panel.anchor_right = 0.5
	combat_panel.offset_left = -92.0
	combat_panel.offset_top = 14.0
	combat_panel.offset_right = 92.0
	combat_panel.offset_bottom = 52.0
	combat_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.035, 0.025, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.95, 0.36, 0.14, 0.90)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	combat_panel.add_theme_stylebox_override("panel", style)

	combat_label = Label.new()
	combat_label.text = "COMBAT"
	combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_label.add_theme_font_size_override("font_size", 15)
	combat_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.72, 1.0))
	combat_panel.add_child(combat_label)
	add_child(combat_panel)

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

	_update_combat_indicator()
	_update_upgrade_button()

func _update_combat_indicator() -> void:
	if not combat_panel or not combat_label or not world_controller:
		return

	var active: bool = false
	if world_controller.has_method("is_in_combat"):
		active = bool(world_controller.call("is_in_combat"))

	combat_panel.visible = active
	if not active:
		return

	var distance: float = 0.0
	if world_controller.has_method("get_combat_distance"):
		distance = float(world_controller.call("get_combat_distance"))

	combat_label.text = "COMBAT  •  %.0fm" % distance

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
	var tween := create_tween()
	tween.tween_property(notification_banner, "modulate:a", 1.0, 0.20)
	tween.tween_interval(1.2)
	tween.tween_property(notification_banner, "modulate:a", 0.0, 0.30)
