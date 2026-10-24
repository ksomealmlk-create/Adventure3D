extends CharacterBody3D
## Adventure3D - main hero (rigged GLB) with a code-driven run animation.
## Arms and legs swing while moving, knees/elbows bend, body leans and bobs.
## Works with Godot 4.3. Put hero.glb next to this script (res://hero.glb).

@export_file("*.glb", "*.gltf") var model_path: String = "res://hero.glb"
@export var move_speed := 6.0
@export var acceleration := 25.0
@export var jump_velocity := 7.5
@export var gravity := 24.0
@export var turn_speed := 12.0
@export var cam_distance := 6.0
@export var cam_height := 1.5
@export var cam_pitch_deg := -20.0
## Strength of the swing (radians). Raise for a more exaggerated run.
@export var leg_swing := 0.9
@export var arm_swing := 0.8

# The model's feet are ~1.0 below its origin.
const FEET_OFFSET := 1.0

# Set these from an on-screen joystick / jump button if you have one.
var move_input := Vector2.ZERO
var jump_requested := false

var _pivot: Node3D
var _model: Node3D
var _skel: Skeleton3D
var _bone := {}
var _rest := {}
var _phase := 0.0
var _blend := 0.0
var _air := 0.0
var _cam_pivot: Node3D
var _cam_yaw := 0.0
var _cam_pitch := 0.0

const BONE_NAMES := [
	"LeftUpperArm", "RightUpperArm", "LeftForearm", "RightForearm",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
	"Spine", "Chest",
]


func _ready() -> void:
	_setup_inputs()
	_build_collision()
	_load_model()
	_build_camera()


func _setup_inputs() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_forward", [KEY_W, KEY_UP])
	_add_action("move_back", [KEY_S, KEY_DOWN])
	_add_action("jump", [KEY_SPACE])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _build_collision() -> void:
	if not find_children("*", "CollisionShape3D", false).is_empty():
		return
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.9
	cs.shape = cap
	cs.position = Vector3(0, 0.95, 0)
	add_child(cs)


func _load_model() -> void:
	var scn = load(model_path)
	if scn == null:
		push_error("Hero model not found: " + model_path)
		return
	_pivot = Node3D.new()
	add_child(_pivot)
	_model = Node3D.new()
	_model.position.y = FEET_OFFSET
	_pivot.add_child(_model)
	var inst: Node = scn.instantiate()
	_model.add_child(inst)

	# Stop the imported (weak) animation so our run is the only thing posing the bones.
	var ap := _find_node_of_class(inst, "AnimationPlayer")
	if ap:
		(ap as AnimationPlayer).stop()
		(ap as AnimationPlayer).active = false

	_fix_meshes(inst)

	_skel = _find_node_of_class(inst, "Skeleton3D") as Skeleton3D
	if _skel == null:
		push_error("No Skeleton3D found in the model")
		return
	for n in BONE_NAMES:
		var i := _skel.find_bone(n)
		if i >= 0:
			_bone[n] = i
			_rest[n] = _skel.get_bone_rest(i).basis.get_rotation_quaternion()
		else:
			push_warning("Bone not found: " + n)


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


func _build_camera() -> void:
	_cam_pitch = deg_to_rad(cam_pitch_deg)
	_cam_pivot = Node3D.new()
	_cam_pivot.top_level = true
	add_child(_cam_pivot)
	_cam_pivot.global_position = global_position + Vector3(0, cam_height, 0)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, cam_distance)
	_cam_pivot.add_child(cam)
	cam.current = true


func _unhandled_input(event: InputEvent) -> void:
	# Drag on screen (touch) or hold right mouse button to rotate the camera.
	if event is InputEventScreenDrag:
		_cam_yaw -= event.relative.x * 0.005
		_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.005, -1.2, -0.05)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		_cam_yaw -= event.relative.x * 0.005
		_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.005, -1.2, -0.05)


func _physics_process(delta: float) -> void:
	var v := move_input
	if v == Vector2.ZERO:
		v = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var cam_basis := Basis(Vector3.UP, _cam_yaw)
	var dir := cam_basis * Vector3(v.x, 0, v.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var target := dir * move_speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_requested or Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	jump_requested = false

	move_and_slide()

	var hspeed := Vector2(velocity.x, velocity.z).length()
	if hspeed > 0.5 and _pivot:
		# the model faces +Z
		var yaw := atan2(velocity.x, velocity.z)
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))

	_animate(delta, hspeed)
	_update_camera(delta)


func _animate(delta: float, hspeed: float) -> void:
	if _skel == null:
		return
	var on_floor := is_on_floor()
	_blend = move_toward(_blend, clampf(hspeed / move_speed, 0.0, 1.0), delta * 8.0)
	_air = move_toward(_air, 0.0 if on_floor else 1.0, delta * 10.0)
	if on_floor:
		_phase += delta * hspeed * 1.7

	var s := sin(_phase)
	var c := cos(_phase)
	var swing := _blend * (1.0 - 0.6 * _air)

	# Rotation about +X: positive = limb swings BACK, negative = FORWARD (model faces +Z).
	var l_leg := s * leg_swing * swing
	var r_leg := -s * leg_swing * swing
	var l_arm := -s * arm_swing * swing   # arms swing opposite to the same-side leg
	var r_arm := s * arm_swing * swing

	var l_knee := maxf(0.0, -c) * 1.3 * _blend
	var r_knee := maxf(0.0, c) * 1.3 * _blend
	var l_elbow := -_blend * (0.9 + 0.25 * s)
	var r_elbow := -_blend * (0.9 - 0.25 * s)

	# In the air: raise arms, tuck legs.
	l_leg -= 0.5 * _air
	r_leg -= 0.5 * _air
	l_knee += 0.8 * _air
	r_knee += 0.8 * _air
	l_arm -= 0.9 * _air
	r_arm -= 0.9 * _air

	_set_rot("LeftUpperLeg", l_leg)
	_set_rot("RightUpperLeg", r_leg)
	_set_rot("LeftLowerLeg", l_knee)
	_set_rot("RightLowerLeg", r_knee)
	_set_rot("LeftUpperArm", l_arm)
	_set_rot("RightUpperArm", r_arm)
	_set_rot("LeftForearm", l_elbow)
	_set_rot("RightForearm", r_elbow)
	# Small torso twist for a natural look.
	_set_rot("Chest", s * 0.15 * swing, Vector3.UP)
	_set_rot("Spine", -s * 0.08 * swing, Vector3.UP)

	# Body bob and forward lean.
	_model.position.y = FEET_OFFSET + absf(s) * 0.06 * _blend
	_pivot.rotation.x = lerpf(_pivot.rotation.x, 0.18 * _blend, clampf(10.0 * delta, 0.0, 1.0))


func _set_rot(bone_name: String, angle: float, axis: Vector3 = Vector3.RIGHT) -> void:
	if not _bone.has(bone_name):
		return
	_skel.set_bone_pose_rotation(_bone[bone_name], _rest[bone_name] * Quaternion(axis, angle))


func _update_camera(delta: float) -> void:
	if _cam_pivot == null:
		return
	var goal := global_position + Vector3(0, cam_height, 0)
	_cam_pivot.global_position = _cam_pivot.global_position.lerp(goal, clampf(10.0 * delta, 0.0, 1.0))
	_cam_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0)
