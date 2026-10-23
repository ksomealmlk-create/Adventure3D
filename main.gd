extends Node3D

static var skip_menu := false
static var fx_on := true

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
var quality_btn: Button
var sun_light: DirectionalLight3D
var mat_cache := {}
var leaves: CPUParticles3D
var cam_off := Vector3(0, 5, 8)
var cam_zones := [
	[12.0, -13.0, Vector3(0, 5.0, 8.0)],
	[-13.0, -30.0, Vector3(0, 6.5, 9.5)],
	[-30.0, -47.0, Vector3(0, 3.6, 6.0)],
	[-47.0, -66.0, Vector3(0, 6.0, 10.5)],
	[-66.0, -72.0, Vector3(0, 5.0, 8.0)],
	[-72.0, -92.0, Vector3(0, 2.2, 5.5)],
	[-92.0, -130.0, Vector3(0, 7.0, 10.0)],
]
var was_floor := true
var dust_t := 0.0
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
	Engine.physics_ticks_per_second = 120
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.5, 0.9)
	sky_mat.sky_horizon_color = Color(0.7, 0.85, 1.0)
	sky_mat.ground_horizon_color = Color(0.7, 0.85, 1.0)
	sky_mat.ground_bottom_color = Color(0.18, 0.4, 0.2)
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.fog_enabled = true
	e.fog_light_color = Color(0.7, 0.85, 1.0)
	e.fog_density = 0.005
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	e.adjustment_contrast = 1.05
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.38
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = fx_on
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun_light = sun
	add_child(sun)

	_build_sounds()
	_build_level()
	_build_forest()

	player = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.4
	sh.height = 1.6
	cs.shape = sh
	player.add_child(cs)
	visual = preload("res://character.gd").new()
	player.add_child(visual)
	add_child(player)
	player.position = respawn_pos

	cam = Camera3D.new()
	add_child(cam)
	cam.position = respawn_pos + Vector3(0, 5, 8)
	leaves = CPUParticles3D.new()
	leaves.amount = 40
	leaves.lifetime = 6.0
	leaves.preprocess = 3.0
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(14, 5, 14)
	leaves.direction = Vector3(0.3, -1, 0.2)
	leaves.spread = 25.0
	leaves.initial_velocity_min = 0.3
	leaves.initial_velocity_max = 0.9
	leaves.gravity = Vector3(0, -0.4, 0)
	var lm := BoxMesh.new()
	lm.size = Vector3(0.14, 0.02, 0.1)
	lm.material = _mat(Color(0.75, 0.85, 0.3))
	leaves.mesh = lm
	leaves.local_coords = false
	leaves.emitting = fx_on
	cam.add_child(leaves)

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

	quality_btn = Button.new()
	quality_btn.text = "HD" if fx_on else "LD"
	quality_btn.add_theme_font_size_override("font_size", 36)
	quality_btn.custom_minimum_size = Vector2(90, 90)
	quality_btn.position = Vector2(sz.x - 230, 20)
	quality_btn.pressed.connect(_on_quality)
	layer.add_child(quality_btn)

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
	_bridge(-30.0, -46.0, 1.6, 0.8)
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
	for az in [-75.0, -79.0, -83.0, -87.0]:
		var azf: float = az
		_arch(azf, 1.6, 1.75)
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
	var body := _box(Vector3(cx, top - 0.5, (z0 + z1) * 0.5), Vector3(w, 1, ln), color)
	_add_pillars(body, w, ln, top)
	return body

func _hazard(pos: Vector3) -> void:
	var hm := _mesh(Vector3(3, 0.7, 0.8), Color(0.9, 0.1, 0.1), pos)
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.9, 0.1, 0.1)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.1, 0.05)
	em.emission_energy_multiplier = 0.8
	hm.material_override = em
	add_child(hm)
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

func _cam_zone(z: float) -> Vector3:
	for zone in cam_zones:
		var a: float = zone[0]
		var b: float = zone[1]
		if z <= a and z > b:
			var off: Vector3 = zone[2]
			return off
	return Vector3(0, 6, 9)

func _add_pillars(body: Node3D, w: float, ln: float, top: float) -> void:
	var h := top + 9.0
	var n := maxi(1, int(ln / 10.0))
	var pw := minf(w * 0.4, 1.2)
	for i in range(n):
		var z := 0.0
		if n > 1:
			z = lerpf(-ln * 0.5 + 1.0, ln * 0.5 - 1.0, float(i) / float(n - 1))
		body.add_child(_mesh(Vector3(pw, h, pw), Color(0.45, 0.32, 0.2), Vector3(0, -0.5 - h * 0.5, z)))

func _bridge(z0: float, z1: float, top: float, half: float) -> void:
	var wood_c := Color(0.35, 0.22, 0.12)
	var ln := absf(z1 - z0)
	var zc := (z0 + z1) * 0.5
	var n := maxi(1, int(ln / 4.0))
	var sides := [-1.0, 1.0]
	for sx in sides:
		var xs: float = sx
		var rx := xs * (half + 0.1)
		add_child(_mesh(Vector3(0.08, 0.08, ln), wood_c, Vector3(rx, top + 0.75, zc)))
		add_child(_mesh(Vector3(0.08, 0.08, ln), wood_c, Vector3(rx, top + 0.4, zc)))
		for i in range(n + 1):
			var pz := z0 - float(i) * (ln / float(n))
			add_child(_mesh(Vector3(0.16, 0.9, 0.16), wood_c, Vector3(rx, top + 0.45, pz)))

