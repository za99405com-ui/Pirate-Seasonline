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

var helm_root: Control = null
var helm_background: Panel = null
var helm_wheel: TextureRect = null
var helm_status: Label = null
var right_sailing_root: Control = null
var sails_button: Button = null
var anchor_button: Button = null

var helm_touch_index: int = -1
var helm_mouse_active: bool = false
var helm_last_angle: float = 0.0
var helm_rotation: float = 0.0
var helm_max_rotation: float = deg_to_rad(115.0)
var helm_return_speed: float = deg_to_rad(145.0)

func _ready() -> void:
	world_controller = get_parent()

	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.player_health_changed.connect(_on_player_health_changed)
	GameManager.ship_level_changed.connect(_on_ship_level_changed)
	GameManager.ship_storage_changed.connect(_on_ship_storage_changed)

	_apply_clean_layout()
	_create_sailing_controls()
	_create_combat_indicator()
	if not get_viewport().size_changed.is_connected(_layout_sailing_controls):
		get_viewport().size_changed.connect(_layout_sailing_controls)

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

	if fire_left_btn:
		fire_left_btn.visible = false
	if fire_right_btn:
		fire_right_btn.visible = false

	var left_controls := $Controls/LeftControls as Control
	if left_controls:
		left_controls.visible = false

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
		speed_panel.offset_left = -92.0
		speed_panel.offset_top = -72.0
		speed_panel.offset_right = 92.0
		speed_panel.offset_bottom = -18.0

func _create_sailing_controls() -> void:
	if not controls_root:
		return

	# Left: physical helm. It holds the rudder angle where the player leaves it.
	helm_root = Control.new()
	helm_root.name = "HelmControl"
	helm_root.anchor_left = 0.0
	helm_root.anchor_top = 1.0
	helm_root.anchor_right = 0.0
	helm_root.anchor_bottom = 1.0
	helm_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_root.add_child(helm_root)

	helm_background = Panel.new()
	helm_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var helm_style := StyleBoxFlat.new()
	helm_style.bg_color = Color(0.055, 0.033, 0.018, 0.82)
	helm_style.border_width_left = 3
	helm_style.border_width_top = 3
	helm_style.border_width_right = 3
	helm_style.border_width_bottom = 3
	helm_style.border_color = Color(0.64, 0.39, 0.15, 0.95)
	helm_style.corner_radius_top_left = 120
	helm_style.corner_radius_top_right = 120
	helm_style.corner_radius_bottom_left = 120
	helm_style.corner_radius_bottom_right = 120
	helm_background.add_theme_stylebox_override("panel", helm_style)
	helm_root.add_child(helm_background)

	helm_wheel = TextureRect.new()
	helm_wheel.texture = load("res://assets/ui/ship_wheel.svg") as Texture2D
	helm_wheel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	helm_wheel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	helm_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	helm_root.add_child(helm_wheel)

	helm_status = Label.new()
	helm_status.text = "RUDDER  0°"
	helm_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	helm_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	helm_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	helm_status.add_theme_font_size_override("font_size", 15)
	helm_status.add_theme_color_override("font_color", Color(1.0, 0.90, 0.66, 1.0))
	helm_root.add_child(helm_status)

	# Right: one sail control plus a separate anchor.
	right_sailing_root = Control.new()
	right_sailing_root.name = "SailingActions"
	right_sailing_root.anchor_left = 1.0
	right_sailing_root.anchor_top = 1.0
	right_sailing_root.anchor_right = 1.0
	right_sailing_root.anchor_bottom = 1.0
	controls_root.add_child(right_sailing_root)

	sails_button = _make_action_button("SAILS\nFURLED")
	anchor_button = _make_action_button("ANCHOR\nREADY")
	anchor_button.icon = load("res://assets/ui/anchor.svg") as Texture2D
	anchor_button.expand_icon = true
	sails_button.icon = load("res://assets/ui/sail.svg") as Texture2D
	sails_button.expand_icon = true
	right_sailing_root.add_child(sails_button)
	right_sailing_root.add_child(anchor_button)
	sails_button.pressed.connect(_cycle_sails)
	anchor_button.pressed.connect(_toggle_anchor)

	_layout_sailing_controls()

