"""Edificios de Neotokyo+ renderizados en 3D con Blender, por código.

Uso (con el módulo `bpy` de Blender):
    python3 ciudad_blender.py escena  SALIDA.png   # una manzana montada
    python3 ciudad_blender.py sprites CARPETA      # cada edificio, suelto y con fondo transparente

Todo sale de una semilla: el mismo script da siempre los mismos edificios.
"""
import math
import random
import sys

import bpy

NEONES = [(1.0, 0.18, 0.53), (0.0, 0.9, 1.0), (1.0, 0.89, 0.28), (0.63, 0.42, 1.0)]
VENTANAS = [(1.0, 0.78, 0.45), (1.0, 0.9, 0.7), (0.55, 0.9, 1.0), (1.0, 0.55, 0.8)]


# ── Materiales ───────────────────────────────────────────────────────────────

_cache = {}


def emision(color, fuerza):
    clave = ('e', color, fuerza)
    if clave in _cache:
        return _cache[clave]
    m = bpy.data.materials.new('emision')
    m.use_nodes = True
    n = m.node_tree.nodes
    n.clear()
    out = n.new('ShaderNodeOutputMaterial')
    em = n.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (*color, 1)
    em.inputs['Strength'].default_value = fuerza
    m.node_tree.links.new(em.outputs[0], out.inputs[0])
    _cache[clave] = m
    return m


def liso(color, rugosidad=0.5, metal=0.0):
    clave = ('l', color, rugosidad, metal)
    if clave in _cache:
        return _cache[clave]
    m = bpy.data.materials.new('liso')
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rugosidad
    b.inputs['Metallic'].default_value = metal
    _cache[clave] = m
    return m


