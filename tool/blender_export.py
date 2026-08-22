"""Export Z-Anatomy display meshes as one GLB per atlas layer.

Run: blender --background Startup.blend --python blender_export.py -- <staging_dir> [--thumbnails]

Display-mesh rule (validated against the shipped file): real structures are
named without a type suffix or with `.l`/`.r`; `.j`/`.i` are landmark/detail
overlays, `.t`/`.g`/`.s` are label text; names starting with "(" are optional
sub-parts; names containing "?" are junk. FONT objects are labels.
"""
import bpy
import json
import re
import sys
from math import pi

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
STAGING = argv[0] if argv else "/tmp/atlas-staging"
THUMBNAILS = "--thumbnails" in argv

SUFFIX_RE = re.compile(r"\.([a-z])$")
HEART_RE = re.compile(r"atrium|ventricle|leaflet|papillary", re.IGNORECASE)
# Credited CC-BY-NC sources (Univ. of Dundee inner ear) — excluded outright.
NC_RE = re.compile(r"^(Cochlea|Tympanic membrane|Osseous labyrinth|Membranous labyrinth)(\.[lr])?$")

SYSTEMS = {
    "skeleton": ["1: Skeletal system", "3: Joints"],
    "muscles": ["4: Muscular system"],
    "organs": ["8: Visceral systems"],
    "vessels": ["5: Cardiovascular system", "6: Lymphoid organs"],
    "nerves": ["7: Nervous system & Sense organs"],
    "skin": ["9: Regions of human body"],
}


def is_display(o):
    if o.type not in ("MESH", "CURVE"):
        return False
    if o.type == "CURVE" and not (o.data.bevel_depth > 0 or o.data.bevel_object):
        return False
    n = o.name
    if n.startswith("(") or "?" in n:
        return False
    m = SUFFIX_RE.search(n)
    if m and m.group(1) in "jitgs":
        return False
    return True


# ---- gather per-layer object lists ----
layers = {}
for lid, cols in SYSTEMS.items():
    objs = []
    for cname in cols:
        col = bpy.data.collections.get(cname)
        for o in col.objects:
            if not is_display(o):
                continue
            if lid == "nerves" and NC_RE.match(o.name):
                continue
            if cname == "5: Cardiovascular system" and o.type == "MESH" and HEART_RE.search(o.name):
                continue  # heart meshes are added to organs below
            objs.append(o)
    layers[lid] = objs

heart = [o for o in bpy.data.collections["5: Cardiovascular system"].objects
         if is_display(o) and o.type == "MESH" and HEART_RE.search(o.name)]
layers["organs"].extend(heart)

# ---- make everything reachable: enable collections, unhide objects ----
def enable(lc):
    lc.exclude = False
    lc.hide_viewport = False
    for c in lc.children:
        enable(c)

enable(bpy.context.view_layer.layer_collection)

wanted = {o for objs in layers.values() for o in objs}
for o in wanted:
    o.hide_viewport = False
    o.hide_render = False
    o.hide_select = False
    o.hide_set(False)

# ---- convert beveled curves to meshes (lower resolution first: they are
# thin tubes; meshopt simplification finishes the job later) ----
curves = [o for o in wanted if o.type == "CURVE"]
for o in curves:
    o.data.resolution_u = min(o.data.resolution_u, 6)
    o.data.bevel_resolution = min(o.data.bevel_resolution, 2)
bpy.ops.object.select_all(action="DESELECT")
for o in curves:
    o.select_set(True)
if curves:
    bpy.context.view_layer.objects.active = curves[0]
    bpy.ops.object.convert(target="MESH")

print("STAGE: curves converted", file=sys.stderr)

# ---- drop objects that evaluate to empty geometry (glTF exporter chokes) ----
deps = bpy.context.evaluated_depsgraph_get()
empty = set()
for o in wanted:
    if o.type != "MESH":
        empty.add(o)
        continue
    ev = o.evaluated_get(deps)
    try:
        me = ev.to_mesh()
        if me is None or len(me.polygons) == 0:
            empty.add(o)
        ev.to_mesh_clear()
    except RuntimeError:
        empty.add(o)
if empty:
    print(f"STAGE: dropping {len(empty)} empty/non-mesh objects: "
          f"{sorted(o.name for o in list(empty)[:10])}", file=sys.stderr)
    wanted -= empty
    for lid in layers:
        layers[lid] = [o for o in layers[lid] if o not in empty]

# ---- clean names (leading-space label quirk) ----
for o in wanted:
    if o.name != o.name.strip():
        o.name = o.name.strip()

# ---- smooth shading for organic surfaces ----
bpy.ops.object.select_all(action="DESELECT")
for o in wanted:
    o.select_set(True)
