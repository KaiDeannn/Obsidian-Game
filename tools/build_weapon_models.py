"""Builds the ten Engineer weapon models and exports one .glb per weapon.

Run:  blender --background --python tools/build_weapon_models.py -- <out_dir> [<render_dir>]

Each weapon is modelled from the design document's reference picture: lathed canister
bodies, bevelled plates, tapered shells, rings, levers and emissive cores, with PBR
materials (painted metal, gunmetal, polymer, glass, emission). Launchers point along
+Y (which the glTF exporter maps to Godot's -Z, forward); grenades stand along +Z with
their centre at the origin; the mine sits on the ground plane. Units are metres.
"""
import bpy
import bmesh
import math
import sys
import os
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = argv[0] if len(argv) > 0 else "."
RENDER_DIR = argv[1] if len(argv) > 1 else ""


# ----------------------------------------------------------------------------- scene helpers
_mats = {}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.lights, bpy.data.cameras):
        for item in list(block):
            if item.users == 0:
                block.remove(item)
    _mats.clear()


def mat(name, color, metallic=0.0, rough=0.5, emit=None, strength=0.0, alpha=1.0):
    key = (name, tuple(color), metallic, rough, tuple(emit) if emit else None, strength, alpha)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission"].default_value = (emit[0], emit[1], emit[2], 1.0)
        b.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    _mats[key] = m
    return m


def M():
    return {
        "gunmetal": mat("Gunmetal", (0.07, 0.075, 0.085), 0.9, 0.38),
        "steel": mat("Steel", (0.52, 0.54, 0.57), 0.95, 0.28),
        "steel_dark": mat("SteelDark", (0.2, 0.21, 0.23), 0.9, 0.35),
        "polymer": mat("Polymer", (0.025, 0.025, 0.03), 0.1, 0.62),
        "white": mat("WhitePaint", (0.86, 0.86, 0.84), 0.25, 0.32),
        "grey": mat("GreyPaint", (0.5, 0.56, 0.58), 0.45, 0.4),
        "red": mat("RedPaint", (0.72, 0.05, 0.06), 0.35, 0.34),
        "olive": mat("Olive", (0.27, 0.31, 0.25), 0.3, 0.6),
        "glow_red": mat("GlowRed", (0.9, 0.08, 0.06), 0.0, 0.4, (1.0, 0.08, 0.04), 2.6),
        "glow_cyan": mat("GlowCyan", (0.1, 0.8, 0.95), 0.0, 0.3, (0.1, 0.85, 1.0), 2.4),
        "glow_orange": mat("GlowOrange", (1.0, 0.5, 0.08), 0.0, 0.4, (1.0, 0.38, 0.03), 2.8),
        "glow_gold": mat("GlowGold", (1.0, 0.8, 0.3), 0.0, 0.4, (1.0, 0.7, 0.2), 2.2),
        "glow_violet": mat("GlowViolet", (0.7, 0.2, 1.0), 0.0, 0.4, (0.7, 0.15, 1.0), 2.6),
        "glow_green": mat("GlowGreen", (0.2, 1.0, 0.3), 0.0, 0.4, (0.2, 1.0, 0.3), 2.2),
        "glow_white": mat("GlowWhite", (1.0, 0.95, 0.85), 0.0, 0.4, (1.0, 0.9, 0.7), 1.8),
        "glass_cyan": mat("GlassCyan", (0.3, 0.9, 1.0), 0.1, 0.05, (0.1, 0.8, 1.0), 1.2, 0.7),
        "crystal": mat("Crystal", (0.95, 0.95, 1.0), 0.15, 0.03, None, 0.0, 0.32),
    }


def finish(obj, material, bevel=0.003, segments=2, smooth=True, angle=35.0):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(30.0)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(angle)
    return obj


def _axis_rot(axis):
    if axis == "Y":
        return Euler((math.radians(90), 0, 0))
    if axis == "X":
        return Euler((0, math.radians(90), 0))
    return Euler((0, 0, 0))


