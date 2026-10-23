extends Node3D
# Stage 2: cartoon armored animal (armadillo style), built from primitives + procedural animation.
# Faces -Z. Feet are at y = -0.8 (matches the player's capsule collider).

const SHELL := Color(0.55, 0.42, 0.30)
const BAND := Color(0.40, 0.29, 0.20)
const SKIN := Color(0.88, 0.72, 0.56)
const FEET_Y := -0.8
const SPIN_TIME := 0.45

var pivot: Node3D
var body: Node3D
var head: Node3D
var tail: Node3D
var legs: Array = []
var anim := "idle"
var anim_t := 0.0
var t := 0.0

func _ready() -> void:
    pivot = Node3D.new()
    pivot.position = Vector3(0, FEET_Y, 0)
    add_child(pivot)

    # body + shell bands
    body = Node3D.new()
    body.position = Vector3(0, 0.6, 0)
    pivot.add_child(body)
    _m(body, _sphere(), SHELL, Vector3.ZERO, Vector3(0.86, 0.66, 1.2))
    var zs := [-0.3, 0.0, 0.3]
    for z in zs:
        var zf: float = z
        var f: float = sqrt(1.0 - pow(zf / 0.6, 2.0))
        _m(body, _sphere(), BAND, Vector3(0, 0, zf), Vector3(0.88 * f, 0.68 * f, 0.1))

    # head
    head = Node3D.new()
    head.position = Vector3(0, 0.68, -0.62)
    pivot.add_child(head)
    _m(head, _sphere(), SKIN, Vector3.ZERO, Vector3(0.52, 0.46, 0.5))
    _m(head, _sphere(), SKIN, Vector3(0, -0.06, -0.27), Vector3(0.22, 0.17, 0.3))
    _m(head, _sphere(), Color(0.1, 0.05, 0.05), Vector3(0, -0.02, -0.42), Vector3(0.09, 0.07, 0.07))
    _m(head, _sphere(), SHELL, Vector3(0, 0.1, 0.08), Vector3(0.5, 0.3, 0.46))
    var sides := [-1.0, 1.0]
    for sx in sides:
        var xs: float = sx
        _m(head, _sphere(), Color.WHITE, Vector3(xs * 0.15, 0.08, -0.2), Vector3(0.16, 0.17, 0.12))
        _m(head, _sphere(), Color.BLACK, Vector3(xs * 0.15, 0.08, -0.27), Vector3(0.08, 0.09, 0.05))
        _m(head, _sphere(), SHELL, Vector3(xs * 0.2, 0.24, 0.05), Vector3(0.14, 0.2, 0.1))

    # tail
    tail = Node3D.new()
    tail.position = Vector3(0, 0.55, 0.55)
    pivot.add_child(tail)
    var cm := CapsuleMesh.new()
    cm.radius = 0.07
    cm.height = 0.5
    cm.radial_segments = 8
    cm.rings = 2
    var tm := _m(tail, cm, SHELL, Vector3(0, 0, 0.22))
    tm.rotation.x = PI / 2.0

    # legs: front-left, front-right, back-left, back-right
    var hips := [Vector3(-0.28, 0.36, -0.35), Vector3(0.28, 0.36, -0.35), Vector3(-0.28, 0.36, 0.35), Vector3(0.28, 0.36, 0.35)]
    for h in hips:
        var lp := Node3D.new()
        lp.position = h
        pivot.add_child(lp)
        var lm := CapsuleMesh.new()
        lm.radius = 0.11
        lm.height = 0.4
        lm.radial_segments = 8
        lm.rings = 2
        _m(lp, lm, SKIN, Vector3(0, -0.16, 0))
        legs.append(lp)

func _sphere() -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = 0.5
    s.height = 1.0
    s.radial_segments = 16
    s.rings = 8
    return s

