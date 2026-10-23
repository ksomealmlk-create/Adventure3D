# Runs inside Blender (headless) on GitHub Actions.
# Usage: blender -b tools/Judy.blend --python tools/judy_convert.py -- out.glb info.txt
import bpy, sys, os

argv = sys.argv
argv = argv[argv.index("--") + 1:] if "--" in argv else []
OUT = argv[0] if len(argv) > 0 else "judy.glb"
INFO = argv[1] if len(argv) > 1 else "judy_info.txt"
TARGET_TRIS = 25000
TEX_SIZE = 1024
log = []

def L(*a):
    s = " ".join(str(x) for x in a)
    print(s)
    log.append(s)

scene = bpy.context.scene
root = scene.collection

# 1) remove rig widgets, cameras, lights
for ob in list(bpy.data.objects):
    n = ob.name.lower()
    junk = ("wdgt", "wgt", "ground", "badgebooleans", "eyeboolean", "camera_rig")
    if n.startswith(junk) or ob.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(ob, do_unlink=True)

# 2) make everything visible and linked to the scene
for ob in bpy.data.objects:
    try:
        if ob.name not in scene.objects:
            root.objects.link(ob)
        ob.hide_viewport = False
        ob.hide_render = False
        ob.hide_set(False)
    except Exception as e:
        L("visibility warn", ob.name, e)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
L("OBJECTS", len(bpy.data.objects), "MESHES", len(meshes), "ARMATURES", len(arms))

# 3) clean meshes
def est_tris(o):
    t = sum(max(1, len(p.vertices) - 2) for p in o.data.polygons)
    if any(m.type == "MIRROR" for m in o.modifiers):
        t *= 2
    return t

for o in meshes:
    for m in list(o.modifiers):
        if m.type in ("SUBSURF", "MULTIRES", "PARTICLE_SYSTEM"):
            o.modifiers.remove(m)
    if o.data.shape_keys:
        try:
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.shape_key_remove(all=True)
        except Exception as e:
            L("shapekey warn", o.name, e)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    for m in list(o.modifiers):
        if m.type in ("MESH_DEFORM", "BOOLEAN", "MIRROR"):
            try:
                m.show_viewport = True
                m.show_render = True
                L("APPLYING", o.name, m.type)
                bpy.context.view_layer.objects.active = o
                bpy.ops.object.modifier_apply(modifier=m.name)
            except Exception as e:
                L("apply warn", o.name, m.name, e)
                try:
                    o.modifiers.remove(m)
                except Exception:
                    pass
cage = bpy.data.objects.get("MeshCage")
if cage:
    bpy.data.objects.remove(cage, do_unlink=True)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
total = sum(est_tris(o) for o in meshes)
ratio = min(1.0, TARGET_TRIS / max(1, total))
L("TOTAL_TRIS_EST", total, "DECIMATE_RATIO", round(ratio, 4))
for o in meshes:
    t = est_tris(o)
    L("MESH", o.name, "tris~", t, "mods", [m.type for m in o.modifiers],
      "materials", [s.material.name for s in o.material_slots if s.material])
    if ratio < 1.0 and t > 400:
        d = o.modifiers.new("JudyDecimate", "DECIMATE")
        d.ratio = max(0.02, ratio)

# 4) make materials exportable (Diffuse BSDF -> Principled)
def fix_material(mat):
    if not mat.use_nodes:
        mat.use_nodes = True
        for n in mat.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                n.inputs["Base Color"].default_value = mat.diffuse_color
        return
    nt = mat.node_tree
    out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
    if out is None:
        return
    if any(n.type == "BSDF_PRINCIPLED" for n in nt.nodes):
        return
    img = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image), None)
    diff = next((n for n in nt.nodes if n.type == "BSDF_DIFFUSE"), None)
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    p.inputs["Roughness"].default_value = 0.8
    linked = False
    if diff is not None:
        sock = diff.inputs["Color"]
        if sock.links:
            nt.links.new(sock.links[0].from_socket, p.inputs["Base Color"])
            linked = True
        else:
            p.inputs["Base Color"].default_value = sock.default_value
            linked = True
    if not linked and img is not None:
        nt.links.new(img.outputs["Color"], p.inputs["Base Color"])
    nt.links.new(p.outputs["BSDF"], out.inputs["Surface"])

for mat in bpy.data.materials:
    try:
        fix_material(mat)
    except Exception as e:
        L("material warn", mat.name, e)

# 5) shrink textures
for img in bpy.data.images:
    try:
        w, h = img.size
        if w > TEX_SIZE or h > TEX_SIZE:
            k = TEX_SIZE / max(w, h)
            img.scale(max(1, int(w * k)), max(1, int(h * k)))
    except Exception as e:
        L("image warn", img.name, e)

# 6) info for the human
try:
    import mathutils
    pts = []
    for o in meshes:
        for c in o.bound_box:
            pts.append(o.matrix_world @ mathutils.Vector(c))
    if pts:
        mn = [min(p[i] for p in pts) for i in range(3)]
        mx = [max(p[i] for p in pts) for i in range(3)]
        L("BBOX_MIN", [round(x, 3) for x in mn], "BBOX_MAX", [round(x, 3) for x in mx])
except Exception as e:
    L("bbox warn", e)
for a in arms:
    L("ARMATURE", a.name, "bones", len(a.data.bones))
    L("BONES", ", ".join(b.name for b in a.data.bones)[:3000])
L("ACTIONS", [a.name for a in bpy.data.actions])

# 7) export
try:
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_animations=False,
        export_image_format="JPEG",
        export_skins=True,
        export_yup=True,
    )
    L("EXPORT_OK", OUT, os.path.getsize(OUT), "bytes")
except Exception as e:
    L("EXPORT_FAILED", e)
    with open(INFO, "w") as f:
        f.write("\n".join(log))
    sys.exit(1)

with open(INFO, "w") as f:
    f.write("\n".join(log))
