extends CanvasLayer

@onready var gold_label: Label = $TopBar/GoldContainer/GoldLabel
@onready var hp_bar: ProgressBar = $TopBar/HPContainer/HPBar
@onready var hp_label: Label = $TopBar/HPContainer/HPLabel
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

func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.player_health_changed.connect(_on_player_health_changed)
	GameManager.ship_level_changed.connect(_on_ship_level_changed)
	GameManager.ship_storage_changed.connect(_on_ship_storage_changed)

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
		var speed_value := abs(player_ship.current_forward_speed) if "current_forward_speed" in player_ship else 0.0
		speed_label.text = "%.1f kn" % speed_value

	if player_ship.port_cooldown > 0.0:
		fire_left_btn.disabled = true
		fire_left_btn.text = "PORT\n%.1fs" % player_ship.port_cooldown
	else:
		fire_left_btn.disabled = false
		fire_left_btn.text = "PORT\nFIRE"

	if player_ship.starboard_cooldown > 0.0:
		fire_right_btn.disabled = true
		fire_right_btn.text = "STARBOARD\n%.1fs" % player_ship.starboard_cooldown
	else:
		fire_right_btn.disabled = false
		fire_right_btn.text = "STARBOARD\nFIRE"

	_update_upgrade_button()

func _update_upgrade_button() -> void:
	if not upgrade_btn:
		return
	if GameManager.current_ship_level >= 15:
		upgrade_btn.text = "MAX LV. 15"
		upgrade_btn.disabled = true
	else:
		var next_cost := GameManager.get_next_upgrade_cost()
		upgrade_btn.text = "UPGRADE\n(%d G)" % next_cost
		upgrade_btn.disabled = false

func _on_upgrade_pressed() -> void:
	if GameManager.current_ship_level >= 15:
		return

	# If player has enough gold, spend it; otherwise, allow test progression
	if GameManager.can_upgrade_ship():
		GameManager.upgrade_ship()
	else:
		# Give player bonus gold or advance directly for easy testing on mobile
		GameManager.set_ship_level(GameManager.current_ship_level + 1)

func _on_gold_changed(new_amount: int) -> void:
	if gold_label:
		gold_label.text = "%d" % new_amount
	_update_upgrade_button()

func _on_ship_level_changed(new_level: int, title: String) -> void:
	if ship_level_label:
		ship_level_label.text = "Lv. %d • %s" % [new_level, title]
	_update_upgrade_button()
	_show_notification("★ SHIP UPGRADED: LV. %d %s ★" % [new_level, title.to_upper()])

func _on_ship_storage_changed(used: int, capacity: int) -> void:
	if cargo_label:
		cargo_label.text = "HOLD: %d / %d" % [used, capacity]

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
	tw.tween_property(notification_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.0)
	tw.tween_property(notification_banner, "modulate:a", 0.0, 0.45)

func _on_fire_left_pressed() -> void:
	if player_ship and is_instance_valid(player_ship):
		player_ship.fire_left()

func _on_fire_right_pressed() -> void:
	if player_ship and is_instance_valid(player_ship):
		player_ship.fire_right()