func _arch(z: float, top: float, half: float) -> void:
	var stone := Color(0.55, 0.55, 0.6)
	add_child(_mesh(Vector3(0.35, 3.4, 0.35), stone, Vector3(-half, top + 1.7, z)))
	add_child(_mesh(Vector3(0.35, 3.4, 0.35), stone, Vector3(half, top + 1.7, z)))
	add_child(_mesh(Vector3(half * 2.0 + 0.7, 0.4, 0.5), stone, Vector3(0, top + 3.5, z)))

func _build_forest() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	pm.material = _mat(Color(0.18, 0.4, 0.2))
	ground.mesh = pm
	ground.position = Vector3(0, -10, -60)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.3
	trunk.bottom_radius = 0.4
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	trunk.material = _mat(Color(0.4, 0.28, 0.18))
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.0
	crown.height = 1.0
	crown.radial_segments = 7
	crown.rings = 1
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.roughness = 0.9
	crown.material = cmat
	var count := 160
	var mm_t := MultiMesh.new()
	mm_t.transform_format = MultiMesh.TRANSFORM_3D
	mm_t.mesh = trunk
	mm_t.instance_count = count
	var mm_c := MultiMesh.new()
	mm_c.transform_format = MultiMesh.TRANSFORM_3D
	mm_c.use_colors = true
	mm_c.mesh = crown
	mm_c.instance_count = count
	for i in range(count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := side * rng.randf_range(7.5, 38.0)
		var z := rng.randf_range(25.0, -150.0)
		var h := rng.randf_range(11.0, 20.0)
		var th := h * 0.5
		var tw := 1.0 + h * 0.02
		mm_t.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(tw, th, tw)), Vector3(x, -10.0 + th * 0.5, z)))
		var ch := h * 0.6
		var cr := 1.4 + h * 0.1
		mm_c.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(cr, ch, cr)), Vector3(x, -10.0 + h * 0.4 + ch * 0.5, z)))
		var g := rng.randf()
		mm_c.set_instance_color(i, Color(0.08 + 0.1 * g, 0.32 + 0.2 * g, 0.12 + 0.1 * g))
	var mi_t := MultiMeshInstance3D.new()
	mi_t.multimesh = mm_t
	mi_t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi_t)
	var mi_c := MultiMeshInstance3D.new()
	mi_c.multimesh = mm_c
	mi_c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi_c)

func _mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not mat_cache.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		mat_cache[k] = m
	var out: StandardMaterial3D = mat_cache[k]
	return out

func _burst(pos: Vector3, color: Color, amount: int, speed: float) -> void:
	if not fx_on:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.14, 0.14)
	bm.material = _mat(color)
	p.mesh = bm
	p.position = pos
	p.emitting = true
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _on_quality() -> void:
	fx_on = not fx_on
	sun_light.shadow_enabled = fx_on
	leaves.emitting = fx_on
	quality_btn.text = "HD" if fx_on else "LD"

