extends Control

signal joystick_moved(vector: Vector2)

@export var max_radius: float = 88.0
@export var deadzone: float = 0.12

var touch_index: int = -1
var is_active: bool = false
var center_position: Vector2 = Vector2.ZERO
var current_handle_position: Vector2 = Vector2.ZERO
var output_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	center_position = size / 2.0
	current_handle_position = center_position
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			is_active = true
			_update_position(event.position)
		elif not event.pressed and event.index == touch_index:
			_reset_joystick()
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update_position(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and touch_index == -1:
			touch_index = 0
			is_active = true
			_update_position(event.position)
		elif not event.pressed and touch_index == 0:
			_reset_joystick()
	elif event is InputEventMouseMotion and is_active and touch_index == 0:
		_update_position(event.position)

func _update_position(touch_pos: Vector2) -> void:
	center_position = size / 2.0
	var offset: Vector2 = touch_pos - center_position
	var distance: float = offset.length()
	
	if distance > max_radius:
		offset = offset.normalized() * max_radius
	
	current_handle_position = center_position + offset
	
	var normalized_dist: float = offset.length() / max_radius
	if normalized_dist < deadzone:
		output_vector = Vector2.ZERO
	else:
		output_vector = offset.normalized() * ((normalized_dist - deadzone) / (1.0 - deadzone))
	
	joystick_moved.emit(output_vector)
	queue_redraw()

func _reset_joystick() -> void:
	touch_index = -1
	is_active = false
	current_handle_position = center_position
	output_vector = Vector2.ZERO
	joystick_moved.emit(Vector2.ZERO)
	queue_redraw()

func _draw() -> void:
	center_position = size / 2.0
	if not is_active:
		current_handle_position = center_position
	
	# Draw Base Outer Ring
	draw_circle(center_position, max_radius, Color(0.04, 0.12, 0.22, 0.45))
	draw_arc(center_position, max_radius, 0.0, TAU, 48, Color(1.0, 0.84, 0.2, 0.8), 3.0, true)
	
	# Direction indicator ticks
	draw_line(center_position - Vector2(max_radius * 0.7, 0), center_position + Vector2(max_radius * 0.7, 0), Color(1.0, 0.84, 0.2, 0.25), 2.0)
	draw_line(center_position - Vector2(0, max_radius * 0.7), center_position + Vector2(0, max_radius * 0.7), Color(1.0, 0.84, 0.2, 0.25), 2.0)
	
	# Draw Inner Thumbstick
	draw_circle(current_handle_position, max_radius * 0.4, Color(0.65, 0.45, 0.15, 0.85))
	draw_arc(current_handle_position, max_radius * 0.4, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, 0.95), 2.5, true)
	draw_circle(current_handle_position, max_radius * 0.12, Color(1.0, 1.0, 1.0, 0.7))
