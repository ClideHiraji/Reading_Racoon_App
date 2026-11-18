"""Option C ("Little reader") as a 3D model, toon-shaded with an ink outline.

Run with Blender (background, no UI):
    blender -b --factory-startup -P racoon_3d.py -- <out_dir>

Builds the model from simple shapes sized off the 2D drawing (make_racoons.py,
option C), with every measurement in the table P below: 1 Blender unit = 100 px
of the 400 px drawing, feet on the ground (2D y = 378 is z = 0). Then it renders
transparent PNGs, writes checks.json and saves racoon_C.blend:

- front_match: framed exactly like the 2D drawing (800 x 800, 2 px per 2D px),
  for overlaying the two pixel for pixel
- front, side, back, three_quarter: the turnaround

Toon look: each colour has three flat tones (shade, base, light) picked by how
much light a surface gets (EEVEE's Shader to RGB). Ink outline: every part gets
a slightly larger, inside-out copy in dark ink that only shows at its edges
(the "inverted hull"). The face markings are an anti-aliased texture projected
from the front, so their edges stay as clean as the 2D drawing's.
"""
import json
import math
import os
import sys
import time

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "3d")
os.makedirs(OUT, exist_ok=True)

# --- every measurement, in Blender units (100 px of the 2D drawing) --------------------------

P = {
    "outline": 0.045,                      # ink width
    "head_c": (0.0, 0.0, 2.08), "head_r": (1.08, 0.95, 0.92),
    "ear_base": (0.575, 2.52), "ear_r": 0.44, "ear_h": 0.82, "ear_tip": 0.13, "ear_flat": 0.7,
    "ear_tilt": 24, "ear_back": 8, "ear_turn": 14, "ear_outline": 0.055,
    "ear_in_r": 0.25, "ear_in_h": 0.50, "ear_in_tip": 0.08, "ear_in_y": -0.15, "ear_in_along": 0.28, "ear_in_flat": 0.45,
    "eye_x": 0.42, "eye_z": 2.05, "eye_r": 0.16, "pupil_r": 0.10, "shine_r": 0.036,
    "muzzle_c": (0.0, -0.80, 1.70), "muzzle_r": (0.40, 0.28, 0.28),
    "nose_c": (0.0, -1.07, 1.86), "nose_r": (0.13, 0.08, 0.09),
    "smile_y": -1.10, "smile_z": 1.66, "smile_w": 0.15,
    "body_c": (0.0, 0.0, 0.62), "body_r": (0.70, 0.62, 0.64),
    "belly_c": (0.0, -0.42, 0.52), "belly_r": (0.44, 0.24, 0.42),
    "foot_x": 0.30, "foot_c": (-0.12, 0.10), "foot_r": (0.25, 0.32, 0.13),
    "scarf_z": 1.19, "scarf_R": 0.62, "scarf_r": 0.16, "scarf_scale": (1.0, 0.9, 0.56), "scarf_dip": 8,
    "knot_c": (0.36, -0.62, 0.98), "knot_r": (0.13, 0.09, 0.12),
    "tail": ((0.36, 0.34, 0.48), (1.42, 0.5, 0.36), (1.22, 0.38, 1.74)),
    "tail_r": (0.2, 0.4, 0.24), "tail_rings": ((0.36, 0.48), (0.62, 0.74), (0.86, 1.01)),
    "book_c": (0.0, -0.80, 0.46), "book_tilt": -32, "book_open": 16,
    "cover": (0.70, 0.05, 0.64), "page": (0.64, 0.04, 0.56),
    "arm": ((0.56, -0.10, 0.92), (0.66, -0.36, 0.62), (0.62, -0.72, 0.54)), "arm_r": 0.13,
    "paw_c": (0.62, -0.80, 0.54), "paw_r": (0.15, 0.14, 0.15),
}

INK = "#3b2d3a"
FRAME_Z = 1.78          # the 2D drawing's centre (y = 200 px) in Blender z
FRAME = 4.0             # the 2D drawing's 400 px


