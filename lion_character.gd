extends Node3D
# Player visual using the lion model (res://models/lion.glb).
# Static mesh (no skeleton): the whole body is animated in code.
# Same interface as judy_character.gd: play(name) and rotation.y.

const MODEL_PATH := "res://models/lion.glb"
const HEIGHT := 1.6
const FEET_Y := -0.8
const YAW := PI
const LION_COLOR := Color(0.93, 0.74, 0.42)

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
	_smooth(inst)
	_fit(inst)

func _smooth(inst: Node3D) -> void:
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var src: Mesh = mi.mesh
		var out := ArrayMesh.new()
		for s in src.get_surface_count():
			var arr := src.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx := PackedInt32Array()
			if arr[Mesh.ARRAY_INDEX] != null:
				idx = arr[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx.resize(verts.size())
				for k in verts.size():
					idx[k] = k
			var acc := {}
			for k in range(0, idx.size() - 2, 3):
				var a: Vector3 = verts[idx[k]]
				var b: Vector3 = verts[idx[k + 1]]
				var c: Vector3 = verts[idx[k + 2]]
				var fnrm: Vector3 = (b - a).cross(c - a)
				for v: Vector3 in [a, b, c]:
					var key := Vector3i((v * 10000.0).round())
					var cur: Vector3 = acc.get(key, Vector3.ZERO)
					acc[key] = cur + fnrm
			var nrm := PackedVector3Array()
			nrm.resize(verts.size())
			for k in verts.size():
				var key2 := Vector3i((verts[k] * 10000.0).round())
				var sum: Vector3 = acc.get(key2, Vector3.UP)
				nrm[k] = sum.normalized()
			arr[Mesh.ARRAY_NORMAL] = nrm
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mi.mesh = out
		var m := StandardMaterial3D.new()
		m.albedo_color = LION_COLOR
		m.roughness = 0.75
		mi.material_override = m

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
			var ph := t * (14.0 if is_run else 9.0)
			var s := sin(ph)
			body.position.y = absf(s) * (0.16 if is_run else 0.09)
			body.rotation.z = s * (0.16 if is_run else 0.09)
			body.rotation.x = -0.3 if is_run else -0.12
			body.scale.y = 1.0 + 0.04 * absf(s)
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
