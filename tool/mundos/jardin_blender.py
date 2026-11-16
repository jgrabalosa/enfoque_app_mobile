"""El jardín de Dulce en 3D (prueba), con la misma cámara isométrica que
Neotokyo+ 3D. Todo por script y con semilla.

    python3 jardin_blender.py escena SALIDA_SIN_EXTENSION

Saca tres imágenes: el color (SALIDA_color.png), las normales
(SALIDA_normal.png) y la profundidad (SALIDA_prof.png). Las dos últimas
sirven para dibujar los contornos al pasarlo a lápiz (lapiz_post.py).
"""
import math
import random
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, __import__('os').path.dirname(__file__))
from ciudad_blender import camara_isometrica  # noqa: E402
import plantas_blender as pl  # noqa: E402

_mats = {}


def mat(nombre, color, rugosidad=0.6, sss=0.0, brillo=0.0):
    clave = (nombre, color)
    if clave in _mats:
        return _mats[clave]
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rugosidad
    if sss > 0:
        p.inputs['Subsurface Weight'].default_value = sss
        p.inputs['Subsurface Radius'].default_value = (0.2, 0.1, 0.1)
    if brillo > 0:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = brillo
    _mats[clave] = m
    return m


def hex_(h):
    h = h.lstrip('#')
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


VERDE = hex_('#5E9A4A')
VERDE_OSC = hex_('#3E7038')
VERDE_CLARO = hex_('#8DBA5E')


def _poner(o, material, col):
    o.data.materials.append(material)
    for c in o.users_collection:
        c.objects.unlink(o)
    col.objects.link(o)
    bpy.ops.object.shade_smooth()
    return o


def esfera(pos, escala, material, col, rot=(0, 0, 0), segmentos=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segmentos, ring_count=segmentos // 2,
                                         location=pos, rotation=rot)
    o = bpy.context.object
    o.scale = escala
    return _poner(o, material, col)


def tallo(a, b, r, material, col):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=r, depth=d.length,
                                        location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.to_track_quat('Z', 'Y')
    return _poner(o, material, col)


def hoja(base, angulo, inclinacion, largo, ancho, material, col):
    """Una hoja: un elipsoide aplastado, inclinado hacia fuera."""
    dx, dy = math.cos(angulo), math.sin(angulo)
    centro = (base[0] + dx * largo * 0.45 * math.cos(inclinacion),
              base[1] + dy * largo * 0.45 * math.cos(inclinacion),
              base[2] + largo * 0.45 * math.sin(inclinacion))
    o = esfera(centro, (largo / 2, ancho / 2, 0.012), material, col,
               rot=(0, -inclinacion, angulo), segmentos=12)
    return o


def mata(centro, radio, alto, r, col, n=14, color=VERDE):
    """Un montón de follaje: bolas verdes apiñadas."""
    m = mat('follaje', color, 0.8)
    for _ in range(n):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * radio * 0.75
        z = alto * (0.35 + 0.5 * r.random()) * (1 - d / radio * 0.5)
        s = radio * (0.28 + 0.18 * r.random())
        esfera((centro[0] + math.cos(a) * d, centro[1] + math.sin(a) * d, z),
               (s, s, s * 0.8), m, col, segmentos=10)


# ── Las plantas ─────────────────────────────────────────────────────────────

def tulipanes(c, r, col, color):
    tal = mat('tallo', VERDE_OSC, 0.6)
    pet = mat('tulipan', color, 0.45, sss=0.15)
    hoj = mat('hoja', VERDE, 0.6)
    for k in range(5):
        a = r.random() * math.tau
        d = r.random() * 0.12
        base = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d, 0)
        h = 0.42 + r.random() * 0.15
        top = (base[0] + (r.random() - 0.5) * 0.05, base[1] + (r.random() - 0.5) * 0.05, h)
        tallo(base, top, 0.008, tal, col)
        for j in range(6):
            aa = j * math.tau / 6 + r.random() * 0.2
            ab = 0.18 if j % 2 else 0.1
            esfera((top[0] + math.cos(aa) * 0.025, top[1] + math.sin(aa) * 0.025, top[2] + 0.04),
                   (0.03, 0.022, 0.06), pet, col, rot=(0, ab, aa), segmentos=12)
        for j in range(2):
            hoja(base, a + j * math.pi + 0.4, math.radians(65), 0.26, 0.06, hoj, col)