def lin(hexc):
    h = hexc.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


# --- scene ----------------------------------------------------------------------------------

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 800
scene.view_settings.view_transform = "Standard"
try:
    scene.eevee.taa_render_samples = 32
except AttributeError:
    pass
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
scene.world = world

sun_data = bpy.data.lights.new("Sun", type="SUN")
sun_data.energy = 3.0
sun_data.use_shadow = False
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)


# --- toon materials -------------------------------------------------------------------------

_mats = {}


def toon(name, shade, base, light):
    """Three flat tones by light: shade, base, light."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, lin(shade)
    els[1].position, els[1].color = 0.22, lin(base)
    e = els.new(0.62)
    e.color = lin(light)
    nt.links.new(diffuse.outputs[0], to_rgb.inputs[0])
    nt.links.new(to_rgb.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], emit.inputs[0])
    nt.links.new(emit.outputs[0], out.inputs[0])
    _mats[name] = m
    return m


def flat(name, color):
    """One flat colour, unaffected by light (eyes, mouth, highlights, outline)."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit.inputs[0].default_value = lin(color)
    nt.links.new(emit.outputs[0], out.inputs[0])
    _mats[name] = m
    return m


FUR = toon("fur", "#716a80", "#8e8899", "#aaa4b6")
FUR_DARK = toon("fur_dark", "#4a4553", "#5d5766", "#736c7d")
MASK = toon("mask", "#2c2431", "#3a2f40", "#4a3e52")
CREAM = toon("cream", "#e6d2b8", "#fbf3e4", "#fffbf2")
EAR_IN = toon("ear_in", "#d99c8c", "#eab3a3", "#f4c8bb")
TEAL = toon("teal", "#1d7166", "#2a9d8f", "#45b8a9")
TEAL_DEEP = toon("teal_deep", "#155a51", "#1d7166", "#2a8a7d")
COVER = toon("cover", "#bd6212", "#e9801f", "#f29a45")
PAGE = toon("page", "#efe6cf", "#fffef4", "#ffffff")
NOSE = flat("nose", "#2d2430")
MOUTH = flat("mouth", "#6b2f36")
TONGUE = flat("tongue", "#e9801f")
CREAM_FLAT = flat("cream_flat", "#fbf3e4")
EYE_DARK = flat("eye_dark", "#221a26")
WHITE = flat("white", "#ffffff")
LINES = flat("lines", "#9a8a7a")
INK_MAT = flat("ink", INK)
INK_MAT.use_backface_culling = True
try:
    INK_MAT.use_backface_culling_shadow = True
except AttributeError:
    pass


# --- building blocks ------------------------------------------------------------------------

def link(obj):
    scene.collection.objects.link(obj)
    return obj


def ellipsoid(name, center, radii, mats, seg=48, rings=24):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    obj = link(bpy.data.objects.new(name, me))
    obj.location = center
    for m in mats:
        me.materials.append(m)
    return obj


def outline(obj, width=None):
    """Ink: an inside-out shell a little bigger than the part, seen only at its edges."""
    obj.data.materials.append(INK_MAT)
    mod = obj.modifiers.new("Ink", "SOLIDIFY")
    mod.thickness = P["outline"] if width is None else width
    mod.offset = 1.0
    mod.use_flip_normals = True
    mod.use_rim = False
    mod.material_offset = len(obj.data.materials) - 1
    return obj


