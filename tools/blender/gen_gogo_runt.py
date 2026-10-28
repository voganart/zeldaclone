# Gogo Runt (Гоголаец-малыш) — tier-1 enemy generator.
# Builds mesh, armature, weights, materials and 12 actions, exports GLB.
# Usage:
#   blender.exe -b --factory-startup -P tools/blender/gen_gogo_runt.py -- [--out PATH.glb] [--rig-json PATH.json]
# Deterministic: no random, only fixed mathutils.noise samples.
# Axes: Blender front = -Y, left (.l) = +X, up = +Z. glTF exporter (+Y up) maps
# Blender (x, y, z) -> glTF/Godot (x, z, -y), so the front ends up at Godot +Z.

import bpy
import bmesh
import json
import math
import os
import sys
from mathutils import Vector, Matrix, Quaternion, Euler, noise

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(SCRIPT_DIR, "..", ".."))
OUT_GLB = os.path.join(PROJECT, "assets", "models", "characters", "GogoRunt.glb")
PALETTE_PNG = os.path.join(PROJECT, "assets", "_master", "MasterTexture_v2.png")
RIG_JSON = None

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for i, a in enumerate(argv):
    if a == "--out":
        OUT_GLB = argv[i + 1]
    elif a == "--rig-json":
        RIG_JSON = argv[i + 1]

FPS = 30
HEIGHT_NORM = 0.95  # for UV2 gradient (toon shader gradient_uv_set = 1)

# Palette cells in MasterTexture_v2.png (pixel centers, 1024x1024)
PAL = {
    "mud": (80, 448), "mud_dark": (24, 448), "mud_light": (112, 448),
    "rust": (336, 80), "rust_dark": (336, 128),
    "metal": (232, 224), "metal_dark": (112, 224),
    "pupil": (80, 224), "wood": (368, 128), "eye": (112, 592),
}
PAL_UV = {k: (x / 1024.0, 1.0 - y / 1024.0) for k, (x, y) in PAL.items()}

MAT_BODY, MAT_EYE = 0, 1

# ---------------------------------------------------------------- skeleton
# name, head, tail, parent, deform
BONES = [
    ("c_traj", (0, 0, 0), (0, 0, 0.12), None, True),
    ("root.x", (0, 0, 0.30), (0, 0, 0.44), "c_traj", True),
    ("spine_01.x", (0, 0, 0.44), (0, 0, 0.62), "root.x", True),
    ("neck.x", (0, 0, 0.62), (0, -0.005, 0.68), "spine_01.x", True),
    ("head.x", (0, -0.005, 0.68), (0, -0.01, 0.82), "neck.x", True),
    ("wheel.x", (0, 0.27, 0.64), None, "spine_01.x", True),  # tail set from axle
]
for s, sx in (("l", 1.0), ("r", -1.0)):
    BONES += [
        ("shoulder." + s, (0.12 * sx, 0, 0.58), (0.24 * sx, 0, 0.56), "spine_01.x", True),
        ("arm_stretch." + s, (0.24 * sx, 0, 0.56), (0.31 * sx, -0.01, 0.45), "shoulder." + s, True),
        ("forearm_stretch." + s, (0.31 * sx, -0.01, 0.45), (0.34 * sx, -0.04, 0.35), "arm_stretch." + s, True),
        ("hand." + s, (0.34 * sx, -0.04, 0.35), (0.35 * sx, -0.06, 0.27), "forearm_stretch." + s, True),
        ("thigh_stretch." + s, (0.11 * sx, 0, 0.32), (0.13 * sx, -0.03, 0.19), "root.x", True),
        ("leg_stretch." + s, (0.13 * sx, -0.03, 0.19), (0.13 * sx, 0, 0.07), "thigh_stretch." + s, True),
        ("foot." + s, (0.13 * sx, 0, 0.07), (0.13 * sx, -0.10, 0.03), "leg_stretch." + s, True),
        # IK helpers (not exported: non-deform + export_def_bones)
        ("ik_foot." + s, (0.13 * sx, 0, 0.07), (0.13 * sx, -0.10, 0.03), "c_traj", False),
    ]

WHEEL_C = Vector((0, 0.27, 0.64))
WHEEL_AXLE = Vector((0.85, 0.12, 0.5)).normalized()
for i, b in enumerate(BONES):
    if b[0] == "wheel.x":
        BONES[i] = (b[0], b[1], tuple(WHEEL_C + WHEEL_AXLE * 0.1), b[3], b[4])

BONE = {b[0]: b for b in BONES}
DEFORM = [b[0] for b in BONES if b[4]]
GI = {n: i for i, n in enumerate(DEFORM)}


def V(t):
    return Vector(t)


