"""Uso: python3 montaje.py CARPETA

Lo que haría Flutter: el suelo renderizado una vez, y cada edificio como
imagen suelta colocada encima, de atrás adelante, con un reflejo falso."""
import json, math, os, random, sys
import bpy
from bpy_extras.object_utils import world_to_camera_view
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
CARPETA = sys.argv[1] if len(sys.argv) > 1 else '.'
import ciudad_blender as cb

PARCELAS = [
    (-2.0, 2.0, 1.6, 1.6), (-3.6, 3.4, 1.2, 1.1), (-2.2, 4.0, 1.3, 1.0),
    (2.1, 2.1, 1.7, 1.5), (3.6, 2.0, 1.1, 1.3), (2.3, 3.8, 1.5, 1.1),
    (2.0, -2.1, 1.6, 1.7), (3.6, -3.4, 1.2, 1.2),
    (-2.1, -2.0, 1.7, 1.6), (-3.8, -2.2, 1.1, 1.4),
]
RES = 1100
ESCALA = 12.5
PX_POR_UNIDAD = RES / ESCALA

# 1. El suelo, sin edificios.
sc = cb.preparar((RES, RES), transparente=False)
col = bpy.data.collections.new('suelo'); sc.collection.children.link(col)
cb.suelo_calle(col)
cb.camara_isometrica(sc, (0, 0, 1.9), ESCALA)
posiciones = []
for (px, py, w, d) in PARCELAS:
    v = world_to_camera_view(sc, sc.camera, __import__('mathutils').Vector((px, py, 0.05)))
    posiciones.append((v.x * RES, (1 - v.y) * RES))
sc.render.filepath = f'{CARPETA}/suelo.png'
bpy.ops.render.render(write_still=True)

# 2. Cada edificio, suelto, con la misma cámara y la misma escala.
W, H = 384, 640
anclas = []
for i, (px, py, w, d) in enumerate(PARCELAS):
    sc = cb.preparar((W, H), transparente=True)
    col = bpy.data.collections.new('e'); sc.collection.children.link(col)
    cb.edificio(1000 + i * 17, w, d, col)
    cb.camara_isometrica(sc, (0, 0, 2.6), H / PX_POR_UNIDAD)
    v = world_to_camera_view(sc, sc.camera, __import__('mathutils').Vector((0, 0, 0.05)))
    anclas.append((v.x * W, (1 - v.y) * H))
    sc.render.filepath = f'{CARPETA}/sprite_{i:02d}.png'
    bpy.ops.render.render(write_still=True)

json.dump({'posiciones': posiciones, 'anclas': anclas,
           'orden': sorted(range(len(PARCELAS)), key=lambda k: PARCELAS[k][0] - PARCELAS[k][1])},
          open(f'{CARPETA}/montaje.json', 'w'))
print('ok')