def tube(name, path_fn, radius_fn, mat_fn, mats, n=48, sides=32, cap_rings=6):
    """A swept tube along path_fn(t), t in 0..1, radius_fn(t), a material per ring band."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    up = Vector((0, 0, 1))
    pts = [path_fn(i / n) for i in range(n + 1)]
    for i in range(n + 1):
        t = i / n
        p = pts[i]
        d = (pts[min(n, i + 1)] - pts[max(0, i - 1)]).normalized()
        side = d.cross(up)
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        nrm = side.cross(d).normalized()
        r = radius_fn(t)
        ring = [bm.verts.new(p + (side * math.cos(a) + nrm * math.sin(a)) * r)
                for a in (math.tau * k / sides for k in range(sides))]
        rings.append((t, ring, d))
    pe, de = pts[-1], rings[-1][2]       # rounded tip
    re = radius_fn(1.0)
    last = rings[-1][1]
    for k in range(1, cap_rings + 1):
        a = (math.pi / 2) * k / cap_rings
        ring = [bm.verts.new(pe + de * math.sin(a) * re + (v.co - pe) * math.cos(a)) for v in last]
        rings.append((1.0, ring, de))
    tip = bm.verts.new(pe + de * re)
    for j in range(len(rings) - 1):
        t, a_ring, _ = rings[j]
        _, b_ring, _ = rings[j + 1]
        for k in range(sides):
            f = bm.faces.new((a_ring[k], a_ring[(k + 1) % sides], b_ring[(k + 1) % sides], b_ring[k]))
            f.material_index = mat_fn(t)
            f.smooth = True
    for k in range(sides):
        f = bm.faces.new((rings[-1][1][k], rings[-1][1][(k + 1) % sides], tip))
        f.material_index = mat_fn(1.0)
        f.smooth = True
    base = bm.faces.new(list(reversed(rings[0][1])))
    base.material_index = mat_fn(0.0)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me))
    for m in mats:
        me.materials.append(m)
    return obj


def quad(a, b, c):
    a, b, c = Vector(a), Vector(b), Vector(c)
    return lambda t: (1 - t) ** 2 * a + 2 * (1 - t) * t * b + t * t * c


def box(name, size, mat, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me))
    obj.location = loc
    me.materials.append(mat)
    return obj


def cone(name, r, h, mat, tip=0.06):
    """A cone with a rounded tip (tip = the top radius before smoothing)."""
    obj = link(bpy.data.objects.new(name, bpy.data.meshes.new(name)))
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=r, radius2=tip, depth=h)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.append(mat)
    sub = obj.modifiers.new("Round", "SUBSURF")
    sub.levels = sub.render_levels = 2
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def curve_line(name, points, mat, depth=0.014):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = depth
    cu.bevel_resolution = 4
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    cu.materials.append(mat)
    return link(bpy.data.objects.new(name, cu))


def poly_line(name, points, mat, depth, closed=False):
    """A line through sampled points: follows a drawn curve exactly, with closed ends."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = depth
    cu.bevel_resolution = 2
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for pt, p in zip(sp.points, points):
        pt.co = (p[0], p[1], p[2], 1.0)
    sp.use_cyclic_u = closed
    cu.materials.append(mat)
    return link(bpy.data.objects.new(name, cu))


# --- the face: markings as a texture projected from the front ------------------------------

HEAD = Vector(P["head_c"])
HR = P["head_r"]


