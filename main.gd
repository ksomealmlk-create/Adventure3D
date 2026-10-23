extends Node3D

static var skip_menu := false

const SPEED := 7.0
const JUMP_V := 10.0
const GRAV := 28.0
const SPIN_TIME := 0.45
const MIX := 22050

var player: CharacterBody3D
var visual: Node3D
var cam: Camera3D
var label: Label
var panel: ColorRect
var title_label: Label
var button: Button
var pause_btn: Button
var stick_base: Panel
var stick_knob: Panel
var sfx := {}
var sfx_players: Array = []
var sfx_idx := 0
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

	_build_sounds()
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

	_build_ui()

	if skip_menu:
		state = "play"
		panel.hide()
	else:
		show_panel("ADVENTURE 3D", "START")

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var sz := get_viewport().get_visible_rect().size

	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 32)
	layer.add_child(label)

	_round_button(layer, "SPIN", Vector2(sz.x * 0.52, sz.y * 0.72), Vector2(sz.x * 0.2, sz.y * 0.22), Color(0.2, 0.5, 1.0, 0.35))
	_round_button(layer, "JUMP", Vector2(sz.x * 0.77, sz.y * 0.72), Vector2(sz.x * 0.2, sz.y * 0.22), Color(0.2, 0.9, 0.3, 0.35))

	stick_base = _circle(160.0, Color(1, 1, 1, 0.18))
	stick_knob = _circle(70.0, Color(1, 1, 1, 0.45))
	stick_base.hide()
	stick_knob.hide()
	layer.add_child(stick_base)
	layer.add_child(stick_knob)

	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", 36)
	pause_btn.custom_minimum_size = Vector2(90, 90)
	pause_btn.position = Vector2(sz.x - 120, 20)
	pause_btn.pressed.connect(_on_pause)
	layer.add_child(pause_btn)

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

func _circle(d: float, color: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	var r := int(d * 0.5)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _round_button(layer: CanvasLayer, text: String, pos: Vector2, size: Vector2, color: Color) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(40)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(4)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 44)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(l)
	layer.add_child(p)