# ---------------------------------------------------------------- weights
def body_w(co):
    z = co.z
    if z < 0.38:
        return {"root.x": 1.0}
    if z < 0.48:
        t = (z - 0.38) / 0.10
        return {"root.x": 1 - t, "spine_01.x": t}
    if z < 0.56:
        return {"spine_01.x": 1.0}
    if z < 0.66:
        t = (z - 0.56) / 0.10
        return {"spine_01.x": 1 - t, "head.x": t}
    return {"head.x": 1.0}


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def seg_w(names):
    def fn(co):
        ws = []
        for n in names:
            d = seg_dist(co, V(BONE[n][1]), V(BONE[n][2]))
            ws.append((1.0 / (d + 0.01) ** 4, n))
        ws.sort(reverse=True)
        top = ws[:2]
        s = sum(w for w, _ in top)
        return {n: w / s for w, n in top}
    return fn


def rigid(name):
    return lambda co: {name: 1.0}


# ---------------------------------------------------------------- mesh builder
class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv0 = self.bm.loops.layers.uv.new("UVMap")
        self.uv1 = self.bm.loops.layers.uv.new("UV2")
        self.dl = self.bm.verts.layers.deform.new()

    def finish(self, verts, color, mat, wfn):
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            f.material_index = mat
            f.smooth = False
            for lp in f.loops:
                lp[self.uv0].uv = PAL_UV[color]
                lp[self.uv1].uv = (0.5, max(0.0, min(1.0, lp.vert.co.z / HEIGHT_NORM)))
        for v in verts:
            for g, w in wfn(v.co).items():
                if w > 1e-4:
                    v[self.dl][GI[g]] = w

    def ico(self, center, scale, color, wfn, subdiv=2, rot=(0, 0, 0), mat=MAT_BODY, lump=0.0, seed=0.0):
        M = Matrix.Translation(V(center)) @ Euler([math.radians(r) for r in rot]).to_matrix().to_4x4()
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0, matrix=Matrix.Identity(4))
        verts = res["verts"]
        for v in verts:
            d = v.co.normalized()
            k = 1.0 + lump * noise.noise(d * 2.3 + Vector((seed, seed * 0.7, seed * 1.3)))
            local = Vector((d.x * scale[0], d.y * scale[1], d.z * scale[2])) * k
            v.co = M @ local
        self.finish(verts, color, mat, wfn)
        return verts

    def cyl(self, a, b, r1, r2, color, wfn, seg=6, mat=MAT_BODY):
        a, b = V(a), V(b)
        d = b - a
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        M = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                    radius1=r1, radius2=r2, depth=d.length, matrix=M)
        self.finish(res["verts"], color, mat, wfn)
        return res["verts"]

    def box(self, center, size, color, wfn, rot=(0, 0, 0), mat=MAT_BODY):
        M = (Matrix.Translation(V(center)) @ Euler([math.radians(r) for r in rot]).to_matrix().to_4x4()
             @ Matrix.Diagonal(Vector((size[0], size[1], size[2], 1.0))))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=M)
        self.finish(res["verts"], color, mat, wfn)
        return res["verts"]

    def torus(self, center, axis, R, r, color, wfn, seg_major=12, seg_minor=4, mat=MAT_BODY):
        q = Vector((0, 0, 1)).rotation_difference(axis)
        M = Matrix.Translation(center) @ q.to_matrix().to_4x4()
        grid = []
        for i in range(seg_major):
            a = 2 * math.pi * i / seg_major
            ring = []
            for j in range(seg_minor):
                b = 2 * math.pi * j / seg_minor + math.pi / seg_minor
                rr = R + r * math.cos(b)
                p = Vector((rr * math.cos(a), rr * math.sin(a), r * math.sin(b)))
                ring.append(self.bm.verts.new(M @ p))
            grid.append(ring)
        for i in range(seg_major):
            for j in range(seg_minor):
                i2, j2 = (i + 1) % seg_major, (j + 1) % seg_minor
                self.bm.faces.new((grid[i][j], grid[i2][j], grid[i2][j2], grid[i][j2]))
        verts = [v for ring in grid for v in ring]
        self.finish(verts, color, mat, wfn)
        return verts


