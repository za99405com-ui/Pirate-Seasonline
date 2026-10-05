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
@onready var controls_root: Control = $Controls
@onready var ship_level_label: Label = $TopBar/ShipInfoContainer/ShipLevelLabel
@onready var cargo_label: Label = $TopBar/ShipInfoContainer/CargoLabel
@onready var upgrade_btn: Button = $TopBar/UpgradeButton
@onready var notification_label: Label = $NotificationBanner/Label
@onready var notification_banner: Panel = $NotificationBanner

var player_ship: Node3D = null
var world_controller: Node = null
var combat_panel: PanelContainer = null
var combat_label: Label = null
var dpad_root: Control = null
var dpad_up: Button = null
var dpad_down: Button = null
var dpad_left: Button = null
var dpad_right: Button = null
var dpad_up_held: bool = false
var dpad_down_held: bool = false
var dpad_left_held: bool = false
var dpad_right_held: bool = false

func _ready() -> void:
	world_controller = get_parent()

	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.player_health_changed.connect(_on_player_health_changed)
	GameManager.ship_level_changed.connect(_on_ship_level_changed)
	GameManager.ship_storage_changed.connect(_on_ship_storage_changed)

	_apply_clean_layout()
	_create_dpad()
	_create_combat_indicator()
	if not get_viewport().size_changed.is_connected(_layout_dpad):
		get_viewport().size_changed.connect(_layout_dpad)

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
	if joystick:
		joystick.visible = false
		joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func _create_dpad() -> void:
	if not controls_root:
		return

	dpad_root = Control.new()
	dpad_root.name = "DPad"
	dpad_root.anchor_left = 0.0
	dpad_root.anchor_top = 1.0
	dpad_root.anchor_right = 0.0
	dpad_root.anchor_bottom = 1.0
	dpad_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	controls_root.add_child(dpad_root)

	dpad_up = _make_dpad_button("▲")
	dpad_down = _make_dpad_button("▼")
	dpad_left = _make_dpad_button("◀")
	dpad_right = _make_dpad_button("▶")

	for button in [dpad_up, dpad_down, dpad_left, dpad_right]:
		dpad_root.add_child(button)

	dpad_up.button_down.connect(_set_dpad_up.bind(true))
	dpad_up.button_up.connect(_set_dpad_up.bind(false))
	dpad_down.button_down.connect(_set_dpad_down.bind(true))
	dpad_down.button_up.connect(_set_dpad_down.bind(false))
	dpad_left.button_down.connect(_set_dpad_left.bind(true))
	dpad_left.button_up.connect(_set_dpad_left.bind(false))
	dpad_right.button_down.connect(_set_dpad_right.bind(true))
	dpad_right.button_up.connect(_set_dpad_right.bind(false))

	_layout_dpad()

func _make_dpad_button(symbol: String) -> Button:
	var button := Button.new()
	button.text = symbol
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 30)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.07, 0.12, 0.78)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.86, 0.68, 0.24, 0.82)
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.24, 0.15, 0.045, 0.96)
	pressed.border_color = Color(1.0, 0.86, 0.34, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60, 1.0))
	return button

func _layout_dpad() -> void:
	if not dpad_root:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var dpad_size: float = clampf(viewport_size.y * 0.36, 230.0, 300.0)
	var button_size: float = dpad_size * 0.36
	var center: float = dpad_size * 0.5
	var half_button: float = button_size * 0.5
	var edge: float = 18.0

	dpad_root.offset_left = edge
	dpad_root.offset_top = -dpad_size - edge
	dpad_root.offset_right = edge + dpad_size
	dpad_root.offset_bottom = -edge

	_place_dpad_button(dpad_up, center - half_button, 0.0, button_size)
	_place_dpad_button(dpad_down, center - half_button, dpad_size - button_size, button_size)
	_place_dpad_button(dpad_left, 0.0, center - half_button, button_size)
	_place_dpad_button(dpad_right, dpad_size - button_size, center - half_button, button_size)

func _place_dpad_button(button: Button, x: float, y: float, button_size: float) -> void:
	if not button:
		return
	button.position = Vector2(x, y)
	button.size = Vector2(button_size, button_size)
	button.custom_minimum_size = Vector2(button_size, button_size)

func _set_dpad_up(active: bool) -> void:
	dpad_up_held = active
	_send_dpad_vector()

func _set_dpad_down(active: bool) -> void:
	dpad_down_held = active
	_send_dpad_vector()

func _set_dpad_left(active: bool) -> void:
	dpad_left_held = active
	_send_dpad_vector()

func _set_dpad_right(active: bool) -> void:
	dpad_right_held = active
	_send_dpad_vector()

func _send_dpad_vector() -> void:
	if not player_ship or not is_instance_valid(player_ship) or not player_ship.has_method("set_joystick_input"):
		return

	var x: float = float(int(dpad_right_held) - int(dpad_left_held))
	var y: float = float(int(dpad_down_held) - int(dpad_up_held))
	var input_vector := Vector2(x, y)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	player_ship.call("set_joystick_input", input_vector)

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

