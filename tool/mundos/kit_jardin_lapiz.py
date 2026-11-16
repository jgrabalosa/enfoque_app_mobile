"""Pasa a lápiz las piezas del kit del jardín (kit_jardin.py) y las junta en
un atlas para la app.

    python3 kit_jardin_lapiz.py CARPETA_KIT DESTINO

Escribe DESTINO/jardin.webp y DESTINO/jardin.json. Las plantas y los
parterres salen dos veces: en color y en boceto (a grafito).
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lapiz_post as lp  # noqa: E402

ANCHO = 4096
AIRE = 12


def main(kit, destino):
    piezas = []
    for f in sorted(glob.glob(f'{kit}/*.json')):
        datos = json.load(open(f))
        base = f[:-5]
        modos = {'cesped': ['suelo']}.get(datos['tipo'], ['objeto'])
        if datos['tipo'] in ('planta', 'parterre'):
            modos = ['objeto', 'boceto']
        for k, modo in enumerate(modos):
            salida = f'{base}_{modo}.png'
            lp.a_lapiz_pieza(base, salida, modo, semilla=3 + k)
            im = Image.open(salida).convert('RGBA')
            caja = im.getbbox()
            caja = (max(0, caja[0] - 2), max(0, caja[1] - 2),
                    min(im.width, caja[2] + 2), min(im.height, caja[3] + 2))
            im = im.crop(caja)
            ax, ay = datos['ancla']
            piezas.append((im, {
                **{k2: v for k2, v in datos.items() if k2 != 'ancla'},
                'version': 'boceto' if modo == 'boceto' else 'color',
                'ax': round(ax - caja[0], 1), 'ay': round(ay - caja[1], 1),
            }))
    # Estantes, de más alta a más baja.
    orden = sorted(range(len(piezas)), key=lambda i: -piezas[i][0].height)
    x = y = alto_estante = 0
    sitio = {}
    for i in orden:
        im = piezas[i][0]
        if x + im.width + AIRE > ANCHO:
            x, y, alto_estante = 0, y + alto_estante + AIRE, 0
        sitio[i] = (x + AIRE // 2, y + AIRE // 2)
        x += im.width + AIRE
        alto_estante = max(alto_estante, im.height)
    alto = y + alto_estante + AIRE
    atlas = Image.new('RGBA', (ANCHO, alto), (0, 0, 0, 0))
    lista = []
    for i, (im, d) in enumerate(piezas):
        px, py = sitio[i]
        atlas.paste(im, (px, py))
        lista.append({**d, 'x': px, 'y': py, 'w': im.width, 'h': im.height})
    os.makedirs(destino, exist_ok=True)
    atlas.save(f'{destino}/jardin.webp', lossless=False, quality=90, method=6)
    json.dump({'piezas': lista}, open(f'{destino}/jardin.json', 'w'), separators=(',', ':'))
    print(f'{len(lista)} piezas, atlas {ANCHO}x{alto}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