def build_mesh():
    B = Builder()
    # Body: lumpy mud blob
    B.ico((0, 0, 0.52), (0.27, 0.25, 0.28), "mud", body_w, subdiv=3, lump=0.09, seed=1.7)
    for c, s, col, sd in (((0.20, 0.06, 0.36), 0.09, "mud_dark", 3.1), ((-0.19, 0.12, 0.70), 0.08, "mud_light", 4.2),
                          ((0.10, 0.20, 0.76), 0.07, "mud_dark", 5.3), ((-0.22, -0.06, 0.40), 0.08, "mud_light", 6.4)):
        B.ico(c, (s, s, s * 0.8), col, body_w, subdiv=2, lump=0.15, seed=sd)
    # Eye, pupil, brow, mouth, teeth
    B.ico((0, -0.205, 0.635), (0.10, 0.10, 0.10), "eye", body_w, subdiv=3, mat=MAT_EYE)
    B.ico((0, -0.295, 0.64), (0.045, 0.02, 0.05), "pupil", body_w, subdiv=2)
    B.ico((0.01, -0.215, 0.755), (0.135, 0.07, 0.04), "mud_dark", body_w, subdiv=2, rot=(0, -10, 0), lump=0.1, seed=7.5)
    B.box((0.0, -0.235, 0.455), (0.15, 0.03, 0.025), "pupil", body_w, rot=(0, 9, 0))
    B.box((-0.035, -0.25, 0.47), (0.025, 0.02, 0.035), "metal", body_w, rot=(0, 9, 0))
    B.box((0.04, -0.248, 0.458), (0.025, 0.02, 0.03), "metal", body_w, rot=(0, -6, 0))
    # Junk shards in the body
    B.box((0.18, 0.14, 0.58), (0.09, 0.015, 0.07), "metal_dark", body_w, rot=(20, 10, 40))
    B.box((-0.21, 0.05, 0.52), (0.015, 0.08, 0.06), "rust_dark", body_w, rot=(15, -20, 0))
    # Bent pipe on the head
    p0, p1, p2 = (0.06, 0.03, 0.74), (0.08, 0.05, 0.93), (0.19, 0.07, 0.96)
    hw = rigid("head.x")
    B.cyl(p0, p1, 0.03, 0.03, "rust", hw)
    B.box(p1, (0.07, 0.07, 0.07), "metal_dark", hw, rot=(0, 15, 10))
    B.cyl(p1, p2, 0.03, 0.03, "rust", hw)
    B.cyl(V(p2) - V((0.02, 0.004, 0.005)), V(p2) + V((0.02, 0.004, 0.005)), 0.045, 0.045, "metal", hw, seg=8)
    # Cart wheel stuck in the back
    ww = rigid("wheel.x")
    B.torus(WHEEL_C, WHEEL_AXLE, 0.15, 0.022, "wood", ww)
    B.cyl(WHEEL_C - WHEEL_AXLE * 0.05, WHEEL_C + WHEEL_AXLE * 0.05, 0.035, 0.035, "metal_dark", ww, seg=8)
    q = Vector((0, 0, 1)).rotation_difference(WHEEL_AXLE)
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        d = q @ Vector((math.cos(a), math.sin(a), 0))
        B.cyl(WHEEL_C + d * 0.03, WHEEL_C + d * 0.14, 0.012, 0.012, "wood", ww, seg=4)
    B.cyl(V((0, 0.12, 0.60)), WHEEL_C, 0.02, 0.02, "metal", rigid("spine_01.x"), seg=5)
    # Arms, fists, pipe club
    for s, sx in (("l", 1.0), ("r", -1.0)):
        aw = seg_w(["shoulder." + s, "arm_stretch." + s, "forearm_stretch." + s, "hand." + s])
        sh = (0.19 * sx, 0, 0.57)
        B.cyl(sh, BONE["arm_stretch." + s][2], 0.055, 0.045, "mud", aw)
        B.cyl(BONE["forearm_stretch." + s][1], BONE["forearm_stretch." + s][2], 0.045, 0.04, "mud", aw)
        h0, h1 = V(BONE["hand." + s][1]), V(BONE["hand." + s][2])
        fist = h0 + (h1 - h0) * 0.6
        B.ico(fist, (0.065, 0.065, 0.06), "mud_dark", rigid("hand." + s), subdiv=2, lump=0.12, seed=8 + sx)
        lw = seg_w(["thigh_stretch." + s, "leg_stretch." + s])
        B.cyl(BONE["thigh_stretch." + s][1], BONE["thigh_stretch." + s][2], 0.07, 0.06, "mud", lw)
        B.cyl(BONE["leg_stretch." + s][1], BONE["leg_stretch." + s][2], 0.06, 0.05, "mud", lw)
        B.ico((0.13 * sx, -0.045, 0.045), (0.075, 0.11, 0.045), "mud_dark", rigid("foot." + s), subdiv=2, lump=0.1, seed=9 + sx)
    h0, h1 = V(BONE["hand.r"][1]), V(BONE["hand.r"][2])
    fist_r = h0 + (h1 - h0) * 0.6
    club_dir = Vector((0, -0.55, -0.835)).normalized()
    club_tip = fist_r + club_dir * 0.30
    cw = rigid("hand.r")
    B.cyl(fist_r - club_dir * 0.05, club_tip, 0.028, 0.032, "rust", cw)
    B.cyl(club_tip - club_dir * 0.02, club_tip + club_dir * 0.04, 0.05, 0.05, "metal_dark", cw, seg=8)
    B.box(fist_r + club_dir * 0.17, (0.07, 0.02, 0.02), "metal", cw)
    h0l, h1l = V(BONE["hand.l"][1]), V(BONE["hand.l"][2])
    fist_l = h0l + (h1l - h0l) * 0.6
    return B, {"club_tip": club_tip, "fist_l": fist_l, "fist_r": fist_r}