def fachada(base, ventana, encendidas, semilla, ancho=0.1, alto=0.13):
    """Paredes oscuras y algo metálicas con una rejilla de ventanas; unas
    encendidas y otras no. Las ventanas solo en las paredes, nunca arriba."""
    m = bpy.data.materials.new('fachada')
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    bsdf = n['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*base, 1)
    bsdf.inputs['Roughness'].default_value = 0.32
    bsdf.inputs['Metallic'].default_value = 0.55
    tc = n.new('ShaderNodeTexCoord')
    ladrillo = n.new('ShaderNodeTexBrick')
    ladrillo.offset = 0
    ladrillo.squash = 1
    ladrillo.inputs['Scale'].default_value = 1
    ladrillo.inputs['Brick Width'].default_value = ancho
    ladrillo.inputs['Row Height'].default_value = alto
    ladrillo.inputs['Mortar Size'].default_value = 0.028
    ladrillo.inputs['Color1'].default_value = (1, 1, 1, 1)
    ladrillo.inputs['Color2'].default_value = (1, 1, 1, 1)
    ladrillo.inputs['Mortar'].default_value = (0, 0, 0, 1)
    # Para que la rejilla vaya por las dos caras: x + y en horizontal.
    sep = n.new('ShaderNodeSeparateXYZ')
    l.new(tc.outputs['Object'], sep.inputs[0])
    suma = n.new('ShaderNodeMath')
    suma.operation = 'ADD'
    l.new(sep.outputs['X'], suma.inputs[0])
    l.new(sep.outputs['Y'], suma.inputs[1])
    comb = n.new('ShaderNodeCombineXYZ')
    l.new(suma.outputs[0], comb.inputs['X'])
    l.new(sep.outputs['Z'], comb.inputs['Y'])
    l.new(comb.outputs[0], ladrillo.inputs['Vector'])
    # ¿Encendida? Ruido blanco por ventana.
    celda = n.new('ShaderNodeVectorMath')
    celda.operation = 'SNAP'
    celda.inputs[1].default_value = (ancho, alto, 1)
    l.new(comb.outputs[0], celda.inputs[0])
    desplaza = n.new('ShaderNodeVectorMath')
    desplaza.operation = 'ADD'
    desplaza.inputs[1].default_value = (semilla * 13.1, semilla * 7.7, 0)
    l.new(celda.outputs[0], desplaza.inputs[0])
    ruido = n.new('ShaderNodeTexWhiteNoise')
    ruido.noise_dimensions = '3D'
    l.new(desplaza.outputs[0], ruido.inputs['Vector'])
    umbral = n.new('ShaderNodeMath')
    umbral.operation = 'LESS_THAN'
    umbral.inputs[1].default_value = encendidas
    l.new(ruido.outputs['Value'], umbral.inputs[0])
    # Algunas ventanas más tenues que otras.
    tenue = n.new('ShaderNodeMath')
    tenue.operation = 'MULTIPLY_ADD'
    tenue.inputs[1].default_value = 3.0
    tenue.inputs[2].default_value = 0.6
    l.new(ruido.outputs['Value'], tenue.inputs[0])
    # Fac vale 1 en la junta: la ventana es lo de dentro.
    hueco = n.new('ShaderNodeMath')
    hueco.operation = 'SUBTRACT'
    hueco.inputs[0].default_value = 1.0
    l.new(ladrillo.outputs['Fac'], hueco.inputs[1])
    ventanas = n.new('ShaderNodeMath')
    ventanas.operation = 'MULTIPLY'
    l.new(hueco.outputs[0], ventanas.inputs[0])
    l.new(umbral.outputs[0], ventanas.inputs[1])
    fuerza = n.new('ShaderNodeMath')
    fuerza.operation = 'MULTIPLY'
    l.new(ventanas.outputs[0], fuerza.inputs[0])
    l.new(tenue.outputs[0], fuerza.inputs[1])
    # Solo en las paredes.
    geo = n.new('ShaderNodeNewGeometry')
    sepn = n.new('ShaderNodeSeparateXYZ')
    l.new(geo.outputs['Normal'], sepn.inputs[0])
    absz = n.new('ShaderNodeMath')
    absz.operation = 'ABSOLUTE'
    l.new(sepn.outputs['Z'], absz.inputs[0])
    pared = n.new('ShaderNodeMath')
    pared.operation = 'LESS_THAN'
    pared.inputs[1].default_value = 0.5
    l.new(absz.outputs[0], pared.inputs[0])
    final = n.new('ShaderNodeMath')
    final.operation = 'MULTIPLY'
    l.new(fuerza.outputs[0], final.inputs[0])
    l.new(pared.outputs[0], final.inputs[1])
    bsdf.inputs['Emission Color'].default_value = (*ventana, 1)
    l.new(final.outputs[0], bsdf.inputs['Emission Strength'])
    return m


def letrero(color, semilla):
    """Un letrero vertical de neón: barras como letras, que no se leen."""
    m = bpy.data.materials.new('letrero')
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    n.clear()
    out = n.new('ShaderNodeOutputMaterial')
    em = n.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (*color, 1)
    tc = n.new('ShaderNodeTexCoord')
    celda = n.new('ShaderNodeVectorMath')
    celda.operation = 'SNAP'
    celda.inputs[1].default_value = (0.06, 0.06, 0.06)
    l.new(tc.outputs['Object'], celda.inputs[0])
    sum_ = n.new('ShaderNodeVectorMath')
    sum_.operation = 'ADD'
    sum_.inputs[1].default_value = (semilla, semilla * 2, 0)
    l.new(celda.outputs[0], sum_.inputs[0])
    ruido = n.new('ShaderNodeTexWhiteNoise')
    ruido.noise_dimensions = '3D'
    l.new(sum_.outputs[0], ruido.inputs['Vector'])
    corte = n.new('ShaderNodeMath')
    corte.operation = 'GREATER_THAN'
    corte.inputs[1].default_value = 0.45
    l.new(ruido.outputs['Value'], corte.inputs[0])
    fuerza = n.new('ShaderNodeMath')
    fuerza.operation = 'MULTIPLY_ADD'
    fuerza.inputs[1].default_value = 9.0
    fuerza.inputs[2].default_value = 0.6
    l.new(corte.outputs[0], fuerza.inputs[0])
    l.new(fuerza.outputs[0], em.inputs['Strength'])
    l.new(em.outputs[0], out.inputs[0])
    return m


# ── Piezas ──────────────────────────────────────────────────────────────────

def caja(x, y, z, sx, sy, sz, material, coleccion):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + sz / 2))
    o = bpy.context.object
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    _mover(o, coleccion)
    return o


def cilindro(x, y, z, r, h, material, coleccion, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=r, depth=h, vertices=vertices, location=(x, y, z + h / 2))
    o = bpy.context.object
    o.data.materials.append(material)
    _mover(o, coleccion)
    return o


def _mover(o, coleccion):
    for c in o.users_collection:
        c.objects.unlink(o)
    coleccion.objects.link(o)


