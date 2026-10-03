# The link preview (public/img/og.png): the phone floating in front of the
# word mark, whose dots are small glossy spheres on a wall that only
# catches their shadows. Rendered transparent, then laid on the page's
# ground colour by ffmpeg (see render_all.sh). Run after build_phone.py.

import bpy, math
exec(open(r"C:/Users/hanne/Flutter/hanneslouncher/website/_source/blender/studio.py").read())

GLYPHS = {
    'h': ['#....', '#....', '#.##.', '##..#', '#...#', '#...#', '#...#'],
    'a': ['.....', '.....', '.###.', '....#', '.####', '#...#', '.####'],
    'n': ['.....', '.....', '#.##.', '##..#', '#...#', '#...#', '#...#'],
    'e': ['.....', '.....', '.###.', '#...#', '#####', '#....', '.###.'],
    's': ['.....', '.....', '.####', '#....', '.###.', '....#', '####.'],
    'l': ['.##..', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    'u': ['.....', '.....', '#...#', '#...#', '#...#', '#..##', '.##.#'],
    'c': ['.....', '.....', '.###.', '#....', '#....', '#...#', '.###.'],
    'r': ['.....', '.....', '#.##.', '##..#', '#....', '#....', '#....'],
}


def dot_material(name, hexcol, rough=0.34):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*srgb(hexcol), 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Coat Weight'].default_value = 0.45
    return m


def wordmark(word, x0, z0, pitch, wall_y):
    for o in list(bpy.data.objects):
        if o.name.startswith('Dot'):
            bpy.data.objects.remove(o, do_unlink=True)
    cols = len(word) * 6 - 1
    a, b = srgb('3f48cc'), srgb('00a2e8')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1)
    proto = bpy.context.active_object
    proto.name = 'DotProto'
    mesh = proto.data
    bpy.data.objects.remove(proto, do_unlink=True)
    off = dot_material('DotOff', 'e9e7e2', rough=0.6)
    shades = []
    for k in range(8):
        t = k / 7
        c = tuple(a[i] + (b[i] - a[i]) * t for i in range(3))
        m = dot_material(f'DotOn{k}', '000000')
        m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*c, 1)
        shades.append(m)
    for ci, ch in enumerate(word):
        g = GLYPHS[ch]
        for r in range(7):
            for c in range(5):
                col = ci * 6 + c
                on = g[r][c] == '#'
                ob = bpy.data.objects.new(f'Dot{ci}_{r}_{c}', mesh.copy())
                scene.collection.objects.link(ob)
                rad = pitch * (0.41 if on else 0.26)
                ob.scale = (rad, rad * (0.75 if on else 0.4), rad)
                ob.location = (x0 + col * pitch, wall_y - rad * 0.7, z0 - r * pitch)
                t = min(1, max(0, (col / (cols - 1) - 0.15) / 0.7))
                ob.data.materials.append(shades[round(t * 7)] if on else off)
                for poly in ob.data.polygons:
                    poly.use_smooth = True


cam = setup(ground=False)
# softer and dimmer than the hero studio: small glossy dots wash out under
# the full key light, and the wall would take a hard shadow
for o in bpy.data.objects:
    if o.get('studio') and o.type == 'LIGHT':
        o.data.energy *= 0.55
        o.data.size *= 2.2
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.42
# a wall right behind the phone that only keeps shadows
bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0.035, 0), rotation=(math.pi / 2, 0, 0))
wall = bpy.context.active_object
wall.name = 'Wall'
wall['studio'] = True
wall.is_shadow_catcher = True

set_screen(SITE + "/public/media/shots/clock_custom.webp")
pose(pitch=3, yaw=-22, roll=-6, loc=(0.138, 0.004, -0.002))
pitch = 0.0033
wordmark('hanneslauncher', -0.203, 0.0118, pitch, 0.035)
look(cam, (0, -0.60, 0.0), (0, 0, 0), lens=50)
render(r"C:/Users/hanne/Flutter/hanneslouncher/website/_source/raw/og_alpha.png", 1200, 630, samples=192)
print('og done')
