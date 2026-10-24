extends Node3D
## Hero visual for Adventure3D. Same interface as the other character scripts:
## main.gd calls play("idle" / "walk" / "run" / "jump" / "fall" / "spin" / "win")
## and spins this node's rotation.y during the spin attack.
## Loads res://hero.glb and moves arms and legs with code.

@export var model_path: String = "res://hero.glb"
@export var model_scale := 0.8
@export var leg_swing := 0.9
@export var arm_swing := 0.8

# Distance from the model origin down to its feet (before scaling).
const FEET := 1.0
# Bottom of the player's capsule (height 1.6, centered on the player origin).
const CAPSULE_BOTTOM := -0.8
const BONE_NAMES := [
	"LeftUpperArm", "RightUpperArm", "LeftForearm", "RightForearm",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
	"Spine", "Chest",
]

var _face: Node3D
var _model: Node3D
var _base_y := 0.0
var _skel: Skeleton3D
var _bone := {}
var _rest := {}
var _body: CharacterBody3D
var _state := "idle"
var _phase := 0.0
var _move := 0.0
var _air := 0.0
var _spin := 0.0
var _win := 0.0
var _t := 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	_face = Node3D.new()
	add_child(_face)
	_model = Node3D.new()
	_model.scale = Vector3.ONE * model_scale
	_base_y = CAPSULE_BOTTOM + FEET * model_scale
	_model.position.y = _base_y
	_face.add_child(_model)

	var scn = load(model_path)
	if scn == null:
		push_error("Hero model not found: " + model_path)
		return
	var inst: Node = scn.instantiate()
	_model.add_child(inst)

	# Stop the imported animation so the code below is the only thing posing the bones.
	var ap := _find_node_of_class(inst, "AnimationPlayer")
	if ap:
		(ap as AnimationPlayer).stop()
		(ap as AnimationPlayer).active = false

	_fix_meshes(inst)

	_skel = _find_node_of_class(inst, "Skeleton3D") as Skeleton3D
	if _skel == null:
		push_error("No Skeleton3D found in hero model")
		return
	for n in BONE_NAMES:
		var i := _skel.find_bone(n)
		if i >= 0:
			_bone[n] = i
			_rest[n] = _skel.get_bone_rest(i).basis.get_rotation_quaternion()


func play(anim: String) -> void:
	_state = anim


func _find_node_of_class(root: Node, cls: String) -> Node:
	if root.is_class(cls):
		return root
	for c in root.get_children():
		var r := _find_node_of_class(c, cls)
		if r:
			return r
	return null


func _fix_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.extra_cull_margin = 3.0
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D:
					var mm := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
					mm.vertex_color_use_as_albedo = true  # the colors live in the vertices
					mm.cull_mode = BaseMaterial3D.CULL_DISABLED
					mi.set_surface_override_material(s, mm)
	for c in n.get_children():
		_fix_meshes(c)


func _process(delta: float) -> void:
	if _skel == null:
		return
	_t += delta
	var vel := Vector3.ZERO
	if _body:
		vel = _body.velocity
	var hs := Vector2(vel.x, vel.z).length()

	# Face the direction of movement (the model looks toward +Z).
	if hs > 0.5:
		_face.rotation.y = lerp_angle(_face.rotation.y, atan2(vel.x, vel.z), clampf(12.0 * delta, 0.0, 1.0))

	var in_air := _state == "jump" or _state == "fall"
	_move = move_toward(_move, clampf(hs / 7.0, 0.0, 1.0), delta * 8.0)
	_air = move_toward(_air, 1.0 if in_air else 0.0, delta * 10.0)
	_spin = move_toward(_spin, 1.0 if _state == "spin" else 0.0, delta * 14.0)
	_win = move_toward(_win, 1.0 if _state == "win" else 0.0, delta * 6.0)
	if not in_air:
		_phase += delta * hs * 1.7

	var s := sin(_phase)
	var c := cos(_phase)
	var sw := _move * (1.0 - 0.6 * _air)

	# Rotation about +X: positive = limb swings back, negative = forward.
	var l_leg := s * leg_swing * sw
	var r_leg := -s * leg_swing * sw
	var l_arm := -s * arm_swing * sw
	var r_arm := s * arm_swing * sw
	var l_knee := maxf(0.0, -c) * 1.3 * _move
	var r_knee := maxf(0.0, c) * 1.3 * _move
	var l_elbow := -_move * (0.9 + 0.25 * s)
	var r_elbow := -_move * (0.9 - 0.25 * s)

	# Standing still: gentle breathing.
	var breath := sin(_t * 2.0) * 0.03 * (1.0 - _move)
	l_arm += breath
	r_arm += breath

	# Jump / fall: arms up, legs tucked.
	l_leg -= 0.5 * _air
	r_leg -= 0.5 * _air
	l_knee += 0.8 * _air
	r_knee += 0.8 * _air
	l_arm -= 0.9 * _air
	r_arm -= 0.9 * _air

	# Victory: both arms straight up.
	l_arm -= 2.6 * _win
	r_arm -= 2.6 * _win
	l_elbow *= (1.0 - _win)
	r_elbow *= (1.0 - _win)

	_pose("LeftUpperLeg", l_leg)
	_pose("RightUpperLeg", r_leg)
	_pose("LeftLowerLeg", l_knee)
	_pose("RightLowerLeg", r_knee)
	# Spin attack: arms stretched out to the sides.
	_pose("LeftUpperArm", l_arm, -1.3 * _spin)
	_pose("RightUpperArm", r_arm, 1.3 * _spin)
	_pose("LeftForearm", l_elbow * (1.0 - _spin))
	_pose("RightForearm", r_elbow * (1.0 - _spin))
	_pose("Chest", 0.0, 0.0, s * 0.15 * sw)
	_pose("Spine", 0.0, 0.0, -s * 0.08 * sw)

	# Body bob, win bounce and forward lean.
	_model.position.y = _base_y + absf(s) * 0.06 * sw + absf(sin(_t * 8.0)) * 0.12 * _win
	_face.rotation.x = lerpf(_face.rotation.x, 0.18 * _move * (1.0 - _air), clampf(10.0 * delta, 0.0, 1.0))


func _pose(bone_name: String, x: float = 0.0, z: float = 0.0, y: float = 0.0) -> void:
	if not _bone.has(bone_name):
		return
	var q := Quaternion(Vector3.UP, y) * Quaternion(Vector3.BACK, z) * Quaternion(Vector3.RIGHT, x)
	_skel.set_bone_pose_rotation(_bone[bone_name], _rest[bone_name] * q)
