"""Las plantas del jardín de Dulce, con hojas y pétalos de verdad: láminas
curvas (no bolas), cada una con su copa (lo que se ahueca) y su curva (lo que
se dobla hacia arriba o hacia abajo).

Cada planta se construye en el origen; quien la llama la mueve y la escala
con su objeto padre.
"""
import math

import bpy
from mathutils import Euler, Vector

_mallas = {}


def lamina(largo, ancho, copa=0.2, curva=0.0, punta=0.7, base=0.15, muescas=0):
    """Una lámina (pétalo u hoja) a lo largo de +X, desde el origen.

    copa: cuánto se ahueca hacia arriba (por los bordes, + = cuchara).
    curva: cuánto se dobla la punta hacia arriba (+) o abajo (−).
    punta: <1 redondeada, >1 afilada. muescas: dientes en la punta."""
    clave = (round(largo, 4), round(ancho, 4), copa, curva, punta, base, muescas)
    if clave in _mallas:
        return _mallas[clave]
    nu, nv = 12, 6
    verts, caras = [], []
    for i in range(nu + 1):
        u = i / nu
        w = max(base * (1 - u), math.sin(math.pi * (u ** 0.75)) ** punta)
        if muescas and u > 0.85:
            w = max(w, 0.35)
        for j in range(nv + 1):
            v = j / nv * 2 - 1
            x = u * largo
            if muescas and i == nu:
                x -= largo * 0.06 * abs(math.sin(muescas * math.pi * (v + 1) / 2))
            y = v * ancho / 2 * w
            z = copa * ancho * v * v * w + curva * largo * u * u
            verts.append((x, y, z))
    for i in range(nu):
        for j in range(nv):
            a = i * (nv + 1) + j
            caras.append((a, a + 1, a + nv + 2, a + nv + 1))
    m = bpy.data.meshes.new('lamina')
    m.from_pydata(verts, [], caras)
    for p in m.polygons:
        p.use_smooth = True
    m.materials.append(None)
    _mallas[clave] = m
    return m


def poner(malla, material, col, pos=(0, 0, 0), rot=(0, 0, 0), escala=1.0, padre=None):
    o = bpy.data.objects.new('p', malla)
    col.objects.link(o)
    o.material_slots[0].link = 'OBJECT'
    o.material_slots[0].material = material
    o.location = pos
    o.rotation_euler = Euler(rot, 'XYZ')
    o.scale = (escala, escala, escala) if isinstance(escala, (int, float)) else escala
    if padre is not None:
        o.parent = padre
    return o


def hoja_en(base, rumbo, alzada, malla, material, col, giro=0.0, padre=None):
    """Una lámina que sale de [base] hacia [rumbo] (ángulo en el suelo),
    levantada [alzada] radianes."""
    return poner(malla, material, col, base, (giro, -alzada, rumbo), padre=padre)


_esfera = {}


def bola(pos, radio, material, col, aplastada=1.0, padre=None, segmentos=10):
    clave = segmentos
    if clave not in _esfera:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segmentos, ring_count=segmentos // 2)
        o = bpy.context.object
        for p in o.data.polygons:
            p.use_smooth = True
        o.data.materials.append(None)
        _esfera[clave] = o.data
        bpy.data.objects.remove(o)
    return poner(_esfera[clave], material, col, pos, escala=(radio, radio, radio * aplastada), padre=padre)


_cilindro = {}


def tallo(a, b, r, material, col):
    if 'c' not in _cilindro:
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=1, depth=1)
        o = bpy.context.object
        o.data.materials.append(None)
        _cilindro['c'] = o.data
        bpy.data.objects.remove(o)
    a, b = Vector(a), Vector(b)
    d = b - a
    o = poner(_cilindro['c'], material, col, tuple((a + b) / 2), escala=(r, r, d.length))
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.to_track_quat('Z', 'Y')
    return o


