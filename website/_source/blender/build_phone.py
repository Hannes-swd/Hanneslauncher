# Builds the phone for the website from nothing. Run inside Blender (the
# MCP addon executes it, or: blender -b -P build_phone.py).
#
# One object per material role so three.js can address them by name:
#   Body    - frame (satin metal) + back (frosted, launcher grey)
#   Glass   - the black front glass around the display
#   Screen  - the active area, UV 0..1 over exactly 1064:2364 - the aspect
#             of the encoded recordings - so a video maps without stretching
#   Camera  - the pill-shaped island with two lenses and a flash
#   Buttons - power + volume on the right edge
# Units are metres; the phone is 74.5 x 158.4 x 8.2 mm.

import bpy, bmesh, math
from mathutils import Vector

W = 0.0745            # body width
SW = W - 0.0058       # screen width  (1.3 mm lip + 1.6 mm bezel each side)
SH = SW * 2364 / 1064 # screen height from the clip aspect
H = SH + 0.0058       # body height
D = 0.0082            # body depth
R = 0.0112            # body corner radius, plan view
E = 0.0021            # edge roundness of the body

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    for b in list(coll):
        if b.users == 0:
            coll.remove(b)


def mat(name, color, metallic=0.0, rough=0.5, coat=0.0, emission=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = rough
    p.inputs['Coat Weight'].default_value = coat
    p.inputs['Coat Roughness'].default_value = 0.03
    if emission:
        p.inputs['Emission Color'].default_value = (*emission, 1)
        p.inputs['Emission Strength'].default_value = 1.0
    return m


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


M_FRAME = mat('Frame', srgb('d8d5cf'), metallic=1.0, rough=0.34)
M_BACK = mat('Back', srgb('ebe8e2'), rough=0.42, coat=0.6)
M_GLASS = mat('Glass', srgb('060608'), rough=0.06, coat=1.0)
M_SCREEN = mat('Screen', (0, 0, 0), rough=0.2, emission=srgb('f4f3f0'))
M_LENS = mat('Lens', srgb('0b0c10'), rough=0.05, coat=1.0)
M_RING = mat('Ring', srgb('c9c6c0'), metallic=1.0, rough=0.22)
M_FLASH = mat('Flash', srgb('f2efe6'), rough=0.3)


def rounded_rect(bm, w, h, r, z=0.0, segs=20):
    vs = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90),
                       (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for i in range(segs + 1):
            a = math.radians(a0 + 90 * i / segs)
            vs.append(bm.verts.new((cx + r * math.cos(a), cy + r * math.sin(a), z)))
    return bm.faces.new(vs)


def slab(name, w, h, d, r, edge, segs=20, edge_segs=6):
    """Rounded-rectangle prism, front at +z, with rounded front/back edges."""
    bm = bmesh.new()
    f = rounded_rect(bm, w, h, r, -d / 2, segs)
    f.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    top = [v for v in ext['geom'] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top, vec=(0, 0, d))
    bm.normal_update()
    caps = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-9
            and abs(abs(e.verts[0].co.z) - d / 2) < 1e-9]
    if edge > 0:
        bmesh.ops.bevel(bm, geom=caps, offset=edge, segments=edge_segs,
                        profile=0.5, affect='EDGES', clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def flat(name, w, h, r, z, material, uv=False, segs=20):
    bm = bmesh.new()
    rounded_rect(bm, w, h, r, z, segs)
    if uv:
        layer = bm.loops.layers.uv.new('UVMap')
        for face in bm.faces:
            for loop in face.loops:
                loop[layer].uv = (loop.vert.co.x / w + 0.5, loop.vert.co.y / h + 0.5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob


# Body: frame on the sides, frosted back on the rear cap
body = slab('Body', W, H, D, R, E, segs=24, edge_segs=8)
body.data.materials.append(M_FRAME)
body.data.materials.append(M_BACK)
for p in body.data.polygons:
    if p.normal.z < -0.999:
        p.material_index = 1

# Front: black glass slightly proud of the frame, the display on top of it
GL = 0.0013
flat('Glass', W - 2 * GL, H - 2 * GL, R - GL, D / 2 + 0.00025, M_GLASS)
screen = flat('Screen', SW, SH, R - GL - 0.0016, D / 2 + 0.00027, M_SCREEN, uv=True)

# Punch-hole selfie camera
bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, segments=32, radius=0.00125)
bmesh.ops.translate(bm, verts=bm.verts, vec=(0, SH / 2 - 0.0046, D / 2 + 0.00029))
me = bpy.data.meshes.new('Selfie'); bm.to_mesh(me); bm.free()
selfie = bpy.data.objects.new('Selfie', me); bpy.context.collection.objects.link(selfie)
me.materials.append(M_LENS)

# Camera island: a vertical pill on the back, top left when seen from behind
IW, IH = 0.0215, 0.0405
ix, iy = W / 2 - 0.0072 - IW / 2, H / 2 - 0.0072 - IH / 2
island = slab('Camera', IW, IH, 0.0016, IW / 2 - 0.0001, 0.0006, segs=24, edge_segs=4)
island.location = (ix, iy, -D / 2 - 0.0006)
island.data.materials.append(M_BACK)
parts = [island]
for k, ly in enumerate((iy + 0.0098, iy - 0.0098)):
    ring = slab(f'Ring{k}', 0.0156, 0.0156, 0.0012, 0.0078 - 0.00001, 0.0003, segs=16, edge_segs=3)
    ring.location = (ix, ly, -D / 2 - 0.0018)
    ring.data.materials.append(M_RING)
    lens = flat(f'Lens{k}', 0.0118, 0.0118, 0.0059 - 0.00001, 0, M_LENS, segs=16)
    lens.location = (ix, ly, -D / 2 - 0.0024)
    lens.rotation_euler = (math.pi, 0, 0)
    parts += [ring, lens]
flash = flat('Flash', 0.0034, 0.0034, 0.0017 - 0.00001, 0, M_FLASH, segs=12)
flash.location = (ix - IW / 2 - 0.0045, iy + 0.0098, -D / 2 - 0.00002)
flash.rotation_euler = (math.pi, 0, 0)
parts.append(flash)

# Buttons on the right edge
buttons = []
for name, y, length in (('Power', 0.022, 0.0115), ('Volume', 0.047, 0.023)):
    b = slab(name, 0.0024, length, 0.0016, 0.0011, 0.0003, segs=8, edge_segs=2)
    b.rotation_euler = (0, math.pi / 2, 0)
    b.location = (W / 2 - 0.0002, y, 0)
    b.data.materials.append(M_FRAME)
    buttons.append(b)

# Join the small parts so the export stays at five meshes
def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]

for o in parts + buttons + [selfie]:
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = island
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
camera_obj = join(parts, 'Camera')
for o in buttons:
    o.select_set(True)
bpy.context.view_layer.objects.active = buttons[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
join(buttons, 'Buttons')

# Everything under one empty so the page can turn the phone as one piece
root = bpy.data.objects.new('Phone', None)
bpy.context.collection.objects.link(root)
for o in bpy.data.objects:
    if o is not root and o.type == 'MESH':
        o.parent = root

print(f'phone {W*1000:.1f} x {H*1000:.1f} x {D*1000:.1f} mm, screen {SW*1000:.2f} x {SH*1000:.2f} mm,',
      sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH'), 'faces')
