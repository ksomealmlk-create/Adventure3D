extends Node3D

const SPEED := 7.0
const JUMP_V := 10.0
const GRAV := 28.0

var player: CharacterBody3D
var cam: Camera3D
var label: Label
var move_vec := Vector2.ZERO
var touch_id := -1
var touch_start := Vector2.ZERO
var jump_req := false
var won := false

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.8, 1.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)

	_box(Vector3(0, -0.5, 0), Vector3(8, 1, 16), Color(0.3, 0.7, 0.3))
	_box(Vector3(0, -0.5, -14), Vector3(4, 1, 4), Color(0.6, 0.4, 0.2))
	_box(Vector3(0, 0.5, -20), Vector3(4, 1, 4), Color(0.6, 0.4, 0.2))
	_box(Vector3(3, 1.5, -25), Vector3(4, 1, 4), Color(0.8, 0.3, 0.3))
	_box(Vector3(0, -0.5, -34), Vector3(3, 1, 10), Color(0.5, 0.35, 0.2))
	_box(Vector3(0, -0.5, -46), Vector3(8, 1, 8), Color(1, 0.84, 0))

	player = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.4
	sh.height = 1.6
	cs.shape = sh
	player.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 1.6, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.5, 0)
	bm.material = mat
	mi.mesh = bm
	player.add_child(mi)
	add_child(player)
	player.position = Vector3(0, 1.5, 0)

	cam = Camera3D.new()
	add_child(cam)

	var layer := CanvasLayer.new()
	label = Label.new()
	label.text = "Left: move | Right: jump"
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 32)
	layer.add_child(label)
	add_child(layer)

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	body.position = pos
	add_child(body)

func _input(ev: InputEvent) -> void:
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if ev.position.x < half and touch_id == -1:
				touch_id = ev.index
				touch_start = ev.position
			elif ev.position.x >= half:
				jump_req = true
		elif ev.index == touch_id:
			touch_id = -1
			move_vec = Vector2.ZERO
	elif ev is InputEventScreenDrag and ev.index == touch_id:
		move_vec = ((ev.position - touch_start) / 100.0).limit_length(1.0)

func _physics_process(delta: float) -> void:
	player.velocity.x = move_vec.x * SPEED
	player.velocity.z = move_vec.y * SPEED
	if not player.is_on_floor():
		player.velocity.y -= GRAV * delta
	elif jump_req:
		player.velocity.y = JUMP_V
	jump_req = false
	player.move_and_slide()

	if player.position.y < -15.0:
		player.position = Vector3(0, 1.5, 0)
		player.velocity = Vector3.ZERO
	if not won and player.position.z < -43.0 and player.position.y > -1.0:
		won = true
		label.text = "YOU WIN!"

	cam.global_position = player.global_position + Vector3(0, 5, 8)
	cam.look_at(player.global_position)