def mata(r, col, material, n, radio, alto, largo, ancho, alzada=(0.3, 0.9)):
    """Un montón de hojas que salen del centro hacia fuera y hacia arriba."""
    m = lamina(largo, ancho, copa=0.25, curva=-0.12, punta=0.8)
    for k in range(n):
        a = r.random() * math.tau
        d = r.random() * radio * 0.4
        base = (math.cos(a) * d, math.sin(a) * d, alto * r.random() * 0.4)
        hoja_en(base, a + (r.random() - 0.5) * 0.6,
                alzada[0] + (alzada[1] - alzada[0]) * r.random(), m, material, col,
                giro=(r.random() - 0.5) * 0.6).scale = (0.75 + 0.5 * r.random(),) * 3


# ── Las especies ───────────────────────────────────────────────────────────


def tulipanes(r, col, m):
    for k in range(5):
        a = r.random() * math.tau
        d = r.random() * 0.1
        base = (math.cos(a) * d, math.sin(a) * d, 0)
        h = 0.42 + r.random() * 0.15
        top = (base[0] + (r.random() - .5) * 0.05, base[1] + (r.random() - .5) * 0.05, h)
        tallo(base, top, 0.006, m['tallo'], col)
        hoja = lamina(0.3, 0.075, copa=0.35, curva=-0.08, punta=1.1)
        for j in range(2):
            hoja_en(base, a + j * math.pi + r.random(), math.radians(70), hoja, m['hoja'], col)
        petalo = lamina(0.11, 0.065, copa=0.45, curva=0.05, punta=0.55)
        for j in range(6):
            aa = j * math.tau / 6 + (0.5 if j % 2 else 0)
            dentro = 0.006 if j % 2 else 0.012
            p = (top[0] + math.cos(aa) * dentro, top[1] + math.sin(aa) * dentro, top[2] - 0.01)
            hoja_en(p, aa, math.radians(74), petalo, m['flor'], col)


def margaritas(r, col, m):
    mata(r, col, m['hoja'], 16, 0.16, 0.05, 0.13, 0.035, alzada=(0.2, 0.6))
    petalo = lamina(0.055, 0.014, copa=0.15, curva=-0.03, punta=0.5)
    for k in range(7):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.15
        base = (math.cos(a) * d, math.sin(a) * d, 0.04)
        top = (base[0], base[1], 0.2 + r.random() * 0.12)
        tallo(base, top, 0.004, m['tallo'], col)
        n = 16
        for j in range(n):
            aa = j * math.tau / n + r.random() * 0.1
            hoja_en(top, aa, math.radians(8 + r.random() * 10), petalo, m['flor'], col)
        bola((top[0], top[1], top[2] + 0.006), 0.018, m['centro'], col, aplastada=0.6)


def lavanda(r, col, m):
    mata(r, col, m['hoja'], 18, 0.12, 0.04, 0.12, 0.014, alzada=(0.5, 1.1))
    for k in range(16):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.12
        base = (math.cos(a) * d, math.sin(a) * d, 0.04)
        sale = 0.1 + d
        top = (base[0] + math.cos(a) * sale * 0.45, base[1] + math.sin(a) * sale * 0.45,
               0.36 + r.random() * 0.12)
        tallo(base, top, 0.003, m['tallo'], col)
        for j in range(7):
            p = Vector(base).lerp(Vector(top), 0.68 + 0.32 * j / 6)
            bola(tuple(p), 0.011 - j * 0.0007, m['flor'], col, aplastada=1.4, segmentos=8)


def rosal(r, col, m):
    hoja = lamina(0.07, 0.042, copa=0.2, curva=-0.05, punta=0.9)
    for k in range(46):
        # Hojas sobre una cúpula: el arbusto.
        a = r.random() * math.tau
        e = r.random() * 1.2
        p = (math.cos(a) * math.cos(e) * 0.2, math.sin(a) * math.cos(e) * 0.2,
             0.06 + math.sin(e) * 0.22)
        hoja_en(p, a + (r.random() - .5), math.radians(-10 + 60 * r.random()), hoja, m['hoja'], col,
                giro=r.random())
    for k in range(6):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.16
        c = (math.cos(a) * d, math.sin(a) * d, 0.24 + r.random() * 0.12)
        for anillo, (n, largo, alz) in enumerate(((5, 0.065, 25), (5, 0.05, 50), (4, 0.036, 72))):
            pet = lamina(largo, largo * 1.1, copa=0.5, curva=0.15, punta=0.45)
            for j in range(n):
                aa = j * math.tau / n + anillo * 0.6 + r.random() * 0.2
                hoja_en(c, aa, math.radians(alz), pet, m['flor'] if anillo < 2 else m['centro'], col)
        bola((c[0], c[1], c[2] + 0.012), 0.01, m['centro'], col)


