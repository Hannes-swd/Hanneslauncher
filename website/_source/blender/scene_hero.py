# The hero phone as a still (public/img/hero-phone.webp): what visitors see
# when the live 3D phone can't run - no WebGL, reduced motion, data saver -
# and for the moment before it loads. Same pose as the hero slot's data-yaw/
# pitch/roll, framed to the slot's 74.5:158.4 so the two line up.

import bpy
exec(open(r"C:/Users/hanne/Flutter/hanneslouncher/website/_source/blender/studio.py").read())
for o in list(bpy.data.objects):
    if o.name.startswith('Dot') or o.name == 'Wall':
        bpy.data.objects.remove(o, do_unlink=True)
cam = setup(ground=False)
set_screen(SITE + "/public/media/shots/clock_custom.webp")
pose(pitch=3, yaw=-20, roll=-5)
look(cam, (0, -0.53, 0.0), (0, 0, 0), lens=85)
cam.data.sensor_fit = 'VERTICAL'
cam.data.sensor_height = 36
render(r"C:/Users/hanne/Flutter/hanneslouncher/website/_source/raw/hero_phone.png", 940, 2000, samples=160)
print('hero done')