def margaritas(c, r, col, color):
    mata(c, 0.22, 0.12, r, col, n=10)
    blanco = mat('petalo', color, 0.5, sss=0.1)
    amarillo = mat('centro_m', hex_('#F2B630'), 0.5)
    tal = mat('tallo', VERDE_OSC, 0.6)
    for k in range(6):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.16
        base = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d, 0.05)
        h = 0.2 + r.random() * 0.12
        top = (base[0], base[1], h)
        tallo(base, top, 0.005, tal, col)
        esfera((top[0], top[1], top[2] + 0.008), (0.022, 0.022, 0.012), amarillo, col, segmentos=10)
        n = 14
        for j in range(n):
            aa = j * math.tau / n
            esfera((top[0] + math.cos(aa) * 0.045, top[1] + math.sin(aa) * 0.045, top[2]),
                   (0.03, 0.009, 0.004), blanco, col, rot=(0, 0, aa), segmentos=8)


def lavanda(c, r, col, color):
    mata(c, 0.2, 0.1, r, col, n=8, color=hex_('#7C9A78'))
    flor = mat('lavanda', color, 0.7)
    tal = mat('tallo_l', hex_('#7C9A78'), 0.7)
    for k in range(16):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.14
        base = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d, 0.05)
        sale = 0.12 + d
        top = (base[0] + math.cos(a) * sale * 0.4, base[1] + math.sin(a) * sale * 0.4,
               0.35 + r.random() * 0.12)
        tallo(base, top, 0.004, tal, col)
        for j in range(6):
            t = j / 6
            p = Vector(base).lerp(Vector(top), 0.7 + 0.3 * t)
            esfera(tuple(p), (0.012, 0.012, 0.016), flor, col, segmentos=8)


def rosal(c, r, col, color):
    mata(c, 0.26, 0.32, r, col, n=18, color=VERDE_OSC)
    rosa = mat('rosa', color, 0.45, sss=0.2)
    oscuro = mat('rosa_osc', tuple(x * 0.55 for x in color), 0.5, sss=0.2)
    for k in range(7):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.2
        z = 0.2 + r.random() * 0.18
        p = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d, z)
        # Capas de pétalos: de fuera adentro, cada vez más cerradas.
        for j, (rad, alto) in enumerate(((0.05, 0.025), (0.038, 0.03), (0.026, 0.032))):
            esfera((p[0], p[1], p[2] + j * 0.008), (rad, rad, alto),
                   rosa if j < 2 else oscuro, col, rot=(0, 0, r.random() * 3), segmentos=12)


def hortensia(c, r, col, color):
    mata(c, 0.3, 0.26, r, col, n=16, color=VERDE)
    flor = mat('hortensia', color, 0.6, sss=0.1)
    claro = mat('hortensia_c', tuple(min(1, x * 1.35) for x in color), 0.6, sss=0.1)
    for k in range(5):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.2
        cab = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d, 0.28 + r.random() * 0.08)
        for j in range(26):
            u = Vector((r.gauss(0, 1), r.gauss(0, 1), abs(r.gauss(0, 1)))).normalized() * 0.065
            esfera(tuple(Vector(cab) + u), (0.022, 0.022, 0.018),
                   flor if r.random() < 0.6 else claro, col, segmentos=8)


def girasol(c, r, col, _color):
    tal = mat('tallo_g', VERDE, 0.6)
    hoj = mat('hoja_g', VERDE, 0.6)
    pet = mat('girasol', hex_('#F2C230'), 0.5, sss=0.1)
    disco = mat('disco', hex_('#5A3A22'), 0.9)
    for k in range(3):
        a = r.random() * math.tau
        d = r.random() * 0.1
        base = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d, 0)
        h = 0.7 + r.random() * 0.2
        top = (base[0], base[1], h)
        tallo(base, top, 0.012, tal, col)
        for j in range(3):
            hoja((base[0], base[1], h * (0.3 + j * 0.2)), a + j * 2.1, math.radians(30), 0.18, 0.12, hoj, col)
        # La flor mira hacia la cámara, algo inclinada.
        esfera((top[0], top[1], top[2]), (0.06, 0.06, 0.02), disco, col, rot=(0.5, 0, -0.8), segmentos=14)
        for j in range(18):
            aa = j * math.tau / 18
            v = Vector((math.cos(aa) * 0.085, math.sin(aa) * 0.085, 0))
            v.rotate(Euler((0.5, 0, -0.8)))
            esfera(tuple(Vector(top) + v), (0.04, 0.014, 0.006), pet, col,
                   rot=(0.5, 0, -0.8 + aa), segmentos=8)