def hortensia(r, col, m):
    mata(r, col, m['hoja'], 22, 0.22, 0.1, 0.13, 0.075, alzada=(0.1, 0.6))
    petalo = lamina(0.018, 0.016, copa=0.15, curva=0.0, punta=0.5)
    for k in range(5):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.16
        cab = Vector((math.cos(a) * d, math.sin(a) * d, 0.25 + r.random() * 0.08))
        for j in range(22):
            u = Vector((r.gauss(0, 1), r.gauss(0, 1), abs(r.gauss(0, 1)) + 0.3)).normalized()
            p = cab + u * 0.065
            mat_flor = m['flor'] if r.random() < 0.65 else m['centro']
            rumbo = math.atan2(u.y, u.x)
            alz = math.asin(max(-1, min(1, u.z)))
            for q in range(4):
                hoja_en(tuple(p), rumbo + q * math.pi / 2, alz * 0.5, petalo, mat_flor, col, giro=q)


def girasol(r, col, m):
    hoja = lamina(0.17, 0.12, copa=0.25, curva=-0.15, punta=0.9)
    petalo = lamina(0.07, 0.022, copa=0.2, curva=0.0, punta=0.6)
    hacia = Vector((0.55, -0.55, 0.45)).normalized()  # mira a la cámara
    for k in range(3):
        a = r.random() * math.tau
        d = r.random() * 0.08
        base = (math.cos(a) * d, math.sin(a) * d, 0)
        h = 0.7 + r.random() * 0.2
        top = (base[0], base[1], h)
        tallo(base, top, 0.01, m['tallo'], col)
        for j in range(4):
            hoja_en((base[0], base[1], h * (0.25 + j * 0.15)), a + j * 2.1, math.radians(15),
                    hoja, m['hoja'], col)
        cabeza = bpy.data.objects.new('cabeza', None)
        col.objects.link(cabeza)
        cabeza.location = top
        cabeza.rotation_mode = 'QUATERNION'
        cabeza.rotation_quaternion = hacia.to_track_quat('Z', 'Y')
        bola((0, 0, 0), 0.055, m['centro'], col, aplastada=0.35, padre=cabeza)
        for j in range(22):
            aa = j * math.tau / 22
            hoja_en((math.cos(aa) * 0.045, math.sin(aa) * 0.045, 0), aa,
                    math.radians(6), petalo, m['flor'], col, padre=cabeza)
        for j in range(12):
            aa = j * math.tau / 12 + 0.13
            hoja_en((math.cos(aa) * 0.04, math.sin(aa) * 0.04, -0.004), aa,
                    math.radians(-4), petalo, m['flor'], col, padre=cabeza)


def amapolas(r, col, m):
    mata(r, col, m['hoja'], 10, 0.12, 0.03, 0.11, 0.03, alzada=(0.3, 0.8))
    petalo = lamina(0.055, 0.07, copa=0.5, curva=0.18, punta=0.4)
    for k in range(5):
        a = r.random() * math.tau
        d = math.sqrt(r.random()) * 0.13
        base = (math.cos(a) * d, math.sin(a) * d, 0.03)
        top = (base[0] + (r.random() - .5) * .08, base[1] + (r.random() - .5) * .08,
               0.32 + r.random() * 0.15)
        tallo(base, top, 0.0035, m['tallo'], col)
        for j in range(4):
            aa = j * math.pi / 2 + r.random() * 0.3
            hoja_en(top, aa, math.radians(32 + r.random() * 12), petalo, m['flor'], col)
        bola((top[0], top[1], top[2] + 0.012), 0.011, m['centro'], col)


ESPECIES = [tulipanes, margaritas, lavanda, rosal, hortensia, girasol, amapolas]