def face_image(res=1024):
    """The face's markings as an anti-aliased RGBA image, projected from the front:
    x in -1.15..1.15 and z in 1.1..3.1 (world units). Same shapes as the 2D drawing."""
    import numpy as np
    ss = 2
    n = res * ss
    xs = np.linspace(-1.15, 1.15, n)
    zs = np.linspace(1.1, 3.1, n)
    x, z = np.meshgrid(xs, zs)
    ax = np.abs(x)
    rgba = np.zeros((n, n, 4), dtype=np.float32)

    def paint(where, hexc, alpha=1.0):
        h = hexc.lstrip("#")
        col = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
        a = where.astype(np.float32) * alpha
        for c in range(3):
            rgba[..., c] = rgba[..., c] * (1 - a) + col[c] * a
        rgba[..., 3] = rgba[..., 3] * (1 - a) + a

    paint((x / 0.5) ** 2 + ((z - 1.66) / 0.34) ** 2 <= 1, "#fbf3e4")
    for sx in (-1, 1):
        paint(((x - sx * 0.70) / 0.15) ** 2 + ((z - 1.74) / 0.085) ** 2 <= 1, "#f08c78", 0.5)
    u = ax / 0.93
    h = 0.29 * np.sqrt(np.clip(1 - u ** 2.2, 0, None)) * (0.62 + 0.38 * np.minimum(1.0, ax / (0.93 * 0.42)))
    zc = 2.06 - 0.04 - 0.11 * u ** 2
    paint((u <= 1) & (np.abs(z - zc) < h), "#3a2f40")
    for sx in (-1, 1):
        a = np.radians(10 * sx)
        dx, dz = x - sx * 0.41, z - 2.43
        bu = dx * np.cos(a) + dz * np.sin(a)
        bw = -dx * np.sin(a) + dz * np.cos(a)
        paint((bu / 0.23) ** 2 + (bw / 0.085) ** 2 <= 1, "#fbf3e4")
    a = np.radians(22)
    dx, dz = x + 0.454, z - 2.65
    hu = dx * np.cos(a) + dz * np.sin(a)
    hw = -dx * np.sin(a) + dz * np.cos(a)
    paint((hu / 0.26) ** 2 + (hw / 0.11) ** 2 <= 1, "#ffffff", 0.28)
    small = rgba.reshape(res, ss, res, ss, 4).mean(axis=(1, 3))
    img = bpy.data.images.new("Face", res, res, alpha=True)
    img.alpha_mode = "STRAIGHT"
    img.pixels.foreach_set(small.ravel())
    img.pack()
    return img