def amapolas(c, r, col, color):
    tal = mat('tallo_a', VERDE_CLARO, 0.6)
    pet = mat('amapola', color, 0.45, sss=0.25)
    negro = mat('centro_a', hex_('#2A1E2A'), 0.6)
    mata(c, 0.18, 0.08, r, col, n=7, color=VERDE_CLARO)
    for k in range(5):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.14
        base = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d, 0.04)
        top = (base[0] + (r.random() - .5) * .08, base[1] + (r.random() - .5) * .08, 0.32 + r.random() * 0.15)
        tallo(base, top, 0.004, tal, col)
        for j in range(4):
            aa = j * math.pi / 2 + r.random() * 0.3
            esfera((top[0] + math.cos(aa) * 0.03, top[1] + math.sin(aa) * 0.03, top[2] + 0.015),
                   (0.045, 0.04, 0.012), pet, col, rot=(0, -0.5, aa), segmentos=12)
        esfera((top[0], top[1], top[2] + 0.025), (0.012, 0.012, 0.012), negro, col, segmentos=8)


ROSA = hex_('#E85A8A')


def materiales(especie, color):
    """Los materiales de una planta: tallo, hojas, flor y centro."""
    hoja = {'lavanda': hex_('#8FA88A'), 'amapolas': VERDE_CLARO, 'rosal': VERDE_OSC}.get(especie, VERDE)
    m = {
        'tallo': mat('tallo_' + especie, tuple(c * 0.75 for c in hoja), 0.6),
        'hoja': mat('hoja_' + especie, hoja, 0.55, sss=0.05),
        'flor': mat('flor_' + especie, color, 0.45, sss=0.2),
    }
    centro = {
        'margaritas': hex_('#F2B630'),
        'girasol': hex_('#5A3A22'),
        'amapolas': hex_('#2A1E2A'),
        'rosal': tuple(c * 0.6 for c in color),
        'hortensia': tuple(min(1.0, c * 1.4) for c in color),
    }.get(especie, color)
    m['centro'] = mat('centro_' + especie, centro, 0.5, sss=0.1)
    return m


ALTURA = {'girasol': 1.0, 'tulipanes': 0.55, 'lavanda': 0.5, 'amapolas': 0.45,
          'rosal': 0.42, 'hortensia': 0.38, 'margaritas': 0.3}

COLORES = {
    'tulipanes': [ROSA, hex_('#F29BBF'), hex_('#D9473A'), hex_('#F2C230')],
    'margaritas': [hex_('#FFFDF8')],
    'lavanda': [hex_('#9C7BD0'), hex_('#B79BE0')],
    'rosal': [ROSA, hex_('#F29BBF'), hex_('#C2367A')],
    'hortensia': [hex_('#8FAAE6'), hex_('#E9A3C9'), hex_('#B79BE0')],
    'girasol': [hex_('#F7C21B')],
    'amapolas': [hex_('#D9473A'), hex_('#F07A5A')],
}


# ── El parterre y el suelo ─────────────────────────────────────────────────

def parterre(centro, radio, col, r):
    """Un parterre redondo un poco elevado, con borde de piedrecitas y
    tierra."""
    tierra = mat('tierra', hex_('#7A5A42'), 0.95)
    piedra = mat('piedra', hex_('#D8CFC2'), 0.8)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radio, depth=0.08,
                                        location=(centro[0], centro[1], 0.04))
    _poner(bpy.context.object, tierra, col)
    n = int(radio * 2 * math.pi / 0.11)
    for k in range(n):
        a = k * math.tau / n
        s = 0.05 + r.random() * 0.015
        esfera((centro[0] + math.cos(a) * radio, centro[1] + math.sin(a) * radio, 0.06),
               (s, s * 0.8, s * 0.7), piedra, col, rot=(0, 0, a), segmentos=8)


def cesped(col, lado=9.0):
    verde = bpy.data.materials.new('cesped')
    verde.use_nodes = True
    nt = verde.node_tree
    p = nt.nodes['Principled BSDF']
    p.inputs['Roughness'].default_value = 0.95
    ruido = nt.nodes.new('ShaderNodeTexNoise')
    ruido.inputs['Scale'].default_value = 3.0
    ruido.inputs['Detail'].default_value = 6.0
    rampa = nt.nodes.new('ShaderNodeValToRGB')
    rampa.color_ramp.elements[0].color = (*hex_('#8DB86A'), 1)
    rampa.color_ramp.elements[1].color = (*hex_('#B5D08A'), 1)
    nt.links.new(ruido.outputs['Fac'], rampa.inputs['Fac'])
    nt.links.new(rampa.outputs['Color'], p.inputs['Base Color'])
    bpy.ops.mesh.primitive_plane_add(size=lado, location=(0, 0, 0))
    _poner(bpy.context.object, verde, col)