bpy.context.view_layer.objects.active = next(iter(wanted))
bpy.ops.object.shade_auto_smooth(angle=0.6109)  # 35 degrees
print("STAGE: shading done", file=sys.stderr)

# ---- flatten materials: Z-Anatomy's node-group shaders crash the 4.2 glTF
# exporter (IndexError in node-tree traversal), so bake each material down to
# a plain color + roughness. Colors come from the Principled node or a group
# Color input; tissue-type overrides keep the classic atlas look. ----
OVERRIDES = [
    (("bone", "teeth", "enamel", "dentine"), (0.91, 0.86, 0.75)),
    (("nerve",), (0.85, 0.72, 0.35)),
    (("lymph",), (0.58, 0.76, 0.50)),
    (("cartilage",), (0.80, 0.84, 0.86)),
    (("skin-1", "skin-2", "skin-3", "skin-4"), (0.85, 0.63, 0.50)),
]


def material_color(mat):
    lname = mat.name.lower()
    for kws, col in OVERRIDES:
        if any(k in lname for k in kws):
            return col, 0.55
    if mat.use_nodes and mat.node_tree:
        for n in mat.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                c = n.inputs["Base Color"].default_value
                return (c[0], c[1], c[2]), float(n.inputs["Roughness"].default_value)
        for n in mat.node_tree.nodes:
            if n.type == "GROUP":
                for s in n.inputs:
                    if getattr(s, "type", "") == "RGBA" and s.name.lower().startswith("color"):
                        c = s.default_value
                        if (round(c[0], 2), round(c[1], 2), round(c[2], 2)) != (0.5, 0.5, 0.5):
                            return (c[0], c[1], c[2]), 0.55
    c = mat.diffuse_color
    return (c[0], c[1], c[2]), 0.55


for mat in bpy.data.materials:
    (r, g, b), rough = material_color(mat)
    mat.use_nodes = False
    mat.diffuse_color = (r, g, b, 1.0)
    mat.roughness = max(0.05, min(1.0, rough))
    mat.metallic = 0.0
    mat.blend_method = "OPAQUE"
print("STAGE: materials flattened", file=sys.stderr)

# ---- export one GLB per layer ----
import os
os.makedirs(STAGING, exist_ok=True)
report = {}
failures = {}
for lid, objs in layers.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = os.path.join(STAGING, f"{lid}.glb")
    try:
        bpy.ops.export_scene.gltf(
            filepath=path,
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_normals=True,
            export_texcoords=False,
            export_materials="EXPORT",
            export_image_format="NONE",
            export_animations=False,
            export_skins=False,
            export_morph=False,
            export_extras=False,
        )
    except Exception:
        import traceback
        failures[lid] = traceback.format_exc()
        print(f"FAILED {lid}:\n{failures[lid]}", file=sys.stderr)
        continue
    report[lid] = {"objects": len(objs), "bytes": os.path.getsize(path)}
    print(f"EXPORTED {lid}: {len(objs)} objects, {report[lid]['bytes']/1e6:.1f} MB",
          file=sys.stderr)

# ---- optional per-layer verification renders (Workbench, material colors) ----
if THUMBNAILS:
    import mathutils
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = 700
    scene.render.resolution_y = 1100
    scene.render.film_transparent = False

    cam_data = bpy.data.cameras.new("ThumbCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("ThumbCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.rotation_euler = (pi / 2, 0, 0)  # look along +Y (front view)

    all_objs = [o for o in bpy.data.objects if o.type in ("MESH", "FONT", "CURVE")]
    exported = {o.name: o for objs in layers.values() for o in objs}
    for lid, objs in layers.items():
        for o in all_objs:
            o.hide_render = True
        mins = mathutils.Vector((1e9,) * 3)
        maxs = mathutils.Vector((-1e9,) * 3)
        for o in objs:
            o.hide_render = False
            for corner in o.bound_box:
                wc = o.matrix_world @ mathutils.Vector(corner)
                mins = mathutils.Vector(map(min, mins, wc))
                maxs = mathutils.Vector(map(max, maxs, wc))
        center = (mins + maxs) / 2
        size = maxs - mins
        cam_data.ortho_scale = max(size.x, size.z) * 1.15
        cam.location = (center.x, center.y - 5, center.z)
        scene.render.filepath = os.path.join(STAGING, f"thumb_{lid}.png")
        bpy.ops.render.render(write_still=True)
        print(f"RENDERED thumb_{lid}.png", file=sys.stderr)

with open(os.path.join(STAGING, "export_report.json"), "w") as f:
    json.dump(report, f, indent=1)
print("DONE", file=sys.stderr)