# ---------------------------------------------------------------- scene
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.render.fps_base = 1.0
    sc.frame_start = 0


def make_materials():
    mp = bpy.data.materials.new("GogoRunt_palette")
    mp.use_nodes = True
    nt = mp.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(PALETTE_PNG)
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    me = bpy.data.materials.new("GogoRunt_eye")
    me.use_nodes = True
    b2 = me.node_tree.nodes["Principled BSDF"]
    b2.inputs["Base Color"].default_value = (1.0, 0.75, 0.07, 1.0)
    b2.inputs["Emission Color"].default_value = (0.55, 1.0, 0.65, 1.0)
    b2.inputs["Emission Strength"].default_value = 2.5
    b2.inputs["Roughness"].default_value = 0.3
    return mp, me


def make_armature():
    ad = bpy.data.armatures.new("root")
    arm = bpy.data.objects.new("root", ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent, deform in BONES:
        eb = ad.edit_bones.new(name)
        eb.head, eb.tail, eb.roll = head, tail, 0.0
        eb.use_deform = deform
        if parent:
            eb.parent = ad.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for s in ("l", "r"):
        pb = arm.pose.bones["leg_stretch." + s]
        ik = pb.constraints.new("IK")
        ik.target, ik.subtarget, ik.chain_count = arm, "ik_foot." + s, 2
        cr = arm.pose.bones["foot." + s].constraints.new("COPY_ROTATION")
        cr.target, cr.subtarget = arm, "ik_foot." + s
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


# ---------------------------------------------------------------- animation
def merge(*poses):
    out = {}
    for p in poses:
        for b, d in p.items():
            out.setdefault(b, {}).update(d)
    return out


def mirror(p):
    """Swap .l/.r and mirror across X (for strafe)."""
    out = {}
    for b, d in p.items():
        nb = b[:-1] + ("r" if b.endswith(".l") else "l") if b[-2:] in (".l", ".r") else b
        nd = {}
        for k, v in d.items():
            if k == "r":
                nd[k] = (v[0], -v[1], -v[2])
            elif k == "l":
                nd[k] = (-v[0], v[1], v[2])
            else:
                nd[k] = v
        out[nb] = nd
    return out


COMBAT = {
    "root.x": dict(l=(0, 0, -0.04), r=(12, 0, 0)),
    "spine_01.x": dict(r=(6, 0, 0)),
    "head.x": dict(r=(-14, 0, 0)),
    "arm_stretch.r": dict(r=(-70, 20, 0)), "forearm_stretch.r": dict(r=(-50, 0, 0)),
    "arm_stretch.l": dict(r=(-40, -15, 0)), "forearm_stretch.l": dict(r=(-40, 0, 0)),
    "ik_foot.l": dict(l=(0.03, -0.04, 0)), "ik_foot.r": dict(l=(-0.03, 0.04, 0)),
}


def walk_keys(n, stride, lift, bob, lean, arm_swing, sway):
    h = n // 2
    q = n // 4
    lean_p = {"spine_01.x": dict(r=(lean, 0, 0)), "head.x": dict(r=(-lean * 0.7, 0, 0))}

    def pose(lf, rf, root_z, roll, armph):
        return merge(lean_p, {
            "root.x": dict(l=(0, 0, root_z), r=(lean * 0.4, roll, -roll * 0.6)),
            "ik_foot.l": dict(l=lf), "ik_foot.r": dict(l=rf),
            "arm_stretch.l": dict(r=(arm_swing * armph, -6, 0)),
            "arm_stretch.r": dict(r=(-arm_swing * armph * 0.6, 6, 0)),
            "forearm_stretch.l": dict(r=(-15, 0, 0)), "forearm_stretch.r": dict(r=(-25, 0, 0)),
            "wheel.x": dict(rl=(0, math.radians(12) * armph, 0)),
        })
    return {
        0: pose((0, -stride, 0), (0, stride, 0), -bob, sway, 1),
        q: pose((0, 0, 0), (0, 0, lift), bob * 0.6, 0, 0),
        h: pose((0, stride, 0), (0, -stride, 0), -bob, -sway, -1),
        h + q: pose((0, 0, lift), (0, 0, 0), bob * 0.6, 0, 0),
        n: pose((0, -stride, 0), (0, stride, 0), -bob, sway, 1),
    }


def strafe_l_keys():
    n, h, q = 30, 15, 7
    base = {"spine_01.x": dict(r=(4, 6, 0)), "head.x": dict(r=(-6, -4, 0)),
            "arm_stretch.r": dict(r=(-45, 20, 0)), "forearm_stretch.r": dict(r=(-40, 0, 0)),
            "arm_stretch.l": dict(r=(-20, -25, 0)), "forearm_stretch.l": dict(r=(-30, 0, 0))}

    def pose(lf, rf, z, roll):
        return merge(base, {"root.x": dict(l=(0, 0, z), r=(6, roll, 0)),
                            "ik_foot.l": dict(l=lf), "ik_foot.r": dict(l=rf)})
    return {
        0: pose((0.07, 0, 0), (0.0, 0, 0), -0.02, 6),
        q: pose((0.03, 0, 0), (0.04, 0, 0.06), 0.01, 4),
        h: pose((0.0, 0, 0), (0.07, 0, 0), -0.02, 8),
        h + q + 1: pose((0.04, 0, 0.06), (0.03, 0, 0), 0.01, 4),
        n: pose((0.07, 0, 0), (0.0, 0, 0), -0.02, 6),
    }


ANIMS = {}

ANIMS["Monstr_idle"] = (60, True, {
    0: {},
    30: {"root.x": dict(l=(0, 0, -0.02)), "spine_01.x": dict(s=(1.05, 0.95, 1.05)),
         "head.x": dict(r=(5, 0, 6)), "neck.x": dict(r=(0, 0, 4)),
         "arm_stretch.l": dict(r=(-6, -5, 0)), "arm_stretch.r": dict(r=(-6, 5, 0)),
         "forearm_stretch.l": dict(r=(-8, 0, 0)), "wheel.x": dict(rl=(0, math.radians(25), 0))},
    60: {},
})
ANIMS["Monstr_walk"] = (30, True, walk_keys(30, 0.09, 0.07, 0.02, 8, 22, 6))
ANIMS["Monstr_run"] = (18, True, walk_keys(18, 0.13, 0.10, 0.03, 20, 35, 8))
ANIMS["Monstr_walk_strafe_l"] = (30, True, strafe_l_keys())
ANIMS["Monstr_walk_strafe_r"] = (30, True, {f: mirror(p) for f, p in strafe_l_keys().items()})

_angry_dn = {"root.x": dict(l=(0, 0, -0.04)), "spine_01.x": dict(s=(1.12, 0.86, 1.12)),
             "arm_stretch.l": dict(r=(-110, -35, 0)), "forearm_stretch.l": dict(r=(-30, 0, 0)),
             "arm_stretch.r": dict(r=(-150, 20, 0)), "forearm_stretch.r": dict(r=(-30, 0, 0)),
             "head.x": dict(r=(-10, 0, 12))}
_angry_up = {"root.x": dict(l=(0, 0, 0.08)), "spine_01.x": dict(s=(0.92, 1.1, 0.92)),
             "arm_stretch.l": dict(r=(-60, -55, 0)), "forearm_stretch.l": dict(r=(-60, 0, 0)),
             "arm_stretch.r": dict(r=(-110, 10, 0)), "forearm_stretch.r": dict(r=(-60, 0, 0)),
             "head.x": dict(r=(-15, 0, -12)), "ik_foot.l": dict(l=(0, 0, 0.06)), "ik_foot.r": dict(l=(0, 0, 0.06)),
             "wheel.x": dict(rl=(0, math.radians(40), 0))}
ANIMS["Monstr_angry"] = (40, True, {0: _angry_dn, 10: _angry_up, 20: _angry_dn,
                                    30: merge(_angry_up, {"head.x": dict(r=(-15, 0, 12))}), 40: _angry_dn})

ANIMS["Monstr_attack_idle"] = (40, True, {
    0: COMBAT,
    20: merge(COMBAT, {"root.x": dict(l=(0, 0, -0.06), r=(14, 0, 0)), "spine_01.x": dict(r=(6, 0, 0), s=(1.04, 0.96, 1.04)),
                       "arm_stretch.r": dict(r=(-80, 22, 0)), "head.x": dict(r=(-16, 0, 4))}),
    40: COMBAT,
})

# Attack 1: overhead pipe slam. 33 frames (1.1 s). STRIKE at frame 16 (0.5333 s).
ATTACK1_STRIKE = 16
ANIMS["Monstr_attack_1"] = (33, False, {
    0: COMBAT,
    11: merge(COMBAT, {"root.x": dict(l=(0, 0.03, -0.01), r=(-15, 0, -10)),
                       "spine_01.x": dict(r=(-15, 0, -10), s=(0.92, 1.12, 0.92)),
                       "head.x": dict(r=(-12, 0, 0)),
                       "arm_stretch.r": dict(r=(-170, 15, 0)), "forearm_stretch.r": dict(r=(-40, 0, 0)),
                       "hand.r": dict(r=(-30, 0, 0)),
                       "arm_stretch.l": dict(r=(-30, -40, 0)), "forearm_stretch.l": dict(r=(-20, 0, 0)),
                       "ik_foot.l": dict(l=(0.03, -0.05, 0)), "ik_foot.r": dict(l=(-0.03, 0.06, 0))}),
    14: merge(COMBAT, {"root.x": dict(l=(0, 0.035, -0.0), r=(-18, 0, -12)),
                       "spine_01.x": dict(r=(-17, 0, -12), s=(0.9, 1.15, 0.9)),
                       "head.x": dict(r=(-12, 0, 0)),
                       "arm_stretch.r": dict(r=(-175, 15, 0)), "forearm_stretch.r": dict(r=(-40, 0, 0)),
                       "hand.r": dict(r=(-30, 0, 0)),
                       "arm_stretch.l": dict(r=(-30, -40, 0)), "forearm_stretch.l": dict(r=(-20, 0, 0)),
                       "ik_foot.l": dict(l=(0.03, -0.05, 0.03)), "ik_foot.r": dict(l=(-0.03, 0.06, 0))}),
    ATTACK1_STRIKE: merge(COMBAT, {"root.x": dict(l=(0, -0.08, -0.06), r=(30, 0, 8)),
                                   "spine_01.x": dict(r=(25, 0, 5), s=(1.15, 0.85, 1.15)),
                                   "head.x": dict(r=(-5, 0, 0)),
                                   "arm_stretch.r": dict(r=(-25, 5, 0)), "forearm_stretch.r": dict(r=(-25, 0, 0)),
                                   "hand.r": dict(r=(-35, 0, 0)),
                                   "arm_stretch.l": dict(r=(10, -25, 0)), "forearm_stretch.l": dict(r=(-10, 0, 0)),
                                   "ik_foot.l": dict(l=(0.03, -0.11, 0)), "ik_foot.r": dict(l=(-0.03, 0.06, 0))}),
    19: merge(COMBAT, {"root.x": dict(l=(0, -0.08, -0.08), r=(28, 0, 6)),
                       "spine_01.x": dict(r=(24, 0, 4), s=(1.2, 0.8, 1.2)),
                       "head.x": dict(r=(0, 0, 6)),
                       "arm_stretch.r": dict(r=(-25, 5, 0)), "forearm_stretch.r": dict(r=(-25, 0, 0)),
                       "hand.r": dict(r=(-35, 0, 0)),
                       "arm_stretch.l": dict(r=(10, -25, 0)), "forearm_stretch.l": dict(r=(-10, 0, 0)),
                       "ik_foot.l": dict(l=(0.03, -0.11, 0)), "ik_foot.r": dict(l=(-0.03, 0.06, 0))}),
    25: merge(COMBAT, {"root.x": dict(l=(0, -0.05, -0.05), r=(20, 0, 3)),
                       "spine_01.x": dict(r=(14, 0, 2), s=(1.02, 0.98, 1.02)),
                       "arm_stretch.r": dict(r=(-35, 10, 0)), "forearm_stretch.r": dict(r=(-30, 0, 0)),
                       "ik_foot.l": dict(l=(0.03, -0.08, 0))}),
    33: COMBAT,
})

# Attack 2: lunge headbutt with both arms thrust forward. 30 frames (1.0 s). STRIKE at frame 14 (0.4667 s).
ATTACK2_STRIKE = 14
ANIMS["Monstr_attack_2"] = (30, False, {
    0: COMBAT,
    10: merge(COMBAT, {"root.x": dict(l=(0, 0.06, -0.06), r=(-18, 0, 0)),
                       "spine_01.x": dict(r=(-8, 0, 0), s=(1.12, 0.86, 1.12)),
                       "head.x": dict(r=(-22, 0, 0)),
                       "arm_stretch.l": dict(r=(40, -25, 0)), "forearm_stretch.l": dict(r=(-10, 0, 0)),
                       "arm_stretch.r": dict(r=(40, 25, 0)), "forearm_stretch.r": dict(r=(-10, 0, 0)),
                       "wheel.x": dict(rl=(0, math.radians(-30), 0))}),
    ATTACK2_STRIKE: merge(COMBAT, {"root.x": dict(l=(0, -0.22, 0.0), r=(38, 0, 0)),
                                   "spine_01.x": dict(r=(12, 0, 0), s=(0.88, 1.18, 0.88)),
                                   "head.x": dict(r=(25, 0, 0)),
                                   "arm_stretch.l": dict(r=(-85, -12, 0)), "forearm_stretch.l": dict(r=(-10, 0, 0)),
                                   "arm_stretch.r": dict(r=(-85, 12, 0)), "forearm_stretch.r": dict(r=(-10, 0, 0)),
                                   "hand.r": dict(r=(20, 0, 0)),
                                   "ik_foot.l": dict(l=(0.03, -0.18, 0.0)), "ik_foot.r": dict(l=(-0.03, -0.02, 0.0)),
                                   "wheel.x": dict(rl=(0, math.radians(90), 0))}),
    17: merge(COMBAT, {"root.x": dict(l=(0, -0.23, -0.04), r=(34, 0, 0)),
                       "spine_01.x": dict(r=(10, 0, 0), s=(1.12, 0.88, 1.12)),
                       "head.x": dict(r=(18, 0, 0)),
                       "arm_stretch.l": dict(r=(-75, -15, 0)), "forearm_stretch.l": dict(r=(-15, 0, 0)),
                       "arm_stretch.r": dict(r=(-75, 15, 0)), "forearm_stretch.r": dict(r=(-15, 0, 0)),
                       "ik_foot.l": dict(l=(0.03, -0.18, 0.0)), "ik_foot.r": dict(l=(-0.03, -0.02, 0.0)),
                       "wheel.x": dict(rl=(0, math.radians(120), 0))}),
    23: merge(COMBAT, {"root.x": dict(l=(0, -0.1, -0.04), r=(18, 0, 0)),
                       "ik_foot.l": dict(l=(0.03, -0.08, 0.0)), "ik_foot.r": dict(l=(-0.03, 0.02, 0.03)),
                       "wheel.x": dict(rl=(0, math.radians(150), 0))}),
    30: merge(COMBAT, {"wheel.x": dict(rl=(0, math.radians(180), 0))}),
})

ANIMS["Monstr_hit"] = (12, False, {
    0: {},
    3: {"root.x": dict(l=(0, 0.05, -0.01), r=(-20, 0, 6)),
        "spine_01.x": dict(r=(-12, 0, 5), s=(1.15, 0.85, 1.15)),
        "head.x": dict(r=(-25, 0, 10)),
        "arm_stretch.l": dict(r=(-50, -40, 0)), "arm_stretch.r": dict(r=(-50, 40, 0)),
        "ik_foot.r": dict(l=(0, 0.03, 0.02))},
    7: {"root.x": dict(l=(0, 0.03, -0.02), r=(-6, 0, 2)),
        "spine_01.x": dict(s=(0.95, 1.05, 0.95)), "head.x": dict(r=(-6, 0, 4))},
    12: {},
})

ANIMS["Monstr_knockdown"] = (18, False, {
    0: {},
    4: {"root.x": dict(l=(0, 0.12, -0.04), r=(-35, 0, -10)),
        "spine_01.x": dict(r=(-18, 0, -6), s=(1.2, 0.8, 1.2)),
        "head.x": dict(r=(-30, 0, -10)),
        "arm_stretch.l": dict(r=(-130, -40, 0)), "arm_stretch.r": dict(r=(-130, 40, 0)),
        "ik_foot.l": dict(l=(0, 0.12, 0.06)), "wheel.x": dict(rl=(0, math.radians(60), 0))},
    10: {"root.x": dict(l=(0, 0.1, -0.07), r=(-12, 0, 4)),
         "spine_01.x": dict(r=(6, 0, 2), s=(1.1, 0.9, 1.1)),
         "head.x": dict(r=(10, 0, 6)),
         "arm_stretch.l": dict(r=(-40, -30, 0)), "arm_stretch.r": dict(r=(-40, 30, 0)),
         "ik_foot.l": dict(l=(0, 0.10, 0)), "wheel.x": dict(rl=(0, math.radians(90), 0))},
    18: {},
})

ANIMS["Monstr_death"] = (30, False, {
    0: {},
    6: {"root.x": dict(l=(0, 0.04, 0.02), r=(-15, 0, 0)),
        "spine_01.x": dict(r=(-8, 0, 0), s=(0.9, 1.1, 0.9)), "head.x": dict(r=(-30, 0, 0)),
        "arm_stretch.l": dict(r=(-150, -30, 0)), "arm_stretch.r": dict(r=(-150, 30, 0))},
    18: {"root.x": dict(l=(0, 0.16, -0.07), r=(-75, 0, 15)),
         "spine_01.x": dict(r=(-10, 0, 0), s=(1.25, 0.8, 1.25)), "head.x": dict(r=(-15, 0, 20)),
         "arm_stretch.l": dict(r=(-90, -60, 0)), "arm_stretch.r": dict(r=(-90, 60, 0)),
         "ik_foot.l": dict(l=(0.02, -0.02, 0.10)), "ik_foot.r": dict(l=(-0.04, -0.06, 0.14)),
         "wheel.x": dict(rl=(0, math.radians(90), 0))},
    22: {"root.x": dict(l=(0, 0.16, -0.04), r=(-72, 0, 15)),
         "spine_01.x": dict(r=(-10, 0, 0), s=(1.1, 0.92, 1.1)), "head.x": dict(r=(-20, 0, 22)),
         "arm_stretch.l": dict(r=(-80, -70, 0)), "arm_stretch.r": dict(r=(-85, 65, 0)),
         "ik_foot.l": dict(l=(0.02, -0.03, 0.13)), "ik_foot.r": dict(l=(-0.04, -0.07, 0.17)),
         "wheel.x": dict(rl=(0, math.radians(120), 0))},
    30: {"root.x": dict(l=(0, 0.17, -0.07), r=(-78, 0, 16)),
         "spine_01.x": dict(r=(-10, 0, 0), s=(1.3, 0.75, 1.3)), "head.x": dict(r=(-10, 0, 25)),
         "arm_stretch.l": dict(r=(-85, -75, 0)), "arm_stretch.r": dict(r=(-90, 70, 0)),
         "forearm_stretch.l": dict(r=(10, 0, 0)), "forearm_stretch.r": dict(r=(10, 0, 0)),
         "ik_foot.l": dict(l=(0.03, -0.02, 0.10)), "ik_foot.r": dict(l=(-0.05, -0.06, 0.14)),
         "wheel.x": dict(rl=(0, math.radians(130), 0))},
})


def apply_pose(arm, pose, prev_q):
    for pb in arm.pose.bones:
        d = pose.get(pb.name, {})
        R = pb.bone.matrix_local.to_quaternion()
        Ri = R.inverted()
        q = Quaternion()
        if "r" in d:
            qw = Euler([math.radians(a) for a in d["r"]], "XYZ").to_quaternion()
            q = Ri @ qw @ R
        if "rl" in d:
            q = q @ Euler(d["rl"], "XYZ").to_quaternion()
        q.normalize()
        if pb.name in prev_q and prev_q[pb.name].dot(q) < 0:
            q.negate()
        prev_q[pb.name] = q.copy()
        pb.rotation_quaternion = q
        pb.location = Ri @ Vector(d.get("l", (0, 0, 0)))
        pb.scale = Vector(d.get("s", (1, 1, 1)))


def make_actions(arm):
    arm.animation_data_create()
    acts = {}
    for name in sorted(ANIMS):
        n, loop, keys = ANIMS[name]
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        prev_q = {}
        for f in sorted(keys):
            apply_pose(arm, keys[f], prev_q)
            for pb in arm.pose.bones:
                pb.keyframe_insert("location", frame=f, group=pb.name)
                pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
                pb.keyframe_insert("scale", frame=f, group=pb.name)
        act.use_frame_range = True
        act.frame_start, act.frame_end = 0, n
        act.use_cyclic = loop
        acts[name] = act
    arm.animation_data.action = acts["Monstr_idle"]
    for pb in arm.pose.bones:
        pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), Quaternion(), (1, 1, 1)
    return acts


