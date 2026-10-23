extends Node3D

static var skip_menu := false

const SPEED := 7.0
const JUMP_V := 10.0
const GRAV := 28.0
const SPIN_TIME := 0.45

var player: CharacterBody3D
var visual: Node3D
var cam: Camera3D
var label: Label
var panel: ColorRect
var title_label: Label
var button: Button
var state := "menu"
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
var respawn_pos := Vector3(0, 1.5, 0)
var crates: Array = []
var enemies: Array = []
var cps: Array = []
var cp_mats: Array = []
var cp_done: Array = []
var movers: Array = []
var hazards: Array = []

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

	_build_level()

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
	player.position = respawn_pos

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

	panel = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 40)
	cc.add_child(vb)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	vb.add_child(title_label)
	button = Button.new()
	button.custom_minimum_size = Vector2(360, 110)
	button.add_theme_font_size_override("font_size", 48)
	button.pressed.connect(_on_button)
	vb.add_child(button)
	add_child(layer)

	if skip_menu:
		state = "play"
		panel.hide()
	else:
		show_panel("ADVENTURE 3D", "START")

func _build_level() -> void:
	var green := Color(0.3, 0.7, 0.3)
	var brown := Color(0.6, 0.4, 0.2)
	var wood := Color(0.5, 0.35, 0.2)
	var red := Color(0.8, 0.3, 0.3)
	var gold := Color(1, 0.84, 0)

	# 1) Start area
	_plat(0, 0.0, 8, -12, 8, green)
	_crate(Vector3(-2, 0.5, -3))
	_crate(Vector3(0, 0.5, -3))
	_crate(Vector3(2, 0.5, -3))
	_enemy(Vector3(0, 0.4, -7), 3.0, "x")

	# 2) Jumping platforms
	_plat(0, 0.0, -15, -18, 3.5, brown)
	_plat(0, 0.8, -21, -24, 3.5, brown)
	_plat(0, 1.6, -27, -30, 3.5, red)
	_crate(Vector3(0, 1.3, -22.5))
	_crate(Vector3(0, 2.1, -28.5))

	# 3) Bridge with an enemy
	_plat(0, 1.6, -30, -46, 1.6, wood)
	_checkpoint(Vector3(0, 2.1, -31), Vector3(0.55, 2.6, -31))
	_enemy(Vector3(0, 2.0, -38), 4.0, "z")

	# 4) Island 1
	_plat(0, 1.6, -46, -54, 8, green)
	_crate(Vector3(-2, 2.1, -49))
	_crate(Vector3(2, 2.1, -49))
	_crate(Vector3(0, 2.1, -52))
	_checkpoint(Vector3(0, 2.1, -50), Vector3(3, 2.6, -50))
	_enemy(Vector3(0, 2.0, -48), 3.0, "x")

	# 5) Moving platform over a gap
	var mp := _plat(0, 1.6, -56.5, -59.5, 3.5, Color(0.2, 0.5, 0.9))
	movers.append({"node": mp, "base": mp.position, "amp": 2.0, "w": 3.5, "len": 3.0})

	# 6) Island 2 and the trap path
	_plat(0, 1.6, -66, -72, 8, green)
	_crate(Vector3(-2, 2.1, -70))
	_crate(Vector3(2, 2.1, -70))
	_checkpoint(Vector3(0, 2.1, -68), Vector3(3, 2.6, -68))
	_enemy(Vector3(0, 2.0, -69), 3.0, "x")
	_plat(0, 1.6, -72, -90, 3, brown)
	_hazard(Vector3(0, 1.95, -76))
	_hazard(Vector3(0, 1.95, -81))
	_hazard(Vector3(0, 1.95, -86))

	# 7) Final climb
	_plat(0, 2.4, -93, -96, 3, brown)
	_plat(0, 3.2, -99, -102, 3, brown)
	_checkpoint(Vector3(0, 3.7, -100.5), Vector3(1.0, 4.2, -100.5))
	_plat(0, 4.0, -105, -108, 3, brown)
	_plat(0, 4.0, -111, -119, 8, gold)