def borde_neon(x, y, z, sx, sy, color, coleccion, grosor=0.035):
    m = emision(color, 14)
    for (dx, dy, lx, ly) in [(0, sy / 2, sx, grosor), (0, -sy / 2, sx, grosor),
                             (sx / 2, 0, grosor, sy), (-sx / 2, 0, grosor, sy)]:
        caja(x + dx, y + dy, z, lx + grosor, ly + grosor, grosor, m, coleccion)


def edificio(semilla, ancho, fondo, coleccion, x=0.0, y=0.0):
    """Un edificio con detalle. Devuelve su altura."""
    r = random.Random(semilla)
    base = r.choice([(0.035, 0.03, 0.06), (0.05, 0.04, 0.08), (0.03, 0.035, 0.05)])
    ventana = r.choice(VENTANAS)
    neon = r.choice(NEONES)
    encendidas = r.uniform(0.22, 0.42)
    mat = fachada(base, ventana, encendidas, semilla)
    oscuro = liso((0.02, 0.018, 0.03), 0.6, 0.3)
    tejado = liso((0.06, 0.05, 0.09), 0.7, 0.1)

    forma = r.choice(['torre', 'escalonado', 'escalonado', 'bajo', 'cilindro'])
    z = 0.0
    w, d = ancho, fondo
    if forma == 'bajo':
        pisos = [(w, d, r.uniform(0.8, 1.6))]
    elif forma == 'torre':
        pisos = [(w, d, r.uniform(1.0, 1.6)), (w * 0.82, d * 0.82, r.uniform(3.5, 6.5))]
    elif forma == 'cilindro':
        pisos = [(w, d, r.uniform(0.6, 1.0)), ('c', min(w, d) * 0.42, r.uniform(3.0, 5.5))]
    else:
        pisos = []
        h1 = r.uniform(1.5, 3.0)
        pisos.append((w, d, h1))
        pisos.append((w * 0.78, d * 0.78, r.uniform(1.2, 2.6)))
        if r.random() < 0.6:
            pisos.append((w * 0.55, d * 0.55, r.uniform(0.8, 2.0)))

    for i, p in enumerate(pisos):
        if p[0] == 'c':
            radio, h = p[1], p[2]
            cilindro(x, y, z, radio, h, mat, coleccion, 32)
            # Aros de neón alrededor.
            for k in range(1, 4):
                bpy.ops.mesh.primitive_torus_add(
                    major_radius=radio + 0.02, minor_radius=0.018,
                    location=(x, y, z + h * k / 4))
                t = bpy.context.object
                t.data.materials.append(emision(neon, 10))
                _mover(t, coleccion)
            z += h
            cilindro(x, y, z, radio * 1.03, 0.05, tejado, coleccion, 32)
            ultimo = (radio * 1.4, radio * 1.4)
            continue
        pw, pd, h = p
        caja(x, y, z, pw, pd, h, mat, coleccion)
        z += h
        # La cornisa: una losa algo más ancha, oscura, con el borde de neón en
        # el último piso o al azar.
        caja(x, y, z, pw + 0.06, pd + 0.06, 0.06, oscuro, coleccion)
        if i == len(pisos) - 1 or r.random() < 0.35:
            borde_neon(x, y, z + 0.06, pw + 0.06, pd + 0.06, neon, coleccion)
        caja(x, y, z + 0.06, pw - 0.02, pd - 0.02, 0.02, tejado, coleccion)
        z += 0.06
        ultimo = (pw, pd)

    # Lo de arriba.
    tw, td = ultimo
    extra = r.choice(['helipuerto', 'antena', 'depositos', 'maquinas', 'cartel'])
    if extra == 'helipuerto' and min(tw, td) > 0.9:
        cilindro(x, y, z, min(tw, td) * 0.38, 0.03, liso((0.08, 0.08, 0.1), 0.5), coleccion, 40)
        bpy.ops.mesh.primitive_torus_add(major_radius=min(tw, td) * 0.33,
                                         minor_radius=0.012, location=(x, y, z + 0.035))
        t = bpy.context.object
        t.data.materials.append(emision((1, 1, 1), 6))
        _mover(t, coleccion)
        for (dx, sx, sy) in [(-0.09, 0.025, 0.2), (0.09, 0.025, 0.2), (0, 0.2, 0.025)]:
            caja(x + dx, y, z + 0.03, sx, sy, 0.01, emision((1, 1, 1), 5), coleccion)
    elif extra == 'antena':
        cilindro(x, y, z, 0.025, 1.2, oscuro, coleccion, 8)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(x, y, z + 1.22))
        s = bpy.context.object
        s.data.materials.append(emision((1, 0.1, 0.15), 40))
        _mover(s, coleccion)
    elif extra == 'depositos':
        for k in range(r.randint(1, 3)):
            cilindro(x + (k - 1) * 0.25, y + r.uniform(-0.15, 0.15), z, 0.1, 0.25,
                     liso((0.12, 0.1, 0.14), 0.5, 0.6), coleccion, 16)
    elif extra == 'maquinas':
        for k in range(r.randint(2, 5)):
            caja(x + r.uniform(-tw / 3, tw / 3), y + r.uniform(-td / 3, td / 3), z,
                 r.uniform(0.12, 0.25), r.uniform(0.12, 0.25), r.uniform(0.06, 0.14),
                 liso((0.1, 0.09, 0.12), 0.6, 0.4), coleccion)
    else:
        # Un cartel en el tejado, de cara a la cámara.
        cw = tw * 0.8
        caja(x, y - td * 0.2, z, cw, 0.03, 0.35, letrero(neon, semilla), coleccion)
        caja(x, y - td * 0.2 + 0.03, z, cw + 0.04, 0.02, 0.39, oscuro, coleccion)

    # Un letrero vertical en la fachada que mira a la cámara, en uno de cada dos.
    if forma != 'cilindro' and r.random() < 0.55:
        alto = min(z * 0.6, 2.6)
        caja(x + w / 2 + 0.03, y - d * 0.25, r.uniform(0.3, 0.8), 0.04, 0.16, alto,
             letrero(r.choice(NEONES), semilla + 3), coleccion)
    return z