def camino(a, b, ancho, col, r):
    grava = mat('grava', hex_('#E3D6C2'), 0.95)
    a, b = Vector((*a, 0)), Vector((*b, 0))
    d = (b - a)
    bpy.ops.mesh.primitive_plane_add(size=1, location=((a + b) / 2) + Vector((0, 0, 0.004)))
    o = bpy.context.object
    o.scale = (d.length, ancho, 1)
    o.rotation_euler = (0, 0, math.atan2(d.y, d.x))
    _poner(o, grava, col)
    # Losas redondeadas encima.
    losa = mat('losa', hex_('#CFC3B0'), 0.85)
    pasos = int(d.length / 0.32)
    for k in range(pasos):
        p = a.lerp(b, (k + 0.5) / pasos)
        esfera((p.x + (r.random() - .5) * 0.06, p.y + (r.random() - .5) * 0.06, 0.012),
               (0.13, 0.11, 0.01), losa, col, rot=(0, 0, r.random() * 3), segmentos=12)


def arbol(pos, col, r):
    """Un árbol: tronco con ramas y una copa de matas cubiertas de hojas."""
    tronco = mat('tronco', hex_('#7A5A42'), 0.9)
    copa = mat('copa', hex_('#6FA35A'), 0.8, sss=0.05)
    copa2 = mat('copa2', hex_('#8DBA5E'), 0.8, sss=0.05)
    base = Vector((pos[0], pos[1], 0))
    pl.tallo(tuple(base), tuple(base + Vector((0, 0, 1.0))), 0.07, tronco, col)
    hoja = pl.lamina(0.11, 0.06, copa=0.25, curva=-0.1, punta=0.8)
    for k in range(16):
        u = Vector((r.gauss(0, 1), r.gauss(0, 1), r.gauss(0, 0.6) + 0.2)).normalized()
        centro = base + Vector((0, 0, 1.35)) + u * (0.42 * r.random() ** 0.4)
        pl.tallo(tuple(base + Vector((0, 0, 0.85))), tuple(centro), 0.025, tronco, col)
        radio = 0.2 + r.random() * 0.08
        o = pl.bola(tuple(centro), radio * 0.85, copa, col, segmentos=12)
        for j in range(46):
            v = Vector((r.gauss(0, 1), r.gauss(0, 1), r.gauss(0, 1))).normalized()
            p = centro + v * radio
            rumbo = math.atan2(v.y, v.x)
            alz = math.asin(max(-1, min(1, v.z)))
            pl.hoja_en(tuple(p), rumbo + (r.random() - .5), alz + (r.random() - .5) * 0.6,
                       hoja, copa if r.random() < 0.55 else copa2, col, giro=r.random() * 3)


# ── Escena de prueba ───────────────────────────────────────────────────────

def preparar(res):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Base Contrast'
    mundo = bpy.data.worlds.new('dia')
    sc.world = mundo
    mundo.use_nodes = True
    fondo = mundo.node_tree.nodes['Background']
    fondo.inputs['Color'].default_value = (0.75, 0.8, 0.95, 1)
    fondo.inputs['Strength'].default_value = 0.9
    # El sol de la tarde, cálido, desde arriba a la izquierda de la pantalla.
    bpy.ops.object.light_add(type='SUN', rotation=(math.radians(40), 0, math.radians(-75)))
    sol = bpy.context.object
    sol.data.energy = 3.2
    sol.data.angle = math.radians(8)
    sol.data.color = (1.0, 0.93, 0.82)
    return sc


