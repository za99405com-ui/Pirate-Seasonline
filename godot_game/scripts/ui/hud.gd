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
var dpad_touch_vectors: Dictionary = {}
var dpad_touch_modes: Dictionary = {}
var mouse_dpad_active: bool = false
var mouse_dpad_mode: String = ""
var mouse_dpad_vector: Vector2 = Vector2.ZERO

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

	# Only four visible buttons. Sliding one finger between them blends the movement.
	dpad_up = _make_dpad_button("▲")
	dpad_down = _make_dpad_button("▼")
	dpad_left = _make_dpad_button("◀")
	dpad_right = _make_dpad_button("▶")

	for button in [dpad_up, dpad_down, dpad_left, dpad_right]:
		dpad_root.add_child(button)
		button.toggle_mode = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_layout_dpad()

func _make_dpad_button(symbol: String) -> Button:
	var button := Button.new()
	button.text = symbol
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 32)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.07, 0.12, 0.78)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.86, 0.68, 0.24, 0.82)
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_left = 20
	normal.corner_radius_bottom_right = 20

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
	var dpad_size: float = clampf(viewport_size.y * 0.44, 270.0, 350.0)
	var button_size: float = dpad_size * 0.26
	var center: float = dpad_size * 0.5
	var half_button: float = button_size * 0.5
	var far: float = dpad_size - button_size
	var edge: float = 16.0

	dpad_root.offset_left = edge
	dpad_root.offset_top = -dpad_size - edge
	dpad_root.offset_right = edge + dpad_size
	dpad_root.offset_bottom = -edge

	_place_dpad_button(dpad_up, center - half_button, 0.0, button_size)
	_place_dpad_button(dpad_down, center - half_button, far, button_size)
	_place_dpad_button(dpad_left, 0.0, center - half_button, button_size)
	_place_dpad_button(dpad_right, far, center - half_button, button_size)

func _place_dpad_button(button: Button, x: float, y: float, button_size: float) -> void:
	if not button:
		return
	button.position = Vector2(x, y)
	button.size = Vector2(button_size, button_size)
	button.custom_minimum_size = Vector2(button_size, button_size)

func _input(event: InputEvent) -> void:
	# Start on one of the four arrows. If the finger starts on forward/back,
	# sliding sideways keeps full throttle and adds rudder instead of weakening speed.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var mode := _dpad_start_mode(touch.position)
			if not mode.is_empty():
				dpad_touch_modes[touch.index] = mode
				dpad_touch_vectors[touch.index] = _dpad_vector_for_drag(mode, touch.position)
				get_viewport().set_input_as_handled()
		else:
			if dpad_touch_modes.has(touch.index):
				dpad_touch_modes.erase(touch.index)
				dpad_touch_vectors.erase(touch.index)
				get_viewport().set_input_as_handled()
		_refresh_dpad_input()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if dpad_touch_modes.has(drag.index):
			var mode := String(dpad_touch_modes[drag.index])
			dpad_touch_vectors[drag.index] = _dpad_vector_for_drag(mode, drag.position)
			get_viewport().set_input_as_handled()
			_refresh_dpad_input()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				mouse_dpad_mode = _dpad_start_mode(mouse.position)
				mouse_dpad_active = not mouse_dpad_mode.is_empty()
				if mouse_dpad_active:
					mouse_dpad_vector = _dpad_vector_for_drag(mouse_dpad_mode, mouse.position)
			else:
				mouse_dpad_active = false
				mouse_dpad_mode = ""
				mouse_dpad_vector = Vector2.ZERO
			_refresh_dpad_input()
	elif event is InputEventMouseMotion and mouse_dpad_active:
		var motion := event as InputEventMouseMotion
		mouse_dpad_vector = _dpad_vector_for_drag(mouse_dpad_mode, motion.position)
		_refresh_dpad_input()

func _dpad_start_mode(screen_position: Vector2) -> String:
	if dpad_up and dpad_up.get_global_rect().has_point(screen_position):
		return "up"
	if dpad_down and dpad_down.get_global_rect().has_point(screen_position):
		return "down"
	if dpad_left and dpad_left.get_global_rect().has_point(screen_position):
		return "left"
	if dpad_right and dpad_right.get_global_rect().has_point(screen_position):
		return "right"
	return ""

func _dpad_vector_for_drag(mode: String, screen_position: Vector2) -> Vector2:
	if not dpad_root:
		return Vector2.ZERO

	var rect: Rect2 = dpad_root.get_global_rect()
	var center: Vector2 = rect.position + rect.size * 0.5
	var horizontal_range: float = maxf(rect.size.x * 0.44, 1.0)
	var steer: float = clampf((screen_position.x - center.x) / horizontal_range, -1.0, 1.0)

	match mode:
		"up":
			return Vector2(steer * 0.68, -1.0)
		"down":
			return Vector2(steer * 0.68, 1.0)
		"left":
			return Vector2(-1.0, 0.0)
		"right":
			return Vector2(1.0, 0.0)
	return Vector2.ZERO

func _refresh_dpad_input() -> void:
	var combined := Vector2.ZERO
	for value in dpad_touch_vectors.values():
		if value is Vector2:
			combined += value as Vector2
	if mouse_dpad_active:
		combined += mouse_dpad_vector

	# Clamp each axis separately: forward + rudder must keep full forward throttle.
	combined.x = clampf(combined.x, -1.0, 1.0)
	combined.y = clampf(combined.y, -1.0, 1.0)

	dpad_left_held = combined.x < -0.18
	dpad_right_held = combined.x > 0.18
	dpad_up_held = combined.y < -0.18
	dpad_down_held = combined.y > 0.18

	if dpad_up:
		dpad_up.set_pressed_no_signal(dpad_up_held)
	if dpad_down:
		dpad_down.set_pressed_no_signal(dpad_down_held)
	if dpad_left:
		dpad_left.set_pressed_no_signal(dpad_left_held)
	if dpad_right:
		dpad_right.set_pressed_no_signal(dpad_right_held)

	_send_dpad_vector(combined)

func _send_dpad_vector(input_vector: Vector2) -> void:
	if not player_ship or not is_instance_valid(player_ship) or not player_ship.has_method("set_joystick_input"):
		return
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
		var travel_active: bool = false
		if player_ship.has_method("is_travel_mode"):
			travel_active = bool(player_ship.call("is_travel_mode"))
		if travel_active:
			speed_label.text = "TRAVEL ×1.5  •  %.1f kn" % speed_value
		else:
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