def head_material():
    """Fur painted with the face texture on the front only, in the same three toon tones."""
    m = bpy.data.materials.new("head")
    m.use_nodes = True
    nt = m.node_tree
    for n_ in list(nt.nodes):
        nt.nodes.remove(n_)
    N = nt.nodes.new
    L = nt.links.new

    def sock(node, ident, out=False):
        return next(s_ for s_ in (node.outputs if out else node.inputs) if s_.identifier == ident)

    def math_node(op, b):
        node = N("ShaderNodeMath")
        node.operation = op
        node.inputs[1].default_value = b
        return node

    tc = N("ShaderNodeTexCoord")
    sep = N("ShaderNodeSeparateXYZ")
    L(tc.outputs["Object"], sep.inputs[0])
    u_add, u_div = math_node("ADD", 1.15), math_node("DIVIDE", 2.3)
    v_add, v_div = math_node("ADD", HEAD.z - 1.1), math_node("DIVIDE", 2.0)
    L(sep.outputs["X"], u_add.inputs[0])
    L(u_add.outputs[0], u_div.inputs[0])
    L(sep.outputs["Z"], v_add.inputs[0])
    L(v_add.outputs[0], v_div.inputs[0])
    comb = N("ShaderNodeCombineXYZ")
    L(u_div.outputs[0], comb.inputs["X"])
    L(v_div.outputs[0], comb.inputs["Y"])
    tex = N("ShaderNodeTexImage")
    tex.image = face_image()
    tex.extension = "CLIP"
    L(comb.outputs[0], tex.inputs["Vector"])
    geo = N("ShaderNodeNewGeometry")
    nsep = N("ShaderNodeSeparateXYZ")
    L(geo.outputs["Normal"], nsep.inputs[0])
    facing = math_node("MULTIPLY", -3.0)
    facing.use_clamp = True
    L(nsep.outputs["Y"], facing.inputs[0])
    fac = N("ShaderNodeMath")
    fac.operation = "MULTIPLY"
    L(tex.outputs["Alpha"], fac.inputs[0])
    L(facing.outputs[0], fac.inputs[1])
    mix = N("ShaderNodeMix")
    mix.data_type = "RGBA"
    L(fac.outputs[0], sock(mix, "Factor_Float"))
    sock(mix, "A_Color").default_value = lin("#8e8899")
    L(tex.outputs["Color"], sock(mix, "B_Color"))
    diffuse = N("ShaderNodeBsdfDiffuse")
    to_rgb = N("ShaderNodeShaderToRGB")
    ramp = N("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (0.80, 0.80, 0.80, 1)
    els[1].position, els[1].color = 0.22, (1.0, 1.0, 1.0, 1)
    e_ = els.new(0.62)
    e_.color = (1.14, 1.14, 1.14, 1)
    L(diffuse.outputs[0], to_rgb.inputs[0])
    L(to_rgb.outputs[0], ramp.inputs[0])
    tone = N("ShaderNodeMix")
    tone.data_type = "RGBA"
    tone.blend_type = "MULTIPLY"
    sock(tone, "Factor_Float").default_value = 1.0
    L(sock(mix, "Result_Color", out=True), sock(tone, "A_Color"))
    L(ramp.outputs["Color"], sock(tone, "B_Color"))
    emit = N("ShaderNodeEmission")
    out = N("ShaderNodeOutputMaterial")
    L(sock(tone, "Result_Color", out=True), emit.inputs[0])
    L(emit.outputs[0], out.inputs[0])
    return m


def surface_y(x, z):
    k = 1 - (x / HR[0]) ** 2 - ((z - HEAD.z) / HR[2]) ** 2
    return -HR[1] * math.sqrt(max(0.0, k))


# --- the model ------------------------------------------------------------------------------

outline(ellipsoid("Head", HEAD, HR, [head_material()], seg=64, rings=32))
ellipsoid("Muzzle", P["muzzle_c"], P["muzzle_r"], [CREAM])   # no ink, like the 2D muzzle
outline(ellipsoid("Nose", P["nose_c"], P["nose_r"], [NOSE], 32, 16), 0.02)
nc = P["nose_c"]
ellipsoid("NoseShine", (nc[0] - 0.04, nc[1] - 0.06, nc[2] + 0.04), (0.045, 0.02, 0.025), [WHITE], 16, 8)
sw, sy, sz = P["smile_w"], P["smile_y"], P["smile_z"]
IDLE, HAPPY = [], []     # the pieces each mood shows
IDLE.append(curve_line("Smile", [(-sw, sy + 0.025, sz + 0.03), (-sw / 2, sy, sz - 0.04), (0.0, sy - 0.005, sz + 0.02),
                                 (sw / 2, sy, sz - 0.04), (sw, sy + 0.025, sz + 0.03)], NOSE))
# happy: the 2D drawing's open "D" mouth (flat top, round bottom) with a tongue, laid on the muzzle
mc, mr = P["muzzle_c"], P["muzzle_r"]


def muzzle_y(x, z):
    k = 1 - (x / mr[0]) ** 2 - ((z - mc[2]) / mr[2]) ** 2
    return mc[1] - mr[1] * math.sqrt(max(0.0, k))


def d_shape(half_w, z_top, z_bot, n=24):
    top = [(-half_w + 2 * half_w * i / n, z_top) for i in range(n + 1)]
    bottom = [(half_w - 2 * half_w * i / n, z_top - (z_top - z_bot) * (1 - ((half_w - 2 * half_w * i / n) / half_w) ** 2))
              for i in range(1, n)]
    return top + bottom


def on_muzzle(name, pts, mat, lift):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((x, muzzle_y(x, z) - lift, z)) for x, z in pts]
    bm.faces.new(verts)
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me))
    me.materials.append(mat)
    return obj


mouth_pts = d_shape(0.138, 1.692, 1.591)
HAPPY.append(on_muzzle("MouthOpen", mouth_pts, MOUTH, 0.010))
tongue = [(0.064 * math.cos(math.tau * i / 32), 1.606 + 0.035 * math.sin(math.tau * i / 32)) for i in range(32)]
HAPPY.append(on_muzzle("Tongue", tongue, TONGUE, 0.014))
rim = [(x, muzzle_y(x, z) - 0.016, z) for x, z in mouth_pts[::2]]
HAPPY.append(poly_line("MouthRim", rim, NOSE, 0.011, closed=True))