# ── Escena ──────────────────────────────────────────────────────────────────

def preparar(resolucion, transparente):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _cache.clear()  # los materiales de antes ya no existen
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = resolucion
    sc.render.film_transparent = transparente
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Punchy'
    mundo = bpy.data.worlds.new('noche')
    sc.world = mundo
    mundo.use_nodes = True
    fondo = mundo.node_tree.nodes['Background']
    fondo.inputs['Color'].default_value = (0.012, 0.008, 0.03, 1)
    fondo.inputs['Strength'].default_value = 0.5
    # Una luz de luna fría, muy suave, para que se vean los volúmenes.
    bpy.ops.object.light_add(type='SUN', rotation=(math.radians(50), 0, math.radians(-30)))
    luna = bpy.context.object
    luna.data.energy = 0.25
    luna.data.color = (0.6, 0.65, 1.0)
    return sc


def camara_isometrica(sc, objetivo, escala):
    """Isométrica clásica: 60º desde la vertical y 45º de giro, ortográfica."""
    ox, oy, oz = objetivo
    dist = 40
    rx, rz = math.radians(60), math.radians(45)
    x = ox + dist * math.sin(rx) * math.sin(rz)
    y = oy - dist * math.sin(rx) * math.cos(rz)
    z = oz + dist * math.cos(rx)
    bpy.ops.object.camera_add(location=(x, y, z), rotation=(rx, 0, rz))
    cam = bpy.context.object
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = escala
    cam.data.clip_end = 200
    sc.camera = cam


