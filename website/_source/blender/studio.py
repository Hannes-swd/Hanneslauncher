# Studio for the website renders: soft light from the upper left like the
# launcher's three-layer shadows, a ground that only catches shadow, and
# helpers to put a screenshot on the display and turn the phone.
# Run after build_phone.py. Call render() from the snippets per scene.

import bpy, math, os
from mathutils import Euler, Vector

SITE = r"C:/Users/hanne/Flutter/hanneslouncher/website"
scene = bpy.context.scene


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def clear_studio():
    for o in list(bpy.data.objects):
        if o.get('studio'):
            bpy.data.objects.remove(o, do_unlink=True)


def add(obj):
    obj['studio'] = True
    scene.collection.objects.link(obj)
    return obj


def area(name, loc, size, energy, color='ffffff'):
    lamp = bpy.data.lights.new(name, 'AREA')
    lamp.shape = 'DISK'
    lamp.size = size
    lamp.energy = energy
    lamp.color = srgb(color)
    ob = add(bpy.data.objects.new(name, lamp))
    ob.location = loc
    direction = Vector((0, 0, 0)) - Vector(loc)
    ob.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    return ob


def setup(ground=True):
    clear_studio()
    world = bpy.data.worlds.get('World') or bpy.data.worlds.new('World')
    scene.world = world
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (*srgb('f4f3f0'), 1)
    bg.inputs['Strength'].default_value = 0.55

    # The phone stands upright (see pose), its screen towards -Y where the
    # camera is; the key comes from the upper left like the launcher's shadows
    area('Key', (-0.34, -0.36, 0.40), 0.40, 40, 'fffaf2')
    area('Fill', (0.42, -0.30, 0.02), 0.55, 12, 'eef3ff')
    area('Rim', (0.18, 0.38, 0.30), 0.25, 22, 'ffffff')

    if ground:
        bpy.ops.mesh.primitive_plane_add(size=3, location=(0, 0, -0.105))
        g = bpy.context.active_object
        g['studio'] = True
        g.name = 'Ground'
        g.is_shadow_catcher = True

    cam_data = bpy.data.cameras.new('Cam')
    cam_data.lens = 85
    cam = add(bpy.data.objects.new('Cam', cam_data))
    scene.camera = cam
    return cam


def look(cam, loc, target=(0, 0, 0), lens=85):
    cam.location = loc
    cam.data.lens = lens
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def set_screen(path, obj_name='Screen'):
    """Shows a picture on the display, emissive like a real panel."""
    m = bpy.data.objects[obj_name].active_material
    nt = m.node_tree
    p = nt.nodes.get('Principled BSDF')
    tex = nt.nodes.get('ScreenTex') or nt.nodes.new('ShaderNodeTexImage')
    tex.name = 'ScreenTex'
    tex.image = bpy.data.images.load(path, check_existing=True)
    tex.interpolation = 'Cubic'
    nt.links.new(tex.outputs['Color'], p.inputs['Emission Color'])
    p.inputs['Emission Strength'].default_value = 1.0
    p.inputs['Base Color'].default_value = (0, 0, 0, 1)
    p.inputs['Roughness'].default_value = 0.12
    p.inputs['Coat Weight'].default_value = 1.0


def pose(pitch=0, yaw=0, roll=0, loc=(0, 0, 0), name='Phone'):
    """Upright phone facing the camera at -Y: pitch tips the top away, yaw
    turns it about the vertical, roll leans it within the picture plane."""
    ob = bpy.data.objects[name]
    ob.rotation_euler = Euler((math.radians(90 + pitch), math.radians(roll), math.radians(yaw)))
    ob.location = loc


def render(out, w, h, engine='CYCLES', samples=96, transparent=True):
    scene.render.engine = 'BLENDER_EEVEE' if engine == 'EEVEE' else 'CYCLES'
    if engine != 'EEVEE':
        scene.cycles.samples = samples
        scene.cycles.use_denoising = True
        try:
            prefs = bpy.context.preferences.addons['cycles'].preferences
            for t in ('OPTIX', 'CUDA', 'HIP', 'ONEAPI', 'METAL'):
                try:
                    prefs.compute_device_type = t
                    prefs.get_devices()
                    if any(d.type == t for d in prefs.devices):
                        for d in prefs.devices:
                            d.use = d.type == t
                        scene.cycles.device = 'GPU'
                        break
                except Exception:
                    continue
        except Exception:
            pass
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA' if transparent else 'RGB'
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    return out