func _m(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mi.material_override = mat
    mi.mesh = mesh
    mi.position = pos
    mi.scale = scl
    parent.add_child(mi)
    return mi

func play(n: String) -> void:
    if n == anim:
        return
    anim = n
    anim_t = 0.0

func _process(delta: float) -> void:
    if pivot == null:
        return
    t += delta
    anim_t += delta
    # reset pose
    pivot.position = Vector3(0, FEET_Y, 0)
    pivot.rotation = Vector3.ZERO
    pivot.visible = true
    body.position = Vector3(0, 0.6, 0)
    body.rotation = Vector3.ZERO
    body.scale = Vector3.ONE
    head.rotation = Vector3.ZERO
    tail.rotation = Vector3.ZERO
    for l in legs:
        l.rotation = Vector3.ZERO

    match anim:
        "idle":
            var b := sin(t * 2.2)
            body.scale = Vector3(1.0 + 0.015 * b, 1.0 + 0.04 * b, 1.0)
            head.rotation.x = 0.04 * sin(t * 2.2 + 0.6)
            tail.rotation.y = 0.3 * sin(t * 1.5)
        "walk", "run":
            var is_run := anim == "run"
            var ph := t * (16.0 if is_run else 10.0)
            var amp := 0.9 if is_run else 0.6
            var s := sin(ph)
            legs[0].rotation.x = s * amp
            legs[3].rotation.x = s * amp
            legs[1].rotation.x = -s * amp
            legs[2].rotation.x = -s * amp
            body.position.y = 0.6 + absf(s) * (0.07 if is_run else 0.04)
            body.rotation.z = s * 0.06
            head.rotation.x = absf(s) * 0.08
            tail.rotation.y = sin(ph * 0.5) * 0.4
            if is_run:
                pivot.rotation.x = -0.18
        "jump":
            legs[0].rotation.x = 0.9
            legs[1].rotation.x = 0.9
            legs[2].rotation.x = -0.7
            legs[3].rotation.x = -0.7
            body.scale = Vector3(0.92, 1.1, 0.95)
            head.rotation.x = 0.3
            tail.rotation.x = 0.4
        "fall":
            var w := sin(t * 18.0) * 0.25
            legs[0].rotation.x = 0.5 + w
            legs[1].rotation.x = 0.5 - w
            legs[2].rotation.x = -0.5 - w
            legs[3].rotation.x = -0.5 + w
            body.scale = Vector3(1.05, 0.93, 1.0)
            head.rotation.x = -0.2
        "spin":
            var k := minf(anim_t / SPIN_TIME, 1.0)
            pivot.rotation.y = k * 4.0 * PI
            pivot.position.y = FEET_Y + 0.12
            for l in legs:
                l.rotation.x = 1.3
            body.scale = Vector3(1.05, 0.9, 1.05)
            head.rotation.x = -0.5
        "hurt":
            pivot.visible = int(anim_t * 20.0) % 2 == 0
            pivot.rotation.x = 0.35
            head.rotation.y = sin(anim_t * 40.0) * 0.35
            legs[0].rotation.x = 0.6
            legs[1].rotation.x = -0.6
            legs[2].rotation.x = -0.6
            legs[3].rotation.x = 0.6
        "dead":
            var k := minf(anim_t * 3.0, 1.0)
            pivot.rotation.z = k * PI / 2.0
            pivot.position.y = FEET_Y + 0.25 * k
            for l in legs:
                l.rotation.x = 0.4
            head.rotation.x = -0.4
        "win":
            pivot.position.y = FEET_Y + absf(sin(anim_t * 6.0)) * 0.5
            pivot.rotation.y = anim_t * 3.0
            legs[0].rotation.x = 1.8 + sin(anim_t * 12.0) * 0.4
            legs[1].rotation.x = 1.8 - sin(anim_t * 12.0) * 0.4
            head.rotation.x = 0.3
            tail.rotation.y = sin(anim_t * 14.0) * 0.6
