"""El kit del jardín de Dulce para la app: cada pieza renderizada sola, con
la cámara isométrica de Neotokyo+ 3D, y sus pasadas para el lápiz.

    python3 kit_jardin.py CARPETA [NOMBRE...]

Escribe, por pieza, CARPETA/NOMBRE_color.png (+ _normal, _prof, _altura,
_indice) y CARPETA/NOMBRE.json con dónde cae su base en la imagen.
Luego `kit_jardin_lapiz.py` las pasa a lápiz y las empaqueta.
"""
import json
import math
import os
import random
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jardin_blender as jb  # noqa: E402
import plantas_blender as pl  # noqa: E402
from ciudad_blender import camara_isometrica  # noqa: E402

#: Píxeles por unidad de Blender.
PX = 200
#: Dibujos de cada especie.
VARIANTES = 4


def encuadrar(sc, col, base, margen=0.12):
    """Pone la cámara y el tamaño de la imagen justo alrededor de lo que hay
    en [col], a PX píxeles por unidad. Devuelve dónde cae [base] (píxeles)."""
    bpy.context.view_layer.update()
    us, ws = [], []
    for o in col.all_objects:
        if o.type != 'MESH':
            continue
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            us.append((p.x + p.y) / math.sqrt(2))
            ws.append((p.y - p.x) * 0.35355 + p.z * 0.8660)
    u0, u1 = min(us) - margen, max(us) + margen
    w0, w1 = min(ws) - margen, max(ws) + margen
    ancho, alto = u1 - u0, w1 - w0
    uc, wc = (u0 + u1) / 2, (w0 + w1) / 2
    # El punto del suelo que cae en el centro de la imagen.
    s, d = uc * math.sqrt(2), wc / 0.35355
    x, y = (s - d) / 2, (s + d) / 2
    camara_isometrica(sc, (x, y, 0), max(ancho, alto))
    sc.render.resolution_x = math.ceil(ancho * PX)
    sc.render.resolution_y = math.ceil(alto * PX)
    v = world_to_camera_view(sc, sc.camera, Vector(base))
    return (v.x * sc.render.resolution_x, (1 - v.y) * sc.render.resolution_y)


def nueva_escena():
    sc = jb.preparar((64, 64))
    pl._mallas.clear()
    pl._esfera.clear()
    pl._cilindro.clear()
    col = bpy.data.collections.new('pieza')
    sc.collection.children.link(col)
    return sc, col


def guardar(sc, col, carpeta, nombre, base=(0, 0, 0), datos=None):
    ancla = encuadrar(sc, col, base)
    jb.pasadas(sc, f'{carpeta}/{nombre}')
    json.dump({'nombre': nombre, 'ancla': ancla, 'px_por_unidad': PX, **(datos or {})},
              open(f'{carpeta}/{nombre}.json', 'w'))


# ── Las piezas ─────────────────────────────────────────────────────────────

def planta(carpeta, especie, v):
    sc, col = nueva_escena()
    nombre = especie.__name__
    r = random.Random(1000 + 97 * v + pl.ESPECIES.index(especie))
    colores = jb.COLORES[nombre]
    color = colores[v % len(colores)]
    raiz = bpy.data.objects.new('planta', None)
    col.objects.link(raiz)
    antes = set(col.objects)
    especie(r, col, jb.materiales(nombre, color))
    for o in set(col.objects) - antes:
        if o.parent is None:
            o.parent = raiz
    escala = 1.35 if nombre == 'girasol' else 2.0
    raiz.location = (0, 0, 0.08)  # sobre la tierra del parterre
    raiz.scale = (escala,) * 3
    guardar(sc, col, carpeta, f'planta_{nombre}_{v}',
            datos={'tipo': 'planta', 'especie': nombre, 'variante': v,
                   'altura': jb.ALTURA[nombre]})


def parterre(carpeta, v):
    sc, col = nueva_escena()
    jb.parterre((0, 0), 1.1, col, random.Random(500 + v))
    guardar(sc, col, carpeta, f'parterre_{v}', datos={'tipo': 'parterre', 'variante': v, 'radio': 1.1})


def arbol(carpeta, v):
    sc, col = nueva_escena()
    jb.arbol((0, 0), col, random.Random(700 + v))
    guardar(sc, col, carpeta, f'arbol_{v}', datos={'tipo': 'arbol', 'variante': v})


def cesped(carpeta, v, radio=1.75):
    sc, col = nueva_escena()
    jb.cesped(col, lado=1)
    o = col.objects[-1]
    bpy.ops.object.select_all(action='DESELECT')
    bpy.data.objects.remove(o)
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=radio, fill_type='NGON')
    disco = bpy.context.object
    jb._poner(disco, bpy.data.materials['cesped'], col)
    disco.rotation_euler = (0, 0, v * 0.7)
    guardar(sc, col, carpeta, f'cesped_{v}', datos={'tipo': 'cesped', 'variante': v, 'radio': radio})