for sx in (-1, 1):
    ex, ez = sx * P["eye_x"], P["eye_z"]
    ey = surface_y(ex, ez)
    er, pr, shr = P["eye_r"], P["pupil_r"], P["shine_r"]
    IDLE.append(ellipsoid(f"EyeWhite{sx}", (ex, ey + 0.02, ez), (er, 0.05, er), [CREAM], 32, 16))
    IDLE.append(ellipsoid(f"Pupil{sx}", (ex, ey - 0.03, ez - 0.01), (pr, 0.03, pr), [EYE_DARK], 32, 16))
    IDLE.append(ellipsoid(f"Shine{sx}", (ex - 0.035, ey - 0.06, ez + 0.035), (shr, 0.012, shr), [WHITE], 16, 8))
    # happy: closed ^^ eyes, the 2D drawing's cream arch (ends 0.11 out, rising 0.08)
    arch = []
    for i in range(13):
        t = i / 12
        ax_ = ex - 0.11 + 0.22 * t
        az_ = (1 - t) ** 2 * (ez - 0.054) + 2 * (1 - t) * t * (ez + 0.112) + t * t * (ez - 0.054)
        arch.append((ax_, surface_y(ax_, az_) - 0.03, az_))
    HAPPY.append(poly_line(f"HappyEye{sx}", arch, CREAM_FLAT, 0.027))
    # each ear leans out from its base, like the 2D drawing's
    tilt = math.radians(P["ear_tilt"])
    axis = (sx * math.sin(tilt), math.cos(tilt))
    bx, bz = P["ear_base"]
    ear = cone(f"Ear{sx}", P["ear_r"], P["ear_h"], FUR, P["ear_tip"])
    ear.location = (sx * bx + axis[0] * P["ear_h"] / 2, 0.0, bz + axis[1] * P["ear_h"] / 2)
    ear.scale = (1.0, P["ear_flat"], 1.0)
    ear.rotation_euler = (math.radians(P["ear_back"]), tilt * sx, math.radians(P["ear_turn"] * sx))
    outline(ear, P["ear_outline"])   # the ear is flattened, so its shell is set a little wider
    inner = cone(f"EarIn{sx}", P["ear_in_r"], P["ear_in_h"], EAR_IN, P["ear_in_tip"])
    inner.location = (sx * bx + axis[0] * P["ear_in_along"], P["ear_in_y"], bz + axis[1] * P["ear_in_along"])
    inner.scale = (1.0, P["ear_in_flat"], 1.0)
    inner.rotation_euler = ear.rotation_euler

outline(ellipsoid("Body", P["body_c"], P["body_r"], [FUR]))
ellipsoid("Belly", P["belly_c"], P["belly_r"], [CREAM])
for sx in (-1, 1):
    fy, fz = P["foot_c"]
    outline(ellipsoid(f"Foot{sx}", (sx * P["foot_x"], fy, fz), P["foot_r"], [FUR_DARK]))

# scarf: a band round the neck, a knot and two hanging ends
bpy.ops.mesh.primitive_torus_add(major_radius=P["scarf_R"], minor_radius=P["scarf_r"], major_segments=48,
                                 minor_segments=12, location=(0, 0, P["scarf_z"]))
scarf = bpy.context.active_object
scarf.name = "Scarf"
scarf.scale = P["scarf_scale"]
scarf.rotation_euler = (math.radians(P["scarf_dip"]), 0, 0)
for p in scarf.data.polygons:
    p.use_smooth = True
scarf.data.materials.append(TEAL)
outline(scarf)
kc = P["knot_c"]
outline(ellipsoid("Knot", kc, P["knot_r"], [TEAL_DEEP], 24, 12))
end1 = outline(ellipsoid("ScarfEnd1", (kc[0] - 0.03, kc[1] - 0.08, kc[2] - 0.23), (0.08, 0.04, 0.22), [TEAL_DEEP], 24, 12))
end1.rotation_euler = (0, math.radians(-10), 0)
end2 = outline(ellipsoid("ScarfEnd2", (kc[0] + 0.15, kc[1] - 0.06, kc[2] - 0.17), (0.07, 0.04, 0.19), [TEAL], 24, 12))
end2.rotation_euler = (0, math.radians(-38), 0)

