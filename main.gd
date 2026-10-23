extends Node3D

const SPEED := 7.0
const JUMP_V := 10.0
const GRAV := 28.0
const SPIN_TIME := 0.45

var player: CharacterBody3D
var visual: Node3D
var cam: Camera3D
var label: Label
var move_vec := Vector2.ZERO
var touch_id := -1
var touch_start := Vector2.ZERO
var jump_req := false
var spin_req := false
var spin_t := 0.0
var won := false
var fruits := 0
var lives := 3
var t := 0.0
var crates: Array = []
var enemies: Array = []

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

	_crate(Vector3(-2, 0.5, -3))
	_crate(Vector3(0, 0.5, -3))
	_crate(Vector3(2, 0.5, -3))
	_crate(Vector3(0, 0.5, -14))
	_crate(Vector3(0, 1.5, -20))
	_crate(Vector3(3, 2.5, -25))

	_enemy(Vector3(0, 0.4, -7), 3.0)
	_enemy(Vector3(0, 0.4, -34), 1.0)

	player = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.4
	sh.height = 1.6
	cs.shape = sh
	player.add_child(cs)
	visual = Node3D.new()
	visual.add_child(_mesh(Vector3(0.8, 1.6, 0.8), Color(1, 0.5, 0), Vector3.ZERO))
	visual.add_child(_mesh(Vector3(0.3, 0.3, 0.3), Color(1, 1, 0), Vector3(0, 0.3, -0.5)))
	player.add_child(visual)
	add_child(player)
	player.position = Vector3(0, 1.5, 0)

	cam = Camera3D.new()
	add_child(cam)

	var layer := CanvasLayer.new()
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 32)
	layer.add_child(label)
	var sz := get_viewport().get_visible_rect().size
	var l1 := Label.new()
	l1.text = "SPIN"
	l1.position = Vector2(sz.x * 0.55, sz.y * 0.8)
	l1.add_theme_font_size_override("font_size", 40)
	layer.add_child(l1)
	var l2 := Label.new()
	l2.text = "JUMP"
	l2.position = Vector2(sz.x * 0.82, sz.y * 0.8)
	l2.add_theme_font_size_override("font_size", 40)
	layer.add_child(l2)
	add_child(layer)

func _mesh(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	return mi

func _box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.add_child(_mesh(size, color, Vector3.ZERO))
	body.position = pos
	add_child(body)
	return body

func _crate(pos: Vector3) -> void:
	var c := _box(pos, Vector3(1, 1, 1), Color(0.9, 0.7, 0.2))
	crates.append(c)

func _enemy(pos: Vector3, rng: float) -> void:
	var en := Node3D.new()
	en.add_child(_mesh(Vector3(0.8, 0.8, 0.8), Color(0.8, 0.1, 0.1), Vector3.ZERO))
	en.position = pos
	en.set_meta("cx", pos.x)
	en.set_meta("rng", rng)
	add_child(en)
	enemies.append(en)

func _input(ev: InputEvent) -> void:
	var sz := get_viewport().get_visible_rect().size
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if ev.position.x < sz.x * 0.5:
				if touch_id == -1:
					touch_id = ev.index
					touch_start = ev.position
			elif ev.position.x < sz.x * 0.75:
				spin_req = true
			else:
				jump_req = true
		elif ev.index == touch_id:
			touch_id = -1
			move_vec = Vector2.ZERO
	elif ev is InputEventScreenDrag and ev.index == touch_id:
		move_vec = ((ev.position - touch_start) / 100.0).limit_length(1.0)

func _near(p: Vector3, r: float) -> bool:
	var d := Vector2(p.x - player.position.x, p.z - player.position.z).length()
	return d < r and absf(p.y - player.position.y) < 1.6

func _hurt() -> void:
	lives -= 1
	if lives <= 0:
		lives = 3
		fruits = 0
	player.position = Vector3(0, 1.5, 0)
	player.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	t += delta
	player.velocity.x = move_vec.x * SPEED
	player.velocity.z = move_vec.y * SPEED
	if not player.is_on_floor():
		player.velocity.y -= GRAV * delta
	elif jump_req:
		player.velocity.y = JUMP_V
	jump_req = false

	if spin_req and spin_t <= 0.0:
		spin_t = SPIN_TIME
	spin_req = false
	if spin_t > 0.0:
		spin_t -= delta
		visual.rotation.y += delta * 4.0 * PI / SPIN_TIME
		for c in crates.duplicate():
			if is_instance_valid(c) and _near(c.position, 2.3):
				crates.erase(c)
				c.queue_free()
				fruits += 1
		for en in enemies.duplicate():
			if is_instance_valid(en) and _near(en.position, 2.3):
				enemies.erase(en)
				en.queue_free()
		if spin_t <= 0.0:
			visual.rotation.y = 0.0

	player.move_and_slide()

	for en in enemies.duplicate():
		en.position.x = float(en.get_meta("cx")) + sin(t * 2.0) * float(en.get_meta("rng"))
		if player.position.distance_to(en.position) < 1.0:
			if player.velocity.y < 0.0 and player.position.y > en.position.y + 0.6:
				enemies.erase(en)
				en.queue_free()
				player.velocity.y = JUMP_V * 0.7
			else:
				_hurt()

	if player.position.y < -15.0:
		_hurt()
	if not won and player.position.z < -43.0 and player.position.y > -1.0:
		won = true

	if won:
		label.text = "YOU WIN!  Fruits: %d" % fruits
	else:
		label.text = "Fruits: %d    Lives: %d" % [fruits, lives]

	cam.global_position = player.global_position + Vector3(0, 5, 8)
	cam.look_at(player.global_position)
