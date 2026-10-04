extends CanvasLayer

@onready var gold_label: Label = $TopBar/GoldContainer/GoldLabel
@onready var hp_bar: ProgressBar = $TopBar/HPContainer/HPBar
@onready var hp_label: Label = $TopBar/HPContainer/HPLabel
@onready var speed_label: Label = $SpeedPanel/SpeedLabel
@onready var fire_left_btn: Button = $Controls/RightControls/FireLeftButton
@onready var fire_right_btn: Button = $Controls/RightControls/FireRightButton
@onready var joystick: Control = $Controls/LeftControls/VirtualJoystick

var player_ship: Node3D = null

func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.player_health_changed.connect(_on_player_health_changed)
	_on_gold_changed(GameManager.gold)

	if fire_left_btn:
		fire_left_btn.pressed.connect(_on_fire_left_pressed)
	if fire_right_btn:
		fire_right_btn.pressed.connect(_on_fire_right_pressed)

func set_player(player: Node3D) -> void:
	player_ship = player
	if joystick and player_ship and player_ship.has_method("set_joystick_input"):
		joystick.joystick_moved.connect(player_ship.set_joystick_input)

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

func _on_gold_changed(new_amount: int) -> void:
	if gold_label:
		gold_label.text = "%d" % new_amount

func _on_player_health_changed(current: float, maximum: float) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
	if hp_label:
		hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_fire_left_pressed() -> void:
	if player_ship and is_instance_valid(player_ship):
		player_ship.fire_left()

func _on_fire_right_pressed() -> void:
	if player_ship and is_instance_valid(player_ship):
		player_ship.fire_right()