def escena(salida, semilla=7, cuantas=10):
    r = random.Random(semilla)
    sc = preparar((1100, 1100))
    col = bpy.data.collections.new('jardin')
    sc.collection.children.link(col)
    cesped(col, lado=5.2)
    camino((-2.6, -0.2), (-1.1, -0.1), 0.42, col, r)
    camino((1.15, 0.2), (2.6, 0.35), 0.42, col, r)
    parterre((0, 0), 1.1, col, r)
    antes_arbol = set(col.objects)
    arbol((-1.5, 1.4), col, r)
    for o in set(col.objects) - antes_arbol:
        o.pass_index = 1  # el árbol no es del parterre: no va a boceto
    # 10 plantas en espiral de girasol dentro del parterre. Como hace un
    # jardinero: las altas detrás (arriba en la pantalla) y las bajas
    # delante, para que se vean todas.
    aureo = math.pi * (3 - math.sqrt(5))
    sitios = []
    for k in range(10):
        rad = 0.8 * math.sqrt((k + 0.6) / 10.3)
        a = k * aureo + 0.4
        sitios.append((math.cos(a) * rad, math.sin(a) * rad, k))
    sitios.sort(key=lambda p: p[0] - p[1])  # de atrás adelante
    especies = list(pl.ESPECIES) + [r.choice([e for e in pl.ESPECIES if e is not pl.girasol]) for _ in range(3)]
    especies.sort(key=lambda e: -ALTURA[e.__name__] + r.random() * 0.05)
    for c, especie in zip(sitios, especies):
        nombre = especie.__name__
        color = r.choice(COLORES[nombre])
        if c[2] >= cuantas:  # aún no se ha plantado (crecen desde el centro)
            continue
        # Cada planta cuelga de un objeto vacío que la pone en su sitio.
        planta = bpy.data.objects.new('planta', None)
        col.objects.link(planta)
        antes = set(col.objects)
        especie(r, col, materiales(nombre, color))
        for o in set(col.objects) - antes:
            if o.parent is None:
                o.parent = planta
        escala = (1.25 if nombre == 'girasol' else 1.9) + r.random() * 0.3
        planta.location = (c[0], c[1], 0.08)
        planta.scale = (escala, escala, escala)
    camara_isometrica(sc, (0, 0, 0.3), 5.6)

    pasadas(sc, salida)


def pasadas(sc, salida):
    """El color y, sin luz, las normales, la profundidad, la altura y el
    índice (para el lápiz)."""
    sc.render.filepath = salida + '_color.png'
    bpy.ops.render.render(write_still=True)

    # Normales y profundidad, sin luz, para los contornos.
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.cycles.samples = 8
    sc.cycles.use_denoising = False
    sc.render.image_settings.color_depth = '16'
    sc.render.film_transparent = False
    sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0
    for nombre, salida_nodo in (('normal', 'normal'), ('prof', 'prof'), ('altura', 'altura'),
                                ('indice', 'indice')):
        sc.render.image_settings.color_mode = 'RGB' if nombre == 'normal' else 'BW'
        m = bpy.data.materials.new(nombre)
        m.use_nodes = True
        n = m.node_tree.nodes
        n.clear()
        out = n.new('ShaderNodeOutputMaterial')
        em = n.new('ShaderNodeEmission')
        if salida_nodo == 'normal':
            g = n.new('ShaderNodeNewGeometry')
            mapa = n.new('ShaderNodeVectorMath')
            mapa.operation = 'MULTIPLY_ADD'
            mapa.inputs[1].default_value = (0.5, 0.5, 0.5)
            mapa.inputs[2].default_value = (0.5, 0.5, 0.5)
            m.node_tree.links.new(g.outputs['Normal'], mapa.inputs[0])
            m.node_tree.links.new(mapa.outputs[0], em.inputs['Color'])
        elif salida_nodo == 'indice':
            info = n.new('ShaderNodeObjectInfo')
            m.node_tree.links.new(info.outputs['Object Index'], em.inputs['Color'])
        elif salida_nodo == 'altura':
            g = n.new('ShaderNodeNewGeometry')
            sep = n.new('ShaderNodeSeparateXYZ')
            div = n.new('ShaderNodeMath')
            div.operation = 'DIVIDE'
            div.inputs[1].default_value = 3.0
            m.node_tree.links.new(g.outputs['Position'], sep.inputs[0])
            m.node_tree.links.new(sep.outputs['Z'], div.inputs[0])
            m.node_tree.links.new(div.outputs[0], em.inputs['Color'])
        else:
            cam = n.new('ShaderNodeCameraData')
            div = n.new('ShaderNodeMapRange')
            div.inputs['From Min'].default_value = 30.0
            div.inputs['From Max'].default_value = 50.0
            m.node_tree.links.new(cam.outputs['View Z Depth'], div.inputs['Value'])
            m.node_tree.links.new(div.outputs['Result'], em.inputs['Color'])
        m.node_tree.links.new(em.outputs[0], out.inputs['Surface'])
        sc.view_layers[0].material_override = m
        sc.render.filepath = f'{salida}_{nombre}.png'
        bpy.ops.render.render(write_still=True)
    sc.view_layers[0].material_override = None


if __name__ == '__main__':
    if sys.argv[1] == 'escena':
        escena(sys.argv[2], cuantas=int(sys.argv[3]) if len(sys.argv) > 3 else 10)