def losa(carpeta, v):
    sc, col = nueva_escena()
    r = random.Random(900 + v)
    m = jb.mat('losa', jb.hex_('#CFC3B0'), 0.85)
    jb.esfera((0, 0, 0.012), (0.13 + r.random() * 0.03, 0.11, 0.012), m, col,
              rot=(0, 0, r.random() * 3), segmentos=14)
    guardar(sc, col, carpeta, f'losa_{v}', datos={'tipo': 'losa', 'variante': v})


# Los hitos, sencillos pero con su gracia.

def piedra_anillo(col, radio, r, alto=0.06, color='#D8CFC2'):
    m = jb.mat('piedra', jb.hex_(color), 0.8)
    n = int(radio * 2 * math.pi / 0.11)
    for k in range(n):
        a = k * math.tau / n
        s = 0.05 + r.random() * 0.015
        jb.esfera((math.cos(a) * radio, math.sin(a) * radio, alto), (s, s * 0.8, s * 0.7), m, col,
                  rot=(0, 0, a), segmentos=8)


def fuente(carpeta):
    sc, col = nueva_escena()
    r = random.Random(11)
    piedra = jb.mat('piedra_f', jb.hex_('#E2D9CC'), 0.75)
    agua = jb.mat('agua', jb.hex_('#7FB3DD'), 0.08)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.62, depth=0.26, location=(0, 0, 0.13))
    jb._poner(bpy.context.object, piedra, col)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.53, depth=0.02, location=(0, 0, 0.255))
    jb._poner(bpy.context.object, agua, col)
    pl.tallo((0, 0, 0.25), (0, 0, 0.65), 0.07, piedra, col)
    jb.esfera((0, 0, 0.68), (0.24, 0.24, 0.07), piedra, col, segmentos=24)
    jb.esfera((0, 0, 0.72), (0.2, 0.2, 0.02), agua, col, segmentos=24)
    jb.esfera((0, 0, 0.82), (0.025, 0.025, 0.1), agua, col, segmentos=12)
    piedra_anillo(col, 0.66, r, alto=0.03)
    guardar(sc, col, carpeta, 'hito_fuente', datos={'tipo': 'hito', 'hito': 'fuente'})


def pergola(carpeta):
    sc, col = nueva_escena()
    r = random.Random(12)
    madera = jb.mat('madera', jb.hex_('#B9875C'), 0.7)
    for x in (-0.55, 0.55):
        for y in (-0.4, 0.4):
            pl.tallo((x, y, 0), (x, y, 1.1), 0.04, madera, col)
    for y in (-0.4, 0.4):
        jb.esfera((0, y, 1.12), (0.75, 0.035, 0.04), madera, col, segmentos=8)
    for k in range(7):
        x = -0.6 + k * 0.2
        jb.esfera((x, 0, 1.18), (0.03, 0.55, 0.025), madera, col, segmentos=8)
    m = jb.materiales('rosal', jb.ROSA)
    hoja = pl.lamina(0.07, 0.042, copa=0.2, curva=-0.05, punta=0.9)
    flor = pl.lamina(0.06, 0.066, copa=0.5, curva=0.15, punta=0.45)
    for x, y in ((-0.55, -0.4), (0.55, -0.4), (-0.55, 0.4), (0.55, 0.4)):
        for k in range(22):
            z = 0.1 + r.random() * 1.05
            a = r.random() * math.tau
            p = (x + math.cos(a) * 0.06, y + math.sin(a) * 0.06, z)
            pl.hoja_en(p, a, math.radians(r.random() * 50), hoja, m['hoja'], col, giro=r.random() * 3)
        for k in range(4):
            z = 0.4 + r.random() * 0.8
            c = (x + (r.random() - .5) * 0.1, y + (r.random() - .5) * 0.1, z)
            for j in range(5):
                pl.hoja_en(c, j * 1.26 + r.random(), math.radians(35), flor, m['flor'], col)
    for k in range(10):
        x = -0.6 + r.random() * 1.2
        y = (0.4 if r.random() < 0.5 else -0.4) + (r.random() - .5) * 0.15
        c = (x, y, 1.2)
        for j in range(5):
            pl.hoja_en(c, j * 1.26 + r.random(), math.radians(30), flor, m['flor'], col)
    guardar(sc, col, carpeta, 'hito_pergola', datos={'tipo': 'hito', 'hito': 'pergola'})