# tail: a smooth ringed tube rising behind on his right
r0, rmid, rtip = P["tail_r"]


def tail_radius(t):
    r = r0 + (rmid - r0) * math.sin(math.pi * min(t, 0.75) / 1.5) ** 1.2
    return r * (1 - t) + rtip * t if t > 0.75 else r


def tail_band(t):
    return 1 if any(a <= t < b for a, b in P["tail_rings"]) else 0


outline(tube("Tail", quad(*P["tail"]), tail_radius, tail_band, [FUR, MASK], n=40, sides=24))

# the open book, tipped back towards him, held at both edges
book = link(bpy.data.objects.new("Book", None))
book.location = P["book_c"]
book.rotation_euler = (math.radians(P["book_tilt"]), 0, 0)
cw, ct, ch = P["cover"]
pw, pt, ph = P["page"]
for sx in (-1, 1):
    half = link(bpy.data.objects.new(f"BookHalf{sx}", None))
    half.parent = book
    half.rotation_euler = (0, 0, math.radians(P["book_open"] * sx))
    cover = outline(box(f"Cover{sx}", (cw, ct, ch), COVER, (sx * cw / 2, 0.03, 0)), 0.03)
    page = box(f"Page{sx}", (pw, pt, ph), PAGE, (sx * (pw / 2 + 0.01), -0.01, 0.0))
    for k in range(4):
        ln = box(f"Line{sx}{k}", (pw * 0.66, 0.008, 0.018), LINES, (sx * (pw / 2 + 0.01), -0.034, ph * 0.3 - k * ph * 0.2))
        ln.parent = half
    cover.parent = half
    page.parent = half
for sx in (-1, 1):
    a, b, c = ((sx * q[0], q[1], q[2]) for q in P["arm"])
    outline(tube(f"Arm{sx}", quad(a, b, c), lambda t: P["arm_r"] * (1.15 - 0.3 * t), lambda t: 0, [FUR],
                 n=12, sides=16, cap_rings=4))
    pc = P["paw_c"]
    outline(ellipsoid(f"Paw{sx}", (sx * pc[0], pc[1], pc[2]), P["paw_r"], [FUR_DARK], 24, 12))

# a soft ground shadow
shadow_mat = bpy.data.materials.new("shadow")
shadow_mat.use_nodes = True
snt = shadow_mat.node_tree
for n_ in list(snt.nodes):
    snt.nodes.remove(n_)
s_emit = snt.nodes.new("ShaderNodeEmission")
s_emit.inputs[0].default_value = lin("#3a2a1f")
s_clear = snt.nodes.new("ShaderNodeBsdfTransparent")
s_mix = snt.nodes.new("ShaderNodeMixShader")
s_mix.inputs[0].default_value = 0.16
s_out = snt.nodes.new("ShaderNodeOutputMaterial")
snt.links.new(s_clear.outputs[0], s_mix.inputs[1])
snt.links.new(s_emit.outputs[0], s_mix.inputs[2])
snt.links.new(s_mix.outputs[0], s_out.inputs[0])
for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
    try:
        setattr(shadow_mat, attr, value)
    except (AttributeError, TypeError):
        pass
ellipsoid("Shadow", (0.12, 0.05, 0.0), (1.05, 0.75, 0.004), [shadow_mat], seg=48, rings=6)


# --- checks ---------------------------------------------------------------------------------

def tri_count(with_ink):
    inks = [m for o in scene.objects for m in o.modifiers if m.name == "Ink"]
    for m in inks:
        m.show_viewport = with_ink
    deps = bpy.context.evaluated_depsgraph_get()
    total = 0
    for o in scene.objects:
        if o.type in ("MESH", "CURVE") and o.name != "Shadow":
            ev = o.evaluated_get(deps)
            me = ev.to_mesh()
            me.calc_loop_triangles()
            total += len(me.loop_triangles)
            ev.to_mesh_clear()
    for m in inks:
        m.show_viewport = True
    return total