func _make_action_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1.0, 0.91, 0.68, 1.0))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.06, 0.09, 0.88)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.78, 0.58, 0.22, 0.90)
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.25, 0.15, 0.045, 0.98)
	pressed.border_color = Color(1.0, 0.84, 0.32, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	return button

func _layout_sailing_controls() -> void:
	if not helm_root or not right_sailing_root:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var wheel_size: float = clampf(viewport_size.y * 0.31, 190.0, 245.0)
	var edge: float = 22.0

	helm_root.offset_left = edge
	helm_root.offset_top = -wheel_size - edge
	helm_root.offset_right = edge + wheel_size
	helm_root.offset_bottom = -edge

	helm_background.position = Vector2.ZERO
	helm_background.size = Vector2(wheel_size, wheel_size)
	helm_wheel.position = Vector2.ZERO
	helm_wheel.size = Vector2(wheel_size, wheel_size)
	helm_wheel.pivot_offset = Vector2(wheel_size * 0.5, wheel_size * 0.5)
	helm_status.position = Vector2(0.0, wheel_size - 34.0)
	helm_status.size = Vector2(wheel_size, 28.0)

	var action_width: float = clampf(viewport_size.x * 0.17, 150.0, 190.0)
	var sail_height: float = 92.0
	var anchor_height: float = 78.0
	var gap: float = 16.0
	var total_height: float = sail_height + gap + anchor_height

	right_sailing_root.offset_left = -action_width - edge
	right_sailing_root.offset_top = -total_height - edge
	right_sailing_root.offset_right = -edge
	right_sailing_root.offset_bottom = -edge

	sails_button.position = Vector2(0.0, 0.0)
	sails_button.size = Vector2(action_width, sail_height)
	anchor_button.position = Vector2(0.0, sail_height + gap)
	anchor_button.size = Vector2(action_width, anchor_height)

func _input(event: InputEvent) -> void:
	if not helm_root:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and helm_touch_index == -1 and helm_root.get_global_rect().has_point(touch.position):
			helm_touch_index = touch.index
			helm_last_angle = _helm_pointer_angle(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == helm_touch_index:
			helm_touch_index = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == helm_touch_index:
			_turn_helm_to_pointer(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed and helm_root.get_global_rect().has_point(mouse.position):
				helm_mouse_active = true
				helm_last_angle = _helm_pointer_angle(mouse.position)
				get_viewport().set_input_as_handled()
			elif not mouse.pressed and helm_mouse_active:
				helm_mouse_active = false
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and helm_mouse_active:
		var motion := event as InputEventMouseMotion
		_turn_helm_to_pointer(motion.position)
		get_viewport().set_input_as_handled()

func _helm_pointer_angle(screen_position: Vector2) -> float:
	var rect: Rect2 = helm_root.get_global_rect()
	var center: Vector2 = rect.position + rect.size * 0.5
	var offset: Vector2 = screen_position - center
	return atan2(offset.y, offset.x)

func _turn_helm_to_pointer(screen_position: Vector2) -> void:
	var new_angle: float = _helm_pointer_angle(screen_position)
	var delta_angle: float = wrapf(new_angle - helm_last_angle, -PI, PI)
	helm_last_angle = new_angle
	helm_rotation = clampf(helm_rotation + delta_angle, -helm_max_rotation, helm_max_rotation)

	_apply_helm_rotation()

func _apply_helm_rotation() -> void:
	if helm_wheel:
		helm_wheel.rotation = helm_rotation

	var rudder_value: float = clampf(helm_rotation / helm_max_rotation, -1.0, 1.0)
	if player_ship and is_instance_valid(player_ship) and player_ship.has_method("set_rudder_input"):
		player_ship.call("set_rudder_input", rudder_value)
	_update_helm_status(rudder_value)

func _update_helm_status(rudder_value: float) -> void:
	if not helm_status:
		return
	var degrees_value: int = int(round(absf(rudder_value) * 35.0))
	if absf(rudder_value) < 0.04:
		helm_status.text = "RUDDER  0°"
	elif rudder_value > 0.0:
		helm_status.text = "RUDDER  %d°  RIGHT" % degrees_value
	else:
		helm_status.text = "RUDDER  %d°  LEFT" % degrees_value

func _cycle_sails() -> void:
	if not player_ship or not is_instance_valid(player_ship) or not player_ship.has_method("get_sail_level"):
		return
	# Two states only: stopped/closed or moving/open.
	var current_state: int = int(player_ship.call("get_sail_level"))
	player_ship.call("set_sail_level", 0 if current_state > 0 else 2)
	_update_sailing_buttons()

func _toggle_anchor() -> void:
	if not player_ship or not is_instance_valid(player_ship) or not player_ship.has_method("toggle_anchor"):
		return
	player_ship.call("toggle_anchor")
	_update_sailing_buttons()

func _update_sailing_buttons() -> void:
	if not player_ship or not is_instance_valid(player_ship):
		return

	if sails_button and player_ship.has_method("get_sail_level"):
		var propulsion_on: bool = int(player_ship.call("get_sail_level")) > 0
		var sail_unlocked: bool = GameManager.current_ship_level >= 3
		if player_ship.has_method("has_sail_upgrade"):
			sail_unlocked = bool(player_ship.call("has_sail_upgrade"))

		if sail_unlocked:
			sails_button.icon = load("res://assets/ui/sail.svg") as Texture2D
			sails_button.text = "SAIL\nOPEN" if propulsion_on else "SAIL\nCLOSED"
		else:
			# Before the sail is installed, this same control is the basic rowing stop/go control.
			sails_button.icon = null
			sails_button.text = "ROWING\nON" if propulsion_on else "ROWING\nSTOPPED"

	if anchor_button and player_ship.has_method("is_anchor_deployed"):
		var deployed: bool = bool(player_ship.call("is_anchor_deployed"))
		var set_now: bool = false
		if player_ship.has_method("is_anchor_set"):
			set_now = bool(player_ship.call("is_anchor_set"))
		if not deployed:
			anchor_button.text = "ANCHOR\nREADY"
		elif set_now:
			anchor_button.text = "ANCHOR\nSET"
		else:
			anchor_button.text = "ANCHOR\nDROPPING..."

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
	_update_sailing_buttons()

func _process(delta: float) -> void:
	# Releasing the helm lets the wheel and rudder return to center smoothly.
	if helm_touch_index == -1 and not helm_mouse_active and absf(helm_rotation) > 0.001:
		helm_rotation = move_toward(helm_rotation, 0.0, helm_return_speed * delta)
		_apply_helm_rotation()

	if not player_ship or not is_instance_valid(player_ship):
		return

	if speed_label:
		var speed_value: float = absf(float(player_ship.current_forward_speed)) if "current_forward_speed" in player_ship else 0.0
		var travel_active: bool = false
		if player_ship.has_method("is_travel_mode"):
			travel_active = bool(player_ship.call("is_travel_mode"))

		var propulsion_on: bool = int(player_ship.call("get_sail_level")) > 0 if player_ship.has_method("get_sail_level") else false
		var status_name: String
		if GameManager.current_ship_level >= 3:
			status_name = "SAIL OPEN" if propulsion_on else "SAIL CLOSED"
		else:
			status_name = "ROWING" if propulsion_on else "STOPPED"

		var prefix: String = "TRAVEL ×1.5  •  " if travel_active else ""
		speed_label.text = "%s%.1f kn\n%s" % [prefix, speed_value, status_name]

	_update_sailing_buttons()
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
	_update_sailing_buttons()
	if new_level == 2:
		_show_notification("CANNON UNLOCKED")
	elif new_level == 3:
		_show_notification("MAIN SAIL + TRAVEL SPEED UNLOCKED")

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