def banco(carpeta):
    sc, col = nueva_escena()
    r = random.Random(13)
    madera = jb.mat('madera', jb.hex_('#B9875C'), 0.7)
    hierro = jb.mat('hierro', jb.hex_('#4A4550'), 0.5)
    for x in (-0.38, 0.38):
        pl.tallo((x, 0.1, 0), (x, 0.1, 0.22), 0.025, hierro, col)
        pl.tallo((x, 0.28, 0), (x, 0.28, 0.5), 0.025, hierro, col)
    for k in range(3):
        jb.esfera((0, 0.1 + k * 0.07, 0.24), (0.46, 0.028, 0.015), madera, col, segmentos=8)
    for k in range(2):
        jb.esfera((0, 0.3, 0.33 + k * 0.1), (0.46, 0.012, 0.035), madera, col, segmentos=8)
    antes = set(col.objects)
    jb.arbol((-0.2, 0.9), col, r)
    for o in set(col.objects) - antes:
        o.scale = tuple(v * 0.8 for v in o.scale)
        o.location = (o.location.x * 0.8 - 0.04, o.location.y * 0.8 + 0.18, o.location.z * 0.8)
    guardar(sc, col, carpeta, 'hito_banco', datos={'tipo': 'hito', 'hito': 'banco'})


def estanque(carpeta):
    sc, col = nueva_escena()
    r = random.Random(14)
    agua = jb.mat('agua', jb.hex_('#7FB3DD'), 0.08)
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=0.85, fill_type='NGON', location=(0, 0, 0.01))
    o = bpy.context.object
    o.scale = (1.15, 0.85, 1)
    jb._poner(o, agua, col)
    m = jb.mat('piedra', jb.hex_('#D8CFC2'), 0.8)
    n = 44
    for k in range(n):
        a = k * math.tau / n
        s = 0.06 + r.random() * 0.02
        jb.esfera((math.cos(a) * 0.98, math.sin(a) * 0.72, 0.03), (s, s * 0.8, s * 0.7), m, col,
                  rot=(0, 0, a), segmentos=8)
    hoja = jb.mat('nenufar', jb.hex_('#6FA35A'), 0.6)
    flor = jb.mat('flor_nenufar', jb.hex_('#F29BBF'), 0.45, sss=0.2)
    pet = pl.lamina(0.05, 0.03, copa=0.4, curva=0.1, punta=0.6)
    for k in range(6):
        a = r.random() * math.tau
        d = 0.3 + r.random() * 0.4
        p = (math.cos(a) * d * 1.1, math.sin(a) * d * 0.75, 0.02)
        jb.esfera(p, (0.09, 0.09, 0.006), hoja, col, segmentos=16)
        if k % 2 == 0:
            for j in range(8):
                pl.hoja_en((p[0], p[1], 0.03), j * math.tau / 8, math.radians(30), pet, flor, col)
    madera = jb.mat('madera', jb.hex_('#B9875C'), 0.7)
    for k in range(14):
        x = -0.95 + k * 0.145
        z = 0.06 + 0.12 * math.sin(math.pi * (k / 13))
        jb.esfera((x, 0, z), (0.06, 0.2, 0.015), madera, col, segmentos=8)
    for y in (-0.2, 0.2):
        for k in range(8):
            x = -0.95 + k * 0.27
            z = 0.06 + 0.12 * math.sin(math.pi * (k / 7))
            pl.tallo((x, y, z), (x, y, z + 0.18), 0.012, madera, col)
    guardar(sc, col, carpeta, 'hito_estanque', datos={'tipo': 'hito', 'hito': 'estanque'})


def todas():
    piezas = []
    for e in pl.ESPECIES:
        for v in range(VARIANTES):
            piezas.append((f'planta_{e.__name__}_{v}', lambda c, e=e, v=v: planta(c, e, v)))
    for v in range(3):
        piezas.append((f'parterre_{v}', lambda c, v=v: parterre(c, v)))
        piezas.append((f'cesped_{v}', lambda c, v=v: cesped(c, v)))
        piezas.append((f'losa_{v}', lambda c, v=v: losa(c, v)))
    piezas.append(('arbol_0', lambda c: arbol(c, 0)))
    for f in (fuente, pergola, banco, estanque):
        piezas.append((f'hito_{f.__name__}', f))
    return piezas


if __name__ == '__main__':
    carpeta = sys.argv[1]
    os.makedirs(carpeta, exist_ok=True)
    pedidas = set(sys.argv[2:])
    for nombre, hacer in todas():
        if pedidas and nombre not in pedidas:
            continue
        if not pedidas and os.path.exists(f'{carpeta}/{nombre}.json'):
            continue
        hacer(carpeta)
        print('HECHA', nombre, flush=True)