def out_of_frame():
    """Parts that leave the front frame (the 2D drawing's 400 x 400 px)."""
    bad = []
    lo_x, hi_x = -FRAME / 2, FRAME / 2
    lo_z, hi_z = FRAME_Z - FRAME / 2, FRAME_Z + FRAME / 2
    for o in scene.objects:
        if o.type not in ("MESH", "CURVE") or o.name == "Shadow":
            continue
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            if not (lo_x <= w.x <= hi_x and lo_z <= w.z <= hi_z):
                bad.append(o.name)
                break
    return bad


checks = {
    "blender": bpy.app.version_string,
    "engine": scene.render.engine,
    "objects": sum(1 for o in scene.objects if o.type in ("MESH", "CURVE")),
    "tris_model": tri_count(False),
    "tris_with_outline": tri_count(True),
    "out_of_frame": out_of_frame(),
    "render_s": {},
}


# --- cameras and renders --------------------------------------------------------------------

def render(name, loc, rot_deg, sun_rot_deg, scale=FRAME):
    cam_data = bpy.data.cameras.new(name)
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = scale
    cam = link(bpy.data.objects.new(name, cam_data))
    cam.location = loc
    cam.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    sun.rotation_euler = tuple(math.radians(a) for a in sun_rot_deg)
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT, f"racoon_C_3d_{name}.png")
    t0 = time.time()
    bpy.ops.render.render(write_still=True)
    checks["render_s"][name] = round(time.time() - t0, 2)


for o in HAPPY:
    o.hide_render = True
render("front_match", (0, -12, FRAME_Z), (90, 0, 0), (52, 0, -28))
render("front", (0, -12, FRAME_Z), (90, 0, 0), (52, 0, -28))
render("side", (-12, 0, FRAME_Z), (90, 0, -90), (52, 0, -118))
render("back", (0, 12, FRAME_Z), (90, 0, 180), (52, 0, 152))
render("three_quarter", (-8.5, -8.5, FRAME_Z + 1.2), (84, 0, -45), (52, 0, -60))

def show_mood(mood):
    for o in IDLE:
        o.hide_render = mood != "idle"
    for o in HAPPY:
        o.hide_render = mood != "happy"


show_mood("happy")
render("front_match_happy", (0, -12, FRAME_Z), (90, 0, 0), (52, 0, -28))
render("three_quarter_happy", (-8.5, -8.5, FRAME_Z + 1.2), (84, 0, -45), (52, 0, -60))
show_mood("idle")

with open(os.path.join(OUT, "checks.json"), "w", encoding="utf-8") as fh:
    json.dump(checks, fh, indent=1)
scene.camera = bpy.data.objects["three_quarter"]

# the moods as collections: tick "Mood happy" and untick "Mood idle" in the Outliner to swap faces
for mood, pieces in (("idle", IDLE), ("happy", HAPPY)):
    col = bpy.data.collections.new(f"Mood {mood}")
    scene.collection.children.link(col)
    for o in pieces:
        for c in o.users_collection:
            c.objects.unlink(o)
        col.objects.link(o)
        o.hide_render = False
bpy.context.view_layer.layer_collection.children["Mood happy"].exclude = True

# the file opens in the toon look: Blender turns Rendered back into Solid when it loads a file but
# keeps Material Preview, which is the same EEVEE shading when only the scene's sun lights it
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            space = area.spaces.active
            space.shading.type = "MATERIAL"
            space.shading.use_scene_lights = True
            space.shading.use_scene_world = False
            space.shading.studiolight_intensity = 0.0
            space.shading.studiolight_background_alpha = 0.0
            space.region_3d.view_perspective = "CAMERA"
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "racoon_C.blend"), compress=True)
print("CHECKS", json.dumps(checks))
print("rendered to", OUT)