# ---------------------------------------------------------------- main
def main():
    reset_scene()
    mat_pal, mat_eye = make_materials()
    arm = make_armature()
    B, pts = build_mesh()
    me = bpy.data.meshes.new("Monstr")
    B.bm.to_mesh(me)
    B.bm.free()
    me.materials.append(mat_pal)
    me.materials.append(mat_eye)
    ob = bpy.data.objects.new("Monstr", me)
    bpy.context.scene.collection.objects.link(ob)
    for n in DEFORM:
        ob.vertex_groups.new(name=n)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm

    make_actions(arm)
    bpy.context.scene.frame_set(0)

    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("GOGO tris:", tris, "verts:", len(me.vertices))

    if RIG_JSON:
        C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
        rig = {"bones": {}, "points": {}}
        for b in arm.data.bones:
            if not b.use_deform:
                continue
            G = C @ b.matrix_local
            rig["bones"][b.name] = {
                "parent": b.parent.name if b.parent else None,
                "length": b.length,
                "godot": [list(G[i][:]) for i in range(3)],
            }
        Mr = arm.data.bones["hand.r"].matrix_local.inverted()
        Ml = arm.data.bones["hand.l"].matrix_local.inverted()
        rig["points"]["hand_r_tip_local"] = list(Mr @ pts["club_tip"])
        rig["points"]["hand_l_tip_local"] = list(Ml @ pts["fist_l"])
        with open(RIG_JSON, "w") as f:
            json.dump(rig, f, indent=1)

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB, export_format="GLB", use_selection=False,
        export_yup=True, export_apply=False, export_texcoords=True, export_normals=True,
        export_materials="EXPORT", export_image_format="NONE",  # palette texture comes from MasterPalette.tres in Godot
        export_skins=True, export_def_bones=True, export_rest_position_armature=True,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_frame_range=False, export_anim_slide_to_zero=False,
        export_reset_pose_bones=True, export_anim_single_armature=True,
        export_optimize_animation_size=False,
    )
    print("GOGO exported:", OUT_GLB)


main()
