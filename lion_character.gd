extends Node3D
# Player visual: rigged lion (res://models/lion.glb, 18 bones).
# Same interface as judy_character.gd: play(name) and rotation.y.

const MODEL_PATH := "res://models/lion.glb"
const HEIGHT := 1.6
const FEET_Y := -0.8
const YAW := PI
const LION_COLOR := Color(0.93, 0.74, 0.42)

var pivot: Node3D
var body: Node3D
var skel: Skeleton3D
var bones := {}
var anim := "idle"
var anim_t := 0.0
var t := 0.0

func _ready() -> void:
	pivot = Node3D.new()
	pivot.position = Vector3(0, FEET_Y, 0)
	add_child(pivot)
	body = Node3D.new()
	pivot.add_child(body)
	var ps := load(MODEL_PATH) as PackedScene
	if ps == null:
		return
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return
	body.add_child(inst)
	inst.rotation.y = YAW
	_setup_rig(inst)
	_fit(inst)

func _setup_rig(inst: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.75
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = m
	var found := inst.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		print("Lion: no skeleton")
		return
	skel = found[0] as Skeleton3D
	for i in skel.get_bone_count():
		bones[skel.get_bone_name(i)] = i
	print("Lion bones: ", bones.size())

func _fit(inst: Node3D) -> void:
	var have := false
	var bb := AABB()
	var inv := body.global_transform.affine_inverse()
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if not have:
			bb = b
			have = true
		else:
			bb = bb.merge(b)
	if not have or bb.size.y < 0.001:
		return
	var s := HEIGHT / bb.size.y
	inst.scale = Vector3(s, s, s)
	var c := bb.get_center()
	inst.position = Vector3(-c.x * s, -bb.position.y * s, -c.z * s)

func _rot(bone: String, x: float, y: float = 0.0, z: float = 0.0) -> void:
	if skel == null or not bones.has(bone):
		return
	var i: int = bones[bone]
	var q := Quaternion.from_euler(Vector3(x, y, z))
	skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion() * q)

func play(n0: String) -> void:
	var n := "run" if n0 == "walk" else n0
	if n == anim:
		return
	anim = n
	anim_t = 0.0

func _process(delta: float) -> void:
	if body == null:
		return
	t += delta
	anim_t += delta
	pivot.position = Vector3(0, FEET_Y, 0)
	pivot.rotation = Vector3.ZERO
	pivot.visible = true
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	if skel != null:
		skel.reset_bone_poses()
	match anim:
		"idle":
			var br := sin(t * 2.2)
			body.scale = Vector3(1.0 + 0.012 * br, 1.0 + 0.025 * br, 1.0 + 0.012 * br)
			_rot("head", 0.04 * sin(t * 1.3))
			_rot("chest", 0.02 * br)
		"walk", "run":
			var is_run := anim == "run"
			var ph := t * (13.0 if is_run else 9.0)
			var sw := sin(ph)
			var cw := cos(ph)
			var leg := 0.9 if is_run else 0.55
			var knee := 1.2 if is_run else 0.6
			var arm := 0.7 if is_run else 0.35
			body.position.y = absf(sw) * (0.1 if is_run else 0.05)
			body.rotation.x = -0.25 if is_run else -0.08
			_rot("thigh_L", sw * leg)
			_rot("thigh_R", -sw * leg)
			_rot("shin_L", knee * maxf(0.0, -cw))
			_rot("shin_R", knee * maxf(0.0, cw))
			_rot("upper_arm_L", -sw * arm)
			_rot("upper_arm_R", sw * arm)
			_rot("forearm_L", -(1.2 if is_run else 0.25))
			_rot("forearm_R", -(1.2 if is_run else 0.25))
			_rot("spine", 0.0, sw * 0.12)
			_rot("head", 0.0, -sw * 0.08)
		"jump":
			body.scale = Vector3(0.95, 1.08, 0.95)
			_rot("thigh_L", -0.7)
			_rot("thigh_R", -0.4)
			_rot("shin_L", 0.9)
			_rot("shin_R", 0.5)
			_rot("upper_arm_L", 0.0, 0.0, 0.8)
			_rot("upper_arm_R", 0.0, 0.0, -0.8)
		"fall":
			body.scale = Vector3(1.04, 0.95, 1.04)
			_rot("thigh_L", -0.3)
			_rot("thigh_R", 0.2)
			_rot("shin_L", 0.4)
			_rot("upper_arm_L", 0.0, 0.0, 0.6)
			_rot("upper_arm_R", 0.0, 0.0, -0.6)
		"spin":
			body.scale = Vector3(1.05, 0.92, 1.05)
			_rot("thigh_L", -0.4)
			_rot("thigh_R", -0.4)
			_rot("shin_L", 0.6)
			_rot("shin_R", 0.6)
			_rot("upper_arm_L", 0.0, 0.0, 1.0)
			_rot("upper_arm_R", 0.0, 0.0, -1.0)
		"hurt":
			pivot.visible = int(anim_t * 20.0) % 2 == 0
			body.rotation.x = 0.3
			_rot("head", -0.3)
		"dead":
			var k := minf(anim_t * 3.0, 1.0)
			pivot.rotation.z = k * PI / 2.0
			pivot.position.y = FEET_Y + 0.25 * k
		"win":
			body.position.y = absf(sin(anim_t * 6.0)) * 0.5
			body.rotation.y = anim_t * 3.0
			_rot("upper_arm_L", 0.0, 0.0, 1.4)
			_rot("upper_arm_R", 0.0, 0.0, -1.4)
