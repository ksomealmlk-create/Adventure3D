extends CanvasLayer
## On-screen controls for touch screens:
##  - Left half of the screen: floating joystick (touch anywhere and drag).
##  - Round button bottom-right: jump.
##  - Drag anywhere else on the right side: rotate the camera (handled by player.gd).
## Add this script to a CanvasLayer node that is a sibling of the node called "Player"
## (or set player_path).

@export var player_path: NodePath
@export var stick_radius := 130.0
@export var knob_radius := 55.0
@export var jump_radius := 90.0

var _player: Node
var _canvas: Control
var _stick_idx := -1
var _stick_center := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _jump_idx := -1


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_on_draw)
	if player_path != NodePath():
		_player = get_node_or_null(player_path)
	else:
		_player = get_parent().get_node_or_null("Player")
	if _player == null:
		push_warning("TouchControls: Player node not found")
	_canvas.queue_redraw()


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _jump_center() -> Vector2:
	return _screen_size() - Vector2(170, 200)


func _idle_stick_center() -> Vector2:
	return Vector2(220, _screen_size().y - 220)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(_jump_center()) <= jump_radius * 1.3:
				_jump_idx = event.index
				if _player:
					_player.jump_requested = true
				get_viewport().set_input_as_handled()
			elif event.position.x < _screen_size().x * 0.5 and _stick_idx == -1:
				_stick_idx = event.index
				_stick_center = event.position
				_stick_pos = event.position
				_update_stick()
				get_viewport().set_input_as_handled()
		else:
			if event.index == _stick_idx:
				_stick_idx = -1
				_set_move(Vector2.ZERO)
				get_viewport().set_input_as_handled()
			elif event.index == _jump_idx:
				_jump_idx = -1
				get_viewport().set_input_as_handled()
		_canvas.queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_idx:
			_stick_pos = event.position
			_update_stick()
			get_viewport().set_input_as_handled()
		elif event.index == _jump_idx:
			get_viewport().set_input_as_handled()
		_canvas.queue_redraw()


func _update_stick() -> void:
	var v := _stick_pos - _stick_center
	if v.length() > stick_radius:
		v = v.normalized() * stick_radius
		_stick_pos = _stick_center + v
	if v.length() < stick_radius * 0.1:
		_set_move(Vector2.ZERO)
	else:
		_set_move(v / stick_radius)


func _set_move(v: Vector2) -> void:
	if _player:
		_player.move_input = v


func _on_draw() -> void:
	var base := _stick_center if _stick_idx != -1 else _idle_stick_center()
	var knob := _stick_pos if _stick_idx != -1 else base
	_canvas.draw_circle(base, stick_radius, Color(1, 1, 1, 0.18))
	_canvas.draw_circle(knob, knob_radius, Color(1, 1, 1, 0.45))
	var a := 0.55 if _jump_idx != -1 else 0.28
	_canvas.draw_circle(_jump_center(), jump_radius, Color(1, 1, 1, a))