func _plat(cx: float, top: float, z0: float, z1: float, w: float, color: Color) -> StaticBody3D:
	var ln := absf(z1 - z0)
	return _box(Vector3(cx, top - 0.5, (z0 + z1) * 0.5), Vector3(w, 1, ln), color)

func _hazard(pos: Vector3) -> void:
	add_child(_mesh(Vector3(3, 0.7, 0.8), Color(0.9, 0.1, 0.1), pos))
	hazards.append({"pos": pos, "half": Vector3(1.5, 0.35, 0.4)})

func show_panel(title: String, btn: String) -> void:
	title_label.text = title
	button.text = btn
	panel.show()

func _on_button() -> void:
	if state == "menu":
		state = "play"
		panel.hide()
	else:
		skip_menu = true
		get_tree().reload_current_scene()

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

func _enemy(pos: Vector3, rng: float, axis: String) -> void:
	var en := Node3D.new()
	en.add_child(_mesh(Vector3(0.8, 0.8, 0.8), Color(0.8, 0.1, 0.1), Vector3.ZERO))
	en.position = pos
	en.set_meta("c", pos)
	en.set_meta("rng", rng)
	en.set_meta("axis", axis)
	add_child(en)
	enemies.append(en)

func _checkpoint(spot: Vector3, flag_pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.15, 2.0, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.1, 0.1)
	bm.material = mat
	mi.mesh = bm
	mi.position = flag_pos
	add_child(mi)
	cps.append(spot)
	cp_mats.append(mat)
	cp_done.append(false)

func _input(ev: InputEvent) -> void:
	if state != "play":
		return
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
		state = "over"
		show_panel("GAME OVER", "RETRY")
		return
	player.position = respawn_pos
	player.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	cam.global_position = player.global_position + Vector3(0, 5, 8)
	cam.look_at(player.global_position)
	label.text = "Fruits: %d    Lives: %d" % [fruits, lives]
	if state != "play":
		return

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

	for m in movers:
		var node: StaticBody3D = m["node"]
		var old := node.position
		var base: Vector3 = m["base"]
		var new_pos := base + Vector3(0, 0, sin(t * 1.2) * float(m["amp"]))
		var on_it: bool = player.is_on_floor() and absf(player.position.x - old.x) < float(m["w"]) * 0.5 + 0.2 and absf(player.position.z - old.z) < float(m["len"]) * 0.5 + 0.2 and absf(player.position.y - (old.y + 1.3)) < 0.5
		node.position = new_pos
		if on_it:
			player.position += new_pos - old

	player.move_and_slide()

	for en in enemies.duplicate():
		var c: Vector3 = en.get_meta("c")
		var off := sin(t * 2.0) * float(en.get_meta("rng"))
		if en.get_meta("axis") == "x":
			en.position = Vector3(c.x + off, c.y, c.z)
		else:
			en.position = Vector3(c.x, c.y, c.z + off)
		if player.position.distance_to(en.position) < 1.0:
			if player.velocity.y < 0.0 and player.position.y > en.position.y + 0.6:
				enemies.erase(en)
				en.queue_free()
				player.velocity.y = JUMP_V * 0.7
			else:
				_hurt()
				if state != "play":
					return

	for h in hazards:
		var hp: Vector3 = h["pos"]
		var hh: Vector3 = h["half"]
		if absf(player.position.x - hp.x) < hh.x + 0.4 and absf(player.position.z - hp.z) < hh.z + 0.4 and player.position.y - 0.8 < hp.y + hh.y:
			_hurt()
			if state != "play":
				return
			break

	for i in range(cps.size()):
		if not cp_done[i] and player.position.distance_to(cps[i]) < 2.0:
			cp_done[i] = true
			respawn_pos = cps[i] + Vector3(0, 0.3, 0)
			cp_mats[i].albedo_color = Color(0.2, 1.0, 0.2)

	if player.position.y < -15.0:
		_hurt()
		if state != "play":
			return
	if not won and player.position.z < -112.0 and player.position.y > 3.0:
		won = true
		state = "win"
		show_panel("YOU WIN!\nFruits: %d" % fruits, "PLAY AGAIN")