# ---------- Sounds (generated in code) ----------
func _tone(freq0: float, freq1: float, dur: float, vol: float, noise: float) -> AudioStreamWAV:
	var n := int(MIX * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var k := float(i) / float(n)
		var f := lerpf(freq0, freq1, k)
		phase += TAU * f / float(MIX)
		var env := (1.0 - k) * minf(1.0, k * 40.0)
		var s := sin(phase) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.stereo = false
	w.data = data
	return w

func _build_sounds() -> void:
	sfx["jump"] = _tone(300, 650, 0.16, 0.5, 0.0)
	sfx["spin"] = _tone(500, 250, 0.22, 0.35, 0.25)
	sfx["crate"] = _tone(200, 80, 0.2, 0.6, 0.7)
	sfx["stomp"] = _tone(400, 150, 0.15, 0.55, 0.1)
	sfx["hurt"] = _tone(220, 70, 0.4, 0.6, 0.15)
	sfx["check"] = _tone(660, 990, 0.25, 0.45, 0.0)
	sfx["win"] = _tone(500, 1200, 0.7, 0.5, 0.0)
	sfx["lose"] = _tone(300, 60, 0.8, 0.55, 0.1)
	for i in range(6):
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		sfx_players.append(ap)

func _play(name: String) -> void:
	var ap: AudioStreamPlayer = sfx_players[sfx_idx]
	sfx_idx = (sfx_idx + 1) % sfx_players.size()
	ap.stream = sfx[name]
	ap.play()

# ---------- Level ----------
func _build_level() -> void:
	var green := Color(0.3, 0.7, 0.3)
	var brown := Color(0.6, 0.4, 0.2)
	var wood := Color(0.5, 0.35, 0.2)
	var red := Color(0.8, 0.3, 0.3)
	var gold := Color(1, 0.84, 0)

	_plat(0, 0.0, 8, -12, 8, green)
	_crate(Vector3(-2, 0.5, -3))
	_crate(Vector3(0, 0.5, -3))
	_crate(Vector3(2, 0.5, -3))
	_enemy(Vector3(0, 0.4, -7), 3.0, "x")

	_plat(0, 0.0, -15, -18, 3.5, brown)
	_plat(0, 0.8, -21, -24, 3.5, brown)
	_plat(0, 1.6, -27, -30, 3.5, red)
	_crate(Vector3(0, 1.3, -22.5))
	_crate(Vector3(0, 2.1, -28.5))

	_plat(0, 1.6, -30, -46, 1.6, wood)
	_checkpoint(Vector3(0, 2.1, -31), Vector3(0.55, 2.6, -31))
	_enemy(Vector3(0, 2.0, -38), 4.0, "z")

	_plat(0, 1.6, -46, -54, 8, green)
	_crate(Vector3(-2, 2.1, -49))
	_crate(Vector3(2, 2.1, -49))
	_crate(Vector3(0, 2.1, -52))
	_checkpoint(Vector3(0, 2.1, -50), Vector3(3, 2.6, -50))
	_enemy(Vector3(0, 2.0, -48), 3.0, "x")

	var mp := _plat(0, 1.6, -56.5, -59.5, 3.5, Color(0.2, 0.5, 0.9))
	movers.append({"node": mp, "base": mp.position, "amp": 2.0, "w": 3.5, "len": 3.0})

	_plat(0, 1.6, -66, -72, 8, green)
	_crate(Vector3(-2, 2.1, -70))
	_crate(Vector3(2, 2.1, -70))
	_checkpoint(Vector3(0, 2.1, -68), Vector3(3, 2.6, -68))
	_enemy(Vector3(0, 2.0, -69), 3.0, "x")
	_plat(0, 1.6, -72, -90, 3, brown)
	_hazard(Vector3(0, 1.95, -76))
	_hazard(Vector3(0, 1.95, -81))
	_hazard(Vector3(0, 1.95, -86))

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
	pause_btn.hide()

func _on_button() -> void:
	if state == "menu" or state == "pause":
		state = "play"
		panel.hide()
		pause_btn.show()
	else:
		skip_menu = true
		get_tree().reload_current_scene()

func _on_pause() -> void:
	if state == "play":
		state = "pause"
		move_vec = Vector2.ZERO
		touch_id = -1
		stick_base.hide()
		stick_knob.hide()
		show_panel("PAUSED", "RESUME")

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
					stick_base.position = ev.position - stick_base.size * 0.5
					stick_knob.position = ev.position - stick_knob.size * 0.5
					stick_base.show()
					stick_knob.show()
			elif ev.position.x < sz.x * 0.75:
				spin_req = true
			else:
				jump_req = true
		elif ev.index == touch_id:
			touch_id = -1
			move_vec = Vector2.ZERO
			stick_base.hide()
			stick_knob.hide()
	elif ev is InputEventScreenDrag and ev.index == touch_id:
		move_vec = ((ev.position - touch_start) / 100.0).limit_length(1.0)
		stick_knob.position = touch_start + move_vec * 80.0 - stick_knob.size * 0.5

func _near(p: Vector3, r: float) -> bool:
	var d := Vector2(p.x - player.position.x, p.z - player.position.z).length()
	return d < r and absf(p.y - player.position.y) < 1.6

func _hurt() -> void:
	lives -= 1
	if lives <= 0:
		state = "over"
		_play("lose")
		show_panel("GAME OVER", "RETRY")
		return
	_play("hurt")
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
		_play("jump")
	jump_req = false

	if spin_req and spin_t <= 0.0:
		spin_t = SPIN_TIME
		_play("spin")
	spin_req = false
	if spin_t > 0.0:
		spin_t -= delta
		visual.rotation.y += delta * 4.0 * PI / SPIN_TIME
		for c in crates.duplicate():
			if is_instance_valid(c) and _near(c.position, 2.3):
				crates.erase(c)
				c.queue_free()
				fruits += 1
				_play("crate")
		for en in enemies.duplicate():
			if is_instance_valid(en) and _near(en.position, 2.3):
				enemies.erase(en)
				en.queue_free()
				_play("stomp")
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
				_play("stomp")
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
			_play("check")

	if player.position.y < -15.0:
		_hurt()
		if state != "play":
			return
	if not won and player.position.z < -112.0 and player.position.y > 3.0:
		won = true
		state = "win"
		_play("win")
		show_panel("YOU WIN!\nFruits: %d" % fruits, "PLAY AGAIN")