def suelo_calle(coleccion, lado=8.0, calle=1.2):
    """Un cruce: asfalto mojado, aceras, pasos de cebra, farolas, neón en los
    bordillos de la avenida y coches de luz."""
    asfalto = liso((0.015, 0.012, 0.03), 0.08, 0.0)
    acera = liso((0.05, 0.045, 0.07), 0.35, 0.0)
    caja(0, 0, -0.02, lado * 2, lado * 2, 0.02, asfalto, coleccion)
    # Cuatro solares con acera.
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (calle / 2 + lado / 2), sy * (calle / 2 + lado / 2)
            caja(cx, cy, 0, lado, lado, 0.05, acera, coleccion)
    # Neón en los bordillos y rayas.
    for s, c in ((1, NEONES[0]), (-1, NEONES[1])):
        caja(0, s * calle / 2, 0.0, lado * 2, 0.025, 0.012, emision(c, 8), coleccion)
        caja(s * calle / 2, 0, 0.0, 0.025, lado * 2, 0.012, emision(c, 8), coleccion)
    raya = emision((0.9, 0.8, 0.4), 1.5)
    for k in range(-12, 13):
        if abs(k) < 2:
            continue
        caja(k * 0.6, 0, 0, 0.25, 0.03, 0.005, raya, coleccion)
        caja(0, k * 0.6, 0, 0.03, 0.25, 0.005, raya, coleccion)
    blanco = emision((0.8, 0.8, 0.9), 0.8)
    for k in range(-4, 5):
        caja(k * 0.12, calle / 2 + 0.15, 0, 0.06, 0.25, 0.005, blanco, coleccion)
        caja(calle / 2 + 0.15, k * 0.12, 0, 0.25, 0.06, 0.005, blanco, coleccion)
    # Farolas.
    luz = emision((1.0, 0.8, 0.55), 30)
    poste = liso((0.05, 0.05, 0.06), 0.5, 0.6)
    for k in range(-6, 7):
        for (px, py) in ((k * 1.2, calle / 2 + 0.2), (k * 1.2, -calle / 2 - 0.2),
                         (calle / 2 + 0.2, k * 1.2), (-calle / 2 - 0.2, k * 1.2)):
            if abs(px) < calle and abs(py) < calle:
                continue
            cilindro(px, py, 0, 0.015, 0.45, poste, coleccion, 6)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.045, location=(px, py, 0.47))
            s = bpy.context.object
            s.data.materials.append(luz)
            _mover(s, coleccion)
    # Coches: faros blancos y luces rojas, por su carril.
    r = random.Random(99)
    for k in range(22):
        t = r.uniform(-lado, lado)
        sentido = r.choice((1, -1))
        horizontal = r.random() < 0.5
        carril = sentido * calle * 0.22
        largo = r.uniform(0.18, 0.24)
        for (frente, color, fuerza) in ((1, (1, 0.95, 0.85), 12), (-1, (1, 0.1, 0.15), 8)):
            off = frente * sentido * largo / 2
            if horizontal:
                caja(t + off, carril, 0.03, 0.03, 0.08, 0.02, emision(color, fuerza), coleccion)
            else:
                caja(carril, t + off, 0.03, 0.08, 0.03, 0.02, emision(color, fuerza), coleccion)
            if horizontal:
                caja(t, carril, 0.0, largo, 0.11, 0.05, liso((0.03, 0.03, 0.04), 0.2, 0.7), coleccion)
            else:
                caja(carril, t, 0.0, 0.11, largo, 0.05, liso((0.03, 0.03, 0.04), 0.2, 0.7), coleccion)


def escena(salida):
    sc = preparar((1100, 1100), transparente=False)
    col = bpy.data.collections.new('ciudad')
    sc.collection.children.link(col)
    suelo_calle(col)
    # Diez edificios en los cuatro solares, en parcelas de tamaños distintos.
    parcelas = [
        (-2.0, 2.0, 1.6, 1.6), (-3.6, 3.4, 1.2, 1.1), (-2.2, 4.0, 1.3, 1.0),
        (2.1, 2.1, 1.7, 1.5), (3.6, 2.0, 1.1, 1.3), (2.3, 3.8, 1.5, 1.1),
        (2.0, -2.1, 1.6, 1.7), (3.6, -3.4, 1.2, 1.2),
        (-2.1, -2.0, 1.7, 1.6), (-3.8, -2.2, 1.1, 1.4),
    ]
    for i, (px, py, w, d) in enumerate(parcelas):
        edificio(1000 + i * 17, w, d, col, px, py)
    camara_isometrica(sc, (0, 0, 1.9), 12.5)
    sc.render.filepath = salida
    bpy.ops.render.render(write_still=True)


def sprites(carpeta, cuantos=10):
    for i in range(cuantos):
        sc = preparar((384, 512), transparente=True)
        col = bpy.data.collections.new('edificio')
        sc.collection.children.link(col)
        r = random.Random(1000 + i * 17)
        edificio(1000 + i * 17, r.uniform(1.1, 1.7), r.uniform(1.1, 1.7), col)
        camara_isometrica(sc, (0, 0, 2.6), 5.5)
        sc.render.filepath = f'{carpeta}/edificio_{i:02d}.png'
        bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    modo, destino = sys.argv[1], sys.argv[2]
    if modo == 'escena':
        escena(destino)
    else:
        sprites(destino)
