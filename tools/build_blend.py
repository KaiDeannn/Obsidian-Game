"""Assemble preview/maps/*.glb into one organized .blend. Run:
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/build_blend.py
"""
import bpy, os, math, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPS = os.path.join(ROOT, "preview", "maps")
OUT = os.path.join(MAPS, "obsidian_game_maps.blend")
SPIRE_OFFSET = 450.0  # metres on +X so both maps sit side by side

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "Obsidian Maps"
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "METERS"

def make_collection(name, parent=None):
    col = bpy.data.collections.new(name)
    (parent or scene.collection).children.link(col)
    return col

def set_active(col):
    def find(lc):
        if lc.collection == col:
            return lc
        for c in lc.children:
            r = find(c)
            if r:
                return r
    bpy.context.view_layer.active_layer_collection = find(bpy.context.view_layer.layer_collection)

def import_glb(path, col):
    set_active(col)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]

def move_to(objs, col):
    for o in objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)

def label(text, loc, col, size=6.0, color=(0.2, 0.9, 1.0, 1), rot_x=0.0):
    curve = bpy.data.curves.new(name="LBL_" + text, type="FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    curve.extrude = size * 0.03
    ob = bpy.data.objects.new("Label " + text, curve)
    ob.location = loc
    ob.rotation_euler = (rot_x, 0, 0)
    mat = bpy.data.materials.get("LabelMat_%s" % text) or bpy.data.materials.new("LabelMat_%s" % text)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Emission"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = 2.0
    curve.materials.append(mat)
    col.objects.link(ob)
    return ob

def g2b(v):  # Godot (x, y up, z) -> Blender (x, -z, y up)
    return (v[0], -v[2], v[1])

# ------------------------------------------------------------------ city
city_col = make_collection("Nova Aetheris (City)")
city_objs = import_glb(os.path.join(MAPS, "nova_aetheris.glb"), city_col)
districts = {
    "Core Plaza": make_collection("Core Plaza", city_col),
    "The Heights": make_collection("The Heights", city_col),
    "Neon Docks": make_collection("Neon Docks", city_col),
    "Wards": make_collection("Wards & Parks", city_col),
    "Roads": make_collection("Roads, Ground & Boundary", city_col),
    "Gate": make_collection("Spire Gate", city_col),
    "Actors": make_collection("Player & Vehicle (reference)", city_col),
}
block_re = re.compile(r"Block_(-?\d+)_(-?\d+)")
def district_for(obj):
    o = obj
    while o is not None:
        m = block_re.match(o.name)
        if m:
            i, j = int(m.group(1)), int(m.group(2))
            if i == 0 and j == 0: return "Core Plaza"
            if i >= 1 and j <= -1: return "The Heights"
            if i <= -1 and j >= 1: return "Neon Docks"
            return "Wards"
        n = o.name
        if n.startswith("CityGate"): return "Gate"
        if n.startswith("Player") or n.startswith("Vehicle"): return "Actors"
        if n.startswith(("Ground", "LaneLines", "Bound", "ParkedCars")): return "Roads"
        o = o.parent
    return "Roads"
for o in city_objs:
    move_to([o], districts[district_for(o)])

anno = make_collection("Annotations", city_col)
for text, pos, colr in [("THE HEIGHTS", (78, 50, -78), (0.2, 0.9, 1, 1)), ("NEON DOCKS", (-78, 28, 78), (1, 0.6, 0.2, 1)),
                        ("CORE PLAZA", (0, 34, 0), (0.6, 0.35, 1, 1)), ("WEST WARDS", (-78, 30, -52), (1, 0.9, 0.8, 1)),
                        ("SPIRE GATE", (0, 24, -146), (0.6, 0.35, 1, 1))]:
    label(text, g2b(pos), anno, 8.0, colr, math.pi / 2)
props = [("Ridge Plot 7  950cr", (90, 0, -120)), ("Skyline Villa  1800cr", (90, 0, -90)),
         ("Obsidian Loft  2400cr", (104, 0, -90)), ("Aurora Penthouse  6500cr", (118, 0, -90))]
for text, pos in props:
    label(text, g2b((pos[0], 14, pos[2])), anno, 2.2, (1, 0.8, 0.3, 1), math.pi / 2)
jobs = {
    "Courier Run": [(-78, 0, 104), (78, 0, -104)],
    "Perimeter Sweep": [(26, 0, 26), (-26, 0, -78), (78, 0, 26)],
    "VIP Shuttle": [(26, 0, -26), (104, 0, -78)],
    "Relay Diagnostics": [(-78, 0, -26), (-78, 0, 52)],
}
jobs_col = make_collection("Job objective markers", anno)
for job, stops in jobs.items():
    for k, pos in enumerate(stops):
        bpy.ops.mesh.primitive_cone_add(radius1=1.6, depth=4.0, location=g2b((pos[0], 2.0, pos[2])))
        cone = bpy.context.active_object
        cone.name = "Objective %s #%d" % (job, k + 1)
        move_to([cone], jobs_col)
        label("%s %d" % (job, k + 1), g2b((pos[0], 6, pos[2])), jobs_col, 1.8, (0.2, 0.9, 1, 1), math.pi / 2)
label("PLAYER SPAWN", g2b((4, 4, 12)), anno, 2.0, (1, 1, 1, 1), math.pi / 2)
label("VEHICLE SPAWN", g2b((-8, 4, 26)), anno, 2.0, (1, 0.72, 0.25, 1), math.pi / 2)

# ------------------------------------------------------------------ spire
spire_col = make_collection("The Spire Ruins (Battlefield)")
spire_objs = import_glb(os.path.join(MAPS, "spire_ruins.glb"), spire_col)
sub = {
    "Arena": make_collection("Arena geometry", spire_col),
    "Enemies": make_collection("Enemy spawns (dummies & hunters)", spire_col),
    "Other": make_collection("Spawn & misc", spire_col),
}
def spire_group(obj):
    o = obj
    while o is not None:
        if o.name.startswith("Arena"): return "Arena"
        if o.name.startswith(("Dummy", "Hunter", "Enemies")): return "Enemies"
        o = o.parent
    return "Other"
roots = [o for o in spire_objs if o.parent is None or o.parent not in spire_objs]
for o in roots:
    o.location.x += SPIRE_OFFSET
for o in spire_objs:
    move_to([o], sub[spire_group(o)])
anno2 = make_collection("Annotations", spire_col)
def sg(v):
    return (v[0] + SPIRE_OFFSET, -v[2], v[1])
for text, pos, colr, size in [("THE SPIRE RUINS - CENTRAL PLAZA", (0, 40, 0), (0.6, 0.35, 1, 1), 8.0),
                              ("VANTAGE NE", (38, 14, 38), (0.2, 0.9, 1, 1), 3.0), ("VANTAGE SW", (-38, 14, -38), (0.2, 0.9, 1, 1), 3.0),
                              ("RUIN SHELL", (-40, 14, 40), (1, 0.9, 0.8, 1), 3.0), ("RUIN SHELL", (40, 14, -40), (1, 0.9, 0.8, 1), 3.0),
                              ("PLAYER SPAWN", (0, 4, 48), (1, 1, 1, 1), 2.5), ("SHATTERED SPIRE", (0, 32, 0), (0.6, 0.35, 1, 1), 3.0)]:
    label(text, sg(pos), anno2, size, colr, math.pi / 2)
enemies = [("Dummy", (12, 0, 22)), ("Dummy", (-15, 0, 18)), ("Dummy", (25, 0, -9)), ("Dummy", (-31, 0, -22)), ("Dummy", (6, 0, -36)),
           ("Dummy", (36, 6.4, 36)), ("Dummy", (-40, 6.4, -40)), ("Dummy", (0, 2.8, 0)),
           ("Hunter", (0, 0, -42)), ("Hunter", (30, 0, 10)), ("Hunter", (-28, 0, -4))]
counts = {}
for kind, pos in enemies:
    counts[kind] = counts.get(kind, 0) + 1
    label("%s %d" % (kind, counts[kind]), sg((pos[0], pos[1] + 3.4, pos[2])), anno2, 1.6, (1, 0.3, 0.3, 1) if kind == "Hunter" else (1, 0.7, 0.25, 1), math.pi / 2)

# ------------------------------------------------------------------ world, camera, view
world = bpy.data.worlds.new("Obsidian Night")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.02, 0.02, 0.05, 1)
    bg.inputs[1].default_value = 0.4
cam_data = bpy.data.cameras.new("Overview Camera")
cam = bpy.data.objects.new("Overview Camera", cam_data)
cam.location = (220, -420, 260)
cam.rotation_euler = (math.radians(55), 0, math.radians(28))
cam_data.lens = 28
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.use_bloom = True
scene.eevee.use_gtao = True

# Make emissive materials glow in Eevee (glTF import maps emissive already); bump strength.
for m in bpy.data.materials:
    if m.use_nodes and m.node_tree:
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf and bsdf.inputs["Emission Strength"].default_value == 0.0:
            em = bsdf.inputs["Emission"].default_value
            if em[0] + em[1] + em[2] > 0.05:
                bsdf.inputs["Emission Strength"].default_value = 3.0

print("objects:", len(bpy.data.objects), "meshes:", len(bpy.data.meshes), "materials:", len(bpy.data.materials), "lights:", len(bpy.data.lights))
bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True)
print("saved", OUT)