func _mesh(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
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

func _crate_old(pos: Vector3) -> void:
	var c := _box(pos, Vector3(1, 1, 1), Color(0.9, 0.7, 0.2))
	crates.append(c)

func _enemy_old(pos: Vector3, rng: float, axis: String) -> void:
	var en := Node3D.new()
	en.add_child(_mesh(Vector3(0.8, 0.8, 0.8), Color(0.8, 0.1, 0.1), Vector3.ZERO))
	en.position = pos
	en.set_meta("c", pos)
	en.set_meta("rng", rng)
	en.set_meta("axis", axis)
	add_child(en)
	enemies.append(en)

func _checkpoint_old(spot: Vector3, flag_pos: Vector3) -> void:
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
	_burst(player.position, Color(1, 0.3, 0.3), 12, 4.0)
	player.position = respawn_pos
	player.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	cam_off = cam_off.lerp(_cam_zone(player.position.z), minf(1.0, delta * 2.5))
	var cam_target := player.global_position + cam_off
	cam_target.x = player.global_position.x * 0.8
	cam.global_position = cam.global_position.lerp(cam_target, minf(1.0, delta * 6.0))
	cam.look_at(player.global_position + Vector3(0, 0.5, -2.0))
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	cam.fov = lerpf(cam.fov, 70.0 + hspeed * 1.2, minf(1.0, delta * 4.0))
	var txt := "Fruits: %d    Lives: %d" % [fruits, lives]
	if txt != label.text:
		label.text = txt
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
		_burst(player.position - Vector3(0, 0.7, 0), Color(1, 1, 1), 6, 2.5)
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
				_burst(c.position, Color(0.9, 0.7, 0.2), 14, 5.0)
				crates.erase(c)
				c.queue_free()
				fruits += 1
				_play("crate")
		for en in enemies.duplicate():
			if is_instance_valid(en) and _near(en.position, 2.3):
				enemies.erase(en)
				_burst(en.position, Color(0.8, 0.1, 0.1), 12, 5.0)
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

	var vy_before := player.velocity.y
	player.move_and_slide()
	var on_fl := player.is_on_floor()
	if spin_t > 0.0:
		visual.play("spin")
	elif not on_fl:
		visual.play("jump" if player.velocity.y > 0.0 else "fall")
	elif Vector2(player.velocity.x, player.velocity.z).length() > 6.0:
		visual.play("run")
	elif Vector2(player.velocity.x, player.velocity.z).length() > 0.5:
		visual.play("walk")
	else:
		visual.play("idle")
	if on_fl and not was_floor and vy_before < -5.0:
		_burst(player.position - Vector3(0, 0.7, 0), Color(1, 1, 1), 8, 3.0)
	was_floor = on_fl
	dust_t -= delta
	if on_fl and dust_t <= 0.0 and Vector2(player.velocity.x, player.velocity.z).length() > 4.0:
		dust_t = 0.18
		_burst(player.position - Vector3(0, 0.7, 0), Color(0.9, 0.85, 0.7), 3, 1.5)

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
				_burst(en.position, Color(0.8, 0.1, 0.1), 12, 5.0)
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
			_burst(cps[i], Color(0.2, 1.0, 0.2), 16, 6.0)

	if player.position.y < -9.0:
		_hurt()
		if state != "play":
			return
	if not won and player.position.z < -112.0 and player.position.y > 3.0:
		won = true
		state = "win"
		_play("win")
		visual.play("win")
		_burst(player.position + Vector3(0, 1, 0), Color(1, 0.84, 0), 40, 8.0)
		show_panel("YOU WIN!\nFruits: %d" % fruits, "PLAY AGAIN")

func _ball(par: Node3D, r: float, color: Color, pos: Vector3, sc: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	sm.material = _mat(color)
	mi.mesh = sm
	mi.position = pos
	mi.scale = sc
	par.add_child(mi)

func _enemy(pos: Vector3, rng: float, axis: String) -> void:
	var en := Node3D.new()
	_ball(en, 0.45, Color(0.8, 0.1, 0.1), Vector3.ZERO, Vector3(1.0, 0.9, 1.0))
	_ball(en, 0.14, Color.WHITE, Vector3(-0.17, 0.12, 0.34))
	_ball(en, 0.14, Color.WHITE, Vector3(0.17, 0.12, 0.34))
	_ball(en, 0.06, Color.BLACK, Vector3(-0.17, 0.12, 0.46))
	_ball(en, 0.06, Color.BLACK, Vector3(0.17, 0.12, 0.46))
	_ball(en, 0.1, Color(0.25, 0.03, 0.03), Vector3(-0.2, -0.4, 0.1), Vector3(1.0, 0.6, 1.3))
	_ball(en, 0.1, Color(0.25, 0.03, 0.03), Vector3(0.2, -0.4, 0.1), Vector3(1.0, 0.6, 1.3))
	var b1 := _mesh(Vector3(0.24, 0.05, 0.05), Color(0.2, 0.0, 0.0), Vector3(-0.17, 0.32, 0.4))
	b1.rotation.z = -0.5
	en.add_child(b1)
	var b2 := _mesh(Vector3(0.24, 0.05, 0.05), Color(0.2, 0.0, 0.0), Vector3(0.17, 0.32, 0.4))
	b2.rotation.z = 0.5
	en.add_child(b2)
	en.position = pos
	en.set_meta("c", pos)
	en.set_meta("rng", rng)
	en.set_meta("axis", axis)
	add_child(en)
	enemies.append(en)

func _crate(pos: Vector3) -> void:
	var c := _box(pos, Vector3(1, 1, 1), Color(0.8, 0.55, 0.25))
	var dark := Color(0.4, 0.25, 0.1)
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			c.add_child(_mesh(Vector3(0.14, 1.04, 0.14), dark, Vector3(sx, 0, sz)))
	var p1 := _mesh(Vector3(1.25, 0.1, 0.04), dark, Vector3(0, 0, 0.51))
	p1.rotation.z = 0.785
	c.add_child(p1)
	var p2 := _mesh(Vector3(1.25, 0.1, 0.04), dark, Vector3(0, 0, 0.51))
	p2.rotation.z = -0.785
	c.add_child(p2)
	crates.append(c)

func _checkpoint(spot: Vector3, flag_pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = flag_pos
	root.add_child(_mesh(Vector3(0.12, 2.2, 0.12), Color(0.85, 0.85, 0.85), Vector3.ZERO))
	root.add_child(_mesh(Vector3(0.6, 0.15, 0.6), Color(0.4, 0.4, 0.45), Vector3(0, -1.1, 0)))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.1, 0.1)
	var cloth := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.45, 0.05)
	bm.material = mat
	cloth.mesh = bm
	cloth.position = Vector3(0.4, 0.8, 0)
	root.add_child(cloth)
	add_child(root)
	cps.append(spot)
	cp_mats.append(mat)
	cp_done.append(false)