def cyl(r, length, loc, material, axis="Z", verts=32, r2=None, bevel=0.003, smooth=True):
    """Cylinder (or cone frustum with r2) centred at loc, along axis."""
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=length, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=length, location=loc)
    o = bpy.context.active_object
    o.rotation_euler = _axis_rot(axis)
    return finish(o, material, bevel, 2, smooth)


def box(size, loc, material, rot=(0, 0, 0), bevel=0.004, taper=None, taper_axis="Y"):
    """Box; taper=(a, b) scales the far face (+taper_axis) cross-section to make a wedge."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if taper:
        idx = {"X": 0, "Y": 1, "Z": 2}[taper_axis]
        others = [i for i in range(3) if i != idx]
        for v in o.data.vertices:
            if v.co[idx] > 0:
                v.co[others[0]] *= taper[0]
                v.co[others[1]] *= taper[1]
    o.rotation_euler = Euler(tuple(math.radians(a) for a in rot))
    return finish(o, material, bevel, 2, True)


def lathe(profile, material, loc=(0, 0, 0), steps=48, bevel=0.0015, name="Lathe"):
    """Revolve a list of (radius, z) points around Z. Closed top and bottom."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for s in range(steps):
            a = 2.0 * math.pi * s / steps
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for s in range(steps):
            n = (s + 1) % steps
            bm.faces.new((rings[i][s], rings[i][n], rings[i + 1][n], rings[i + 1][s]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.location = loc
    bpy.context.view_layer.objects.active = o
    return finish(o, material, bevel, 2, True, 40.0)


def sphere(r, loc, material, segments=32, rings=16, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, material, 0.0, 1, True, 60.0)


def ico(r, loc, material, subdiv=1, scale=(1, 1, 1), smooth=False):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, material, 0.0, 1, smooth)


def torus(big, small, loc, material, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=big, minor_radius=small, major_segments=40, minor_segments=12, location=loc)
    o = bpy.context.active_object
    o.rotation_euler = Euler(tuple(math.radians(a) for a in rot))
    o.scale = scale
    return finish(o, material, 0.0, 1, True, 60.0)


def around(n, radius, z, fn, start=0.0):
    """Call fn(x, y, z, angle_deg) at n points on a circle."""
    for k in range(n):
        a = start + 2.0 * math.pi * k / n
        fn(radius * math.cos(a), radius * math.sin(a), z, math.degrees(a))


def lever_and_ring(m, top_z, radius, lever_mat, ring_mat):
    """Safety lever (spoon) running down the side plus a pull ring: the grenade silhouette."""
    box((0.016, 0.03, 0.006), (0, radius * 0.45, top_z + 0.004), lever_mat, bevel=0.002)
    box((0.016, 0.006, 0.07), (0, radius + 0.008, top_z - 0.03), lever_mat, rot=(-6, 0, 0), bevel=0.002)
    torus(0.014, 0.0022, (0.0, -radius * 0.75, top_z + 0.012), ring_mat, rot=(90, 0, 20))
    cyl(0.003, 0.03, (0, -radius * 0.3, top_z + 0.004), ring_mat, axis="Y", verts=10, bevel=0.0)


# ----------------------------------------------------------------------------- launchers
def build_oathkeeper():
    m = M()
    # molten core and the striped inner sleeve seen through the shroud windows
    cyl(0.034, 1.05, (0, 0.22, 0), m["glow_red"], axis="Y", bevel=0.0)
    cyl(0.05, 0.7, (0, 0.05, 0), m["steel"], axis="Y", verts=24)
    for y in (-0.22, -0.05, 0.12, 0.3):
        cyl(0.052, 0.045, (0, y, 0), m["red"], axis="Y", verts=24, bevel=0.001)
    # octagonal shroud made of eight plates; the two side plates are split to open windows
    for k in range(8):
        a = math.radians(45 * k + 22.5)
        x, z = 0.083 * math.cos(a), 0.083 * math.sin(a)
        rot = (0, -math.degrees(a) + 90, 0)
        side = abs(math.cos(a)) > 0.9
        if side:
            for y, ln in ((-0.36, 0.2), (0.32, 0.26)):
                box((0.064, ln, 0.012), (x, y, z), m["gunmetal"], rot=rot, bevel=0.002)
        else:
            box((0.064, 0.92, 0.012), (x, 0.0, z), m["gunmetal"], rot=rot, bevel=0.002)
    # long front barrel, collar, rear cap
    cyl(0.07, 0.5, (0, 0.72, 0), m["gunmetal"], axis="Y", verts=8, bevel=0.004)
    cyl(0.094, 0.05, (0, 0.47, 0), m["steel_dark"], axis="Y", verts=8, bevel=0.004)
    cyl(0.05, 0.02, (0, 0.975, 0), m["polymer"], axis="Y", verts=24, bevel=0.0)
    cyl(0.088, 0.045, (0, -0.48, 0), m["red"], axis="Y", verts=8, bevel=0.004)
    # top sight rail and two sight blocks
    box((0.022, 0.5, 0.014), (0, 0.0, 0.098), m["polymer"], bevel=0.002)
    box((0.03, 0.05, 0.03), (0, 0.12, 0.115), m["polymer"], bevel=0.003)
    box((0.02, 0.03, 0.022), (0, -0.2, 0.112), m["polymer"], bevel=0.003)
    # receiver, trigger guard, pistol grip, fore grip, front lug
    box((0.06, 0.4, 0.06), (0, 0.02, -0.115), m["gunmetal"], bevel=0.006)
    box((0.045, 0.07, 0.15), (0, -0.1, -0.225), m["polymer"], rot=(18, 0, 0), bevel=0.008)
    torus(0.03, 0.005, (0, -0.03, -0.165), m["gunmetal"], rot=(0, 90, 0), scale=(1, 1.3, 1))
    cyl(0.021, 0.14, (0, 0.2, -0.215), m["polymer"], verts=20)
    cyl(0.0225, 0.02, (0, 0.2, -0.25), m["red"], verts=20, bevel=0.0)
    box((0.02, 0.04, 0.04), (0, 0.9, -0.085), m["gunmetal"], bevel=0.003)


def build_sunblaze():
    m = M()
    # smooth white upper shell, red belly and red nose: ellipsoids and a cone, not boxes
    sphere(1.0, (0, 0.06, 0.03), m["white"], 40, 20, scale=(0.078, 0.3, 0.07))
    sphere(1.0, (0, 0.04, -0.012), m["red"], 40, 20, scale=(0.074, 0.285, 0.062))
    cyl(0.062, 0.2, (0, 0.38, 0.008), m["red"], axis="Y", verts=32, r2=0.03, bevel=0.004)
    box((0.07, 0.16, 0.01), (0, 0.04, 0.098), m["polymer"], bevel=0.004)         # top vent strip
    for k in range(5):
        box((0.05, 0.008, 0.004), (0, -0.01 + k * 0.025, 0.104), m["gunmetal"], bevel=0.001)
    for sx in (-1, 1):                                                           # side windows + status light
        box((0.008, 0.08, 0.04), (sx * 0.073, 0.0, 0.034), m["grey"], rot=(0, sx * 14, 0), bevel=0.006)
        box((0.008, 0.06, 0.034), (sx * 0.069, 0.13, 0.03), m["grey"], rot=(0, sx * 18, 0), bevel=0.006)
        sphere(0.006, (sx * 0.076, -0.075, 0.03), m["glow_white"], 10, 6)
        box((0.006, 0.26, 0.006), (sx * 0.074, 0.02, 0.006), m["gunmetal"], bevel=0.002)   # shell seam
    # barrel running through, muzzle brake, rear stock tube
    cyl(0.034, 0.26, (0, -0.33, 0.012), m["polymer"], axis="Y", verts=28)
    cyl(0.042, 0.05, (0, -0.44, 0.012), m["polymer"], axis="Y", verts=28)
    cyl(0.046, 0.025, (0, -0.2, 0.012), m["gunmetal"], axis="Y", verts=28)
    cyl(0.04, 0.07, (0, 0.5, 0.008), m["polymer"], axis="Y", verts=28)
    cyl(0.026, 0.072, (0, 0.5, 0.008), m["gunmetal"], axis="Y", verts=24, bevel=0.0)
    cyl(0.044, 0.012, (0, 0.47, 0.008), m["steel"], axis="Y", verts=28, bevel=0.001)
    # grip, trigger guard, magazine
    box((0.038, 0.058, 0.14), (0, -0.07, -0.13), m["polymer"], rot=(16, 0, 0), bevel=0.01)
    torus(0.028, 0.005, (0, -0.01, -0.082), m["gunmetal"], rot=(0, 90, 0), scale=(1, 1.3, 1))
    box((0.042, 0.065, 0.11), (0, 0.14, -0.105), m["polymer"], rot=(-8, 0, 0), bevel=0.008)
    box((0.044, 0.07, 0.012), (0, 0.133, -0.165), m["gunmetal"], rot=(-8, 0, 0), bevel=0.003)


def build_skyfall():
    m = M()
    # front launch tube: faceted shroud around a round barrel, heavy muzzle ring
    cyl(0.112, 0.5, (0, 0.36, 0.02), m["grey"], axis="Y", verts=8, bevel=0.012)
    cyl(0.08, 0.14, (0, 0.66, 0.02), m["polymer"], axis="Y", verts=36)
    cyl(0.092, 0.03, (0, 0.615, 0.02), m["steel_dark"], axis="Y", verts=36)
    cyl(0.088, 0.02, (0, 0.72, 0.02), m["steel_dark"], axis="Y", verts=36)
    cyl(0.06, 0.142, (0, 0.662, 0.02), m["gunmetal"], axis="Y", verts=36, bevel=0.0)
    box((0.12, 0.3, 0.02), (0, 0.36, 0.128), m["grey"], bevel=0.006)             # top deck
    for k in range(10):                                                          # cooling slats
        box((0.09, 0.011, 0.012), (0, 0.24 + k * 0.026, 0.142), m["polymer"], bevel=0.002)
    for sx in (-1, 1):
        box((0.012, 0.26, 0.04), (sx * 0.106, 0.36, 0.02), m["polymer"], bevel=0.004)
        box((0.008, 0.12, 0.016), (sx * 0.112, 0.4, 0.062), m["white"], bevel=0.003)
        for k in range(4):
            box((0.008, 0.016, 0.01), (sx * 0.112, 0.27 + k * 0.03, -0.03), m["gunmetal"], bevel=0.002)
    # dark mid housing with status lights and a top sight block
    cyl(0.098, 0.2, (0, 0.02, 0.03), m["gunmetal"], axis="Y", verts=8, bevel=0.01)
    box((0.07, 0.09, 0.04), (0, 0.03, 0.135), m["polymer"], bevel=0.008)
    box((0.03, 0.03, 0.02), (0, 0.06, 0.165), m["polymer"], bevel=0.004)
    for k in range(3):
        box((0.006, 0.012, 0.008), (-0.094, -0.02 + k * 0.022, 0.06), m["glow_orange"], bevel=0.0)
    # rear segments with a glowing coolant ring
    cyl(0.104, 0.2, (0, -0.2, 0.03), m["grey"], axis="Y", verts=8, bevel=0.012)
    cyl(0.094, 0.21, (0, -0.42, 0.035), m["grey"], axis="Y", verts=8, bevel=0.012)
    cyl(0.1, 0.014, (0, -0.31, 0.032), m["glow_cyan"], axis="Y", verts=8, bevel=0.0)
    cyl(0.07, 0.03, (0, -0.535, 0.035), m["polymer"], axis="Y", verts=24)
    box((0.07, 0.12, 0.014), (0, -0.2, 0.136), m["polymer"], bevel=0.004)
    for sx in (-1, 1):
        box((0.01, 0.1, 0.03), (sx * 0.098, -0.42, 0.04), m["polymer"], bevel=0.004)
    # grips, fore brace and shoulder rest
    box((0.044, 0.066, 0.16), (0, -0.02, -0.15), m["polymer"], rot=(14, 0, 0), bevel=0.01)
    torus(0.03, 0.005, (0, 0.045, -0.105), m["gunmetal"], rot=(0, 90, 0), scale=(1, 1.3, 1))
    box((0.048, 0.075, 0.15), (0, 0.25, -0.16), m["polymer"], rot=(-10, 0, 0), bevel=0.01)
    box((0.028, 0.3, 0.018), (0, 0.115, -0.235), m["polymer"], bevel=0.006)
    box((0.07, 0.2, 0.06), (0, -0.26, -0.085), m["gunmetal"], bevel=0.014)
    box((0.09, 0.03, 0.11), (0, -0.52, -0.05), m["polymer"], bevel=0.012)


# ----------------------------------------------------------------------------- grenades
def build_frost_stasis():
    m = M()
    lathe([(0.0, -0.08), (0.046, -0.08), (0.05, -0.075), (0.05, -0.055), (0.046, -0.05)], m["polymer"], name="Base")
    for k in range(4):                                                        # ribbed foot
        cyl(0.0485, 0.004, (0, 0, -0.072 + k * 0.006), m["gunmetal"], verts=40, bevel=0.0)
    lathe([(0.0, -0.05), (0.045, -0.05), (0.046, -0.045), (0.046, -0.005), (0.043, 0.0)], m["grey"], name="Mid")
    box((0.03, 0.002, 0.02), (0, -0.0465, -0.025), m["polymer"], bevel=0.0)   # label plate
    cyl(0.034, 0.045, (0, 0, 0.022), m["glass_cyan"], verts=40, bevel=0.0)    # cryo tube
    cyl(0.018, 0.045, (0, 0, 0.022), m["glow_cyan"], verts=24, bevel=0.0)
    lathe([(0.0, 0.043), (0.047, 0.043), (0.048, 0.047), (0.048, 0.062), (0.04, 0.068), (0.0, 0.068)], m["polymer"], name="Collar")
    around(8, 0.0485, 0.055, lambda x, y, z, a: sphere(0.0045, (x, y, z), m["glow_cyan"], 10, 6))
    around(8, 0.0465, -0.012, lambda x, y, z, a: sphere(0.004, (x, y, z), m["glow_cyan"], 10, 6))
    lathe([(0.0, 0.068), (0.03, 0.068), (0.032, 0.072), (0.03, 0.084), (0.0, 0.086)], m["steel"], name="Cap")
    lever_and_ring(m, 0.086, 0.048, m["polymer"], m["steel"])


def build_scarlet_fuse():
    m = M()
    lathe([(0.0, -0.085), (0.044, -0.085), (0.048, -0.08), (0.048, -0.072)], m["red"], name="Foot")
    lathe([(0.048, -0.072), (0.05, -0.068), (0.05, -0.035), (0.046, -0.03)], m["gunmetal"], name="Lower")
    cyl(0.0505, 0.006, (0, 0, -0.052), m["red"], verts=40, bevel=0.0)
    lathe([(0.0, -0.03), (0.04, -0.03), (0.038, -0.025), (0.038, 0.02), (0.04, 0.025), (0.0, 0.025)], m["steel_dark"], name="Waist")
    for k in range(6):                                                        # exposed core fins
        a = k * math.pi / 3.0
        box((0.006, 0.012, 0.04), (0.04 * math.cos(a), 0.04 * math.sin(a), -0.003), m["gunmetal"], rot=(0, 0, math.degrees(a) + 90), bevel=0.001)
    around(3, 0.0385, 0.0, lambda x, y, z, a: box((0.003, 0.008, 0.012), (x, y, z), m["glow_red"], rot=(0, 0, a), bevel=0.0))
    lathe([(0.046, 0.025), (0.05, 0.03), (0.05, 0.062), (0.046, 0.068), (0.0, 0.068)], m["gunmetal"], name="Upper")
    cyl(0.0505, 0.006, (0, 0, 0.046), m["red"], verts=40, bevel=0.0)
    # fuse head: offset housing, dial, lever, ring
    box((0.06, 0.07, 0.03), (0, 0.004, 0.082), m["gunmetal"], bevel=0.006, taper=(0.85, 0.8))
    cyl(0.016, 0.012, (0, -0.012, 0.102), m["red"], verts=24)
    cyl(0.009, 0.014, (0, -0.012, 0.103), m["glow_red"], verts=16, bevel=0.0)
    box((0.02, 0.04, 0.008), (0, 0.03, 0.1), m["red"], bevel=0.002)
    box((0.02, 0.007, 0.085), (0, 0.058, 0.055), m["red"], rot=(-5, 0, 0), bevel=0.002)
    torus(0.02, 0.003, (0.0, 0.066, 0.045), m["red"], rot=(0, 90, 0), scale=(1, 0.75, 1.25))


def build_cinder_canister():
    m = M()
    lathe([(0.0, -0.08), (0.047, -0.08), (0.05, -0.076), (0.05, -0.058), (0.044, -0.055)], m["polymer"], name="Base")
    cyl(0.04, 0.02, (0, 0, -0.046), m["gunmetal"], verts=40, bevel=0.0)        # vent throat
    around(3, 0.041, -0.046, lambda x, y, z, a: box((0.006, 0.03, 0.012), (x, y, z), m["glow_orange"], rot=(0, 0, a), bevel=0.001), start=0.5)
    lathe([(0.0, -0.036), (0.045, -0.036), (0.047, -0.032), (0.047, 0.02), (0.045, 0.024)], m["white"], name="Body")
    around(14, 0.0472, -0.024, lambda x, y, z, a: sphere(0.0028, (x, y, z), m["polymer"], 8, 5))
    box((0.034, 0.002, 0.018), (0, -0.0475, 0.0), m["polymer"], bevel=0.0)    # FG label
    lathe([(0.045, 0.024), (0.05, 0.028), (0.05, 0.046), (0.046, 0.05), (0.0, 0.05)], m["polymer"], name="Collar")
    around(10, 0.0502, 0.037, lambda x, y, z, a: box((0.002, 0.01, 0.003), (x, y, z), m["white"], rot=(0, 0, a), bevel=0.0))
    lathe([(0.0, 0.05), (0.038, 0.05), (0.04, 0.054), (0.04, 0.066), (0.03, 0.072), (0.0, 0.072)], m["gunmetal"], name="Cap")
    box((0.03, 0.06, 0.012), (0, 0.006, 0.08), m["polymer"], bevel=0.004)     # lever housing
    box((0.022, 0.006, 0.07), (0, 0.045, 0.045), m["polymer"], rot=(-8, 0, 0), bevel=0.002)
    torus(0.016, 0.0028, (0.0, -0.035, 0.085), m["steel"], rot=(90, 0, 0), scale=(1.15, 1, 1))


def build_sol_orb():
    m = M()
    sphere(0.045, (0, 0, 0), m["glow_orange"], 32, 16)
    core = sphere(0.03, (0, 0, 0), m["glow_white"], 24, 12)
    cage = ico(0.056, (0, 0, 0), m["glow_gold"], subdiv=1)
    w = cage.modifiers.new("Wire", "WIREFRAME")
    w.thickness = 0.006
    w.use_replace = True
    torus(0.07, 0.004, (0, 0, -0.005), m["glow_gold"], rot=(68, 0, 25))       # trailing flare
    for k, (h, r, tilt) in enumerate(((0.05, 0.016, 0), (0.038, 0.012, 22), (0.032, 0.01, -24))):
        c = cyl(r, h, (math.sin(math.radians(tilt)) * 0.03, 0, 0.062 + h * 0.4), m["glow_white"] if k == 0 else m["glow_orange"], verts=12, r2=0.0, bevel=0.0)
        c.rotation_euler = Euler((0, math.radians(tilt), 0))


def build_void_orb():
    m = M()
    sphere(0.055, (0, 0, 0), m["gunmetal"], 40, 20, scale=(1, 1, 0.94))
    cyl(0.0565, 0.014, (0, 0, 0), m["steel_dark"], verts=48, bevel=0.002)      # equator band
    for z in (-0.024, 0.024):
        torus(0.049, 0.0075, (0, 0, z), m["steel"])                           # knurled bands
        around(8, 0.056, z, lambda x, y, zz, a: sphere(0.0048, (x, y, zz), m["glow_violet"], 12, 8))
    for z, s in ((0.043, 1), (-0.043, -1)):                                   # polar slots
        around(4, 0.03, z, lambda x, y, zz, a: box((0.02, 0.006, 0.006), (x, y, zz), m["glow_violet"], rot=(0, -40 * s, a), bevel=0.002), start=math.pi / 4)
    around(6, 0.0565, 0.0, lambda x, y, z, a: box((0.004, 0.014, 0.016), (x, y, z), m["gunmetal"], rot=(0, 0, a), bevel=0.001))


def build_sunstone():
    m = M()
    shell = ico(0.062, (0, 0, 0.004), m["crystal"], subdiv=1, scale=(1.0, 1.0, 1.12))
    for v in shell.data.vertices:                                             # pointed crown, flat foot
        if v.co.z > 0.05:
            v.co.z += 0.012
            v.co.x *= 0.7
            v.co.y *= 0.7
        if v.co.z < -0.04:
            v.co.z = -0.058
    core = ico(0.026, (0, 0, -0.008), m["glow_red"], subdiv=2)
    for i, v in enumerate(core.data.vertices):                                # jagged ember
        k = 0.7 + 0.6 * ((i * 37) % 11) / 10.0
        v.co *= k
    ico(0.014, (0.0, 0.0, -0.034), m["glow_orange"], subdiv=1, scale=(1.6, 1.4, 0.7))
    for k, (x, y, z, r) in enumerate(((0.012, 0.008, 0.012, 0.007), (-0.014, 0.004, 0.008, 0.006), (0.003, -0.013, 0.016, 0.005))):
        ico(r, (x, y, z), m["glow_orange"] if k % 2 == 0 else m["glow_gold"], subdiv=0, scale=(0.5, 0.5, 1.6))
    cyl(0.05, 0.004, (0, 0, -0.06), m["crystal"], verts=12, bevel=0.0, smooth=False)


def build_hellfire_mine():
    m = M()
    lathe([(0.0, 0.0), (0.3, 0.0), (0.31, 0.012), (0.31, 0.05), (0.285, 0.075), (0.21, 0.08), (0.2, 0.06), (0.0, 0.06)], m["olive"], steps=64, bevel=0.003, name="Shell")
    cyl(0.2, 0.012, (0, 0, 0.056), m["gunmetal"], verts=64, bevel=0.0)        # well floor
    for k in range(12):                                                       # glowing core segments
        a = 2.0 * math.pi * k / 12
        box((0.105, 0.046, 0.012), (0.125 * math.cos(a), 0.125 * math.sin(a), 0.066), m["glow_orange"], rot=(0, 0, math.degrees(a)), bevel=0.002, taper=(0.55, 1.0), taper_axis="X")
    for k in range(12):                                                       # spokes
        a = 2.0 * math.pi * (k + 0.5) / 12
        box((0.12, 0.008, 0.018), (0.125 * math.cos(a), 0.125 * math.sin(a), 0.068), m["gunmetal"], rot=(0, 0, math.degrees(a)), bevel=0.001)
    torus(0.19, 0.008, (0, 0, 0.072), m["gunmetal"])
    for k in range(7):                                                        # ribbed hub
        cyl(0.055 if k % 2 == 0 else 0.05, 0.012, (0, 0, 0.07 + k * 0.012), m["steel"], verts=40, bevel=0.001)
    cyl(0.04, 0.012, (0, 0, 0.158), m["steel_dark"], verts=40)
    torus(0.026, 0.004, (0, 0, 0.166), m["glow_orange"])
    for k in range(6):                                                        # feet with LEDs
        a = 2.0 * math.pi * k / 6
        x, y = 0.33 * math.cos(a), 0.33 * math.sin(a)
        box((0.17, 0.15, 0.075), (x, y, 0.0375), m["olive"], rot=(0, 0, math.degrees(a)), bevel=0.012, taper=(0.55, 0.45), taper_axis="X")
        box((0.05, 0.05, 0.02), (0.3 * math.cos(a), 0.3 * math.sin(a), 0.08), m["gunmetal"], rot=(0, 0, math.degrees(a)), bevel=0.004)
        if k % 3 == 0:
            box((0.012, 0.03, 0.008), (0.395 * math.cos(a), 0.395 * math.sin(a), 0.03), m["glow_green"], rot=(0, 0, math.degrees(a)), bevel=0.0)
    for k in range(4):                                                        # arming panels, tilted open
        a = 2.0 * math.pi * k / 4 + math.pi / 4
        px, py = 0.215 * math.cos(a), 0.215 * math.sin(a)
        p = box((0.01, 0.1, 0.09), (0, 0, 0.045), m["gunmetal"], bevel=0.003, taper=(1.0, 0.6), taper_axis="Z")
        p.rotation_euler = Euler((0, math.radians(32), a), "ZYX")
        p.location = (px, py, 0.08 + 0.038)


WEAPONS = {
    "oathkeeper": build_oathkeeper,
    "sunblaze": build_sunblaze,
    "skyfall": build_skyfall,
    "frost_stasis": build_frost_stasis,
    "scarlet_fuse": build_scarlet_fuse,
    "cinder_canister": build_cinder_canister,
    "sol_orb": build_sol_orb,
    "void_orb": build_void_orb,
    "sunstone": build_sunstone,
    "hellfire_mine": build_hellfire_mine,
}


# ----------------------------------------------------------------------------- export / preview
def export(name):
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    return path


def render(name):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    centre = (lo + hi) * 0.5
    size = max((hi - lo).length, 0.05)
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = centre + Vector((1.0, -1.25, 0.7)).normalized() * size * 2.3
    direction = centre - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 70
    cam_data.clip_start = 0.005
    bpy.context.scene.camera = cam
    for loc, energy in (((1.5, -1.5, 2.0), 3.0), ((-2.0, -0.5, 1.0), 1.2)):
        ld = bpy.data.lights.new("Sun", "SUN")
        ld.energy = energy
        lo_obj = bpy.data.objects.new("Sun", ld)
        bpy.context.collection.objects.link(lo_obj)
        lo_obj.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.use_bloom = True
    scene.eevee.bloom_intensity = 0.03
    scene.eevee.use_gtao = True
    scene.eevee.use_ssr = True
    scene.render.resolution_x = 720
    scene.render.resolution_y = 480
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("W") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.11, 0.115, 0.125, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.render.filepath = os.path.join(RENDER_DIR, name + ".png")
    bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    if RENDER_DIR:
        os.makedirs(RENDER_DIR, exist_ok=True)
    for name, fn in WEAPONS.items():
        clear_scene()
        fn()
        export(name)
        if RENDER_DIR:
            render(name)
        print("BUILT", name)


main()
