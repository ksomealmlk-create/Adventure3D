extends Node3D
# Player visual using the converted Judy model (res://models/judy.glb).
# Auto-fits to the player's capsule and animates the whole body in code.
# Same interface as character.gd: play(name) and rotation.y (spin is done by main.gd).

const MODEL_PATH := "res://models/judy.glb"
const HEIGHT := 1.6      # total height to fit the capsule
const FEET_Y := -0.8     # capsule bottom
const YAW := PI          # flip to 0.0 if she walks backwards

var pivot: Node3D
var body: Node3D
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
	_fit(inst)
	_pose_arms(inst)

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

func play(n: String) -> void:
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
	match anim:
		"idle":
			var b := sin(t * 2.2)
			body.scale = Vector3(1.0 + 0.015 * b, 1.0 + 0.03 * b, 1.0 + 0.015 * b)
			body.rotation.z = 0.02 * sin(t * 1.4)
		"walk", "run":
			var is_run := anim == "run"
			var ph := t * (16.0 if is_run else 10.0)
			var s := sin(ph)
			body.position.y = absf(s) * (0.12 if is_run else 0.07)
			body.rotation.z = s * (0.1 if is_run else 0.06)
			body.rotation.x = -0.2 if is_run else -0.08
		"jump":
			body.scale = Vector3(0.93, 1.1, 0.93)
			body.rotation.x = -0.1
		"fall":
			body.scale = Vector3(1.05, 0.94, 1.05)
			body.rotation.x = 0.1
		"spin":
			body.scale = Vector3(1.05, 0.92, 1.05)
		"hurt":
			pivot.visible = int(anim_t * 20.0) % 2 == 0
			body.rotation.x = 0.3
		"dead":
			var k := minf(anim_t * 3.0, 1.0)
			pivot.rotation.z = k * PI / 2.0
			pivot.position.y = FEET_Y + 0.25 * k
		"win":
			body.position.y = absf(sin(anim_t * 6.0)) * 0.5
			body.rotation.y = anim_t * 3.0

const ARM_DOWN := 1.2

func _pose_arms(inst: Node3D) -> void:
	var found := inst.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		print("Judy: no skeleton")
		return
	var sk := found[0] as Skeleton3D
	var n := 0
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i).to_lower()
		if not (nm.begins_with("def") and nm.contains("upper_arm")):
			continue
		var g := sk.get_bone_global_rest(i)
		var side := 1.0 if g.origin.x > 0.0 else -1.0
		var rot := Basis(Vector3(0, 0, 1), -side * ARM_DOWN)
		var par := sk.get_bone_parent(i)
		var pg := Basis.IDENTITY
		if par >= 0:
			pg = sk.get_bone_global_rest(par).basis
		var lb := sk.get_bone_rest(i).basis
		var nb := (pg.inverse() * rot * pg * lb).orthonormalized()
		sk.set_bone_pose_rotation(i, nb.get_rotation_quaternion())
		n += 1
	print("Judy arms posed: ", n)
