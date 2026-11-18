"""Junta las imágenes del kit de Neotokyo+ en un atlas para la app.

    python3 ciudad_blender.py kit CARPETA 0 49     # renderiza los 49
    python3 empaquetar_kit.py CARPETA              # crea el atlas

Recorta cada edificio a lo que ocupa, los coloca en estantes en una imagen de
4096 de ancho (con 12 px de aire entre ellos, para que no se mezclen al
alejarse) y escribe `assets/mundos/neotokyo/edificios.webp` y
`edificios.json` (rectángulo en el atlas, ancla de la base, huella y altura).
"""
import json
import os
import sys

from PIL import Image

ANCHO = 4096
AIRE = 12


def main(carpeta, destino='assets/mundos/neotokyo'):
    piezas = []
    i = 0
    while os.path.exists(f'{carpeta}/kit_{i:03d}.png'):
        im = Image.open(f'{carpeta}/kit_{i:03d}.png').convert('RGBA')
        datos = json.load(open(f'{carpeta}/kit_{i:03d}.json'))
        caja = im.getbbox()
        piezas.append((i, im.crop(caja), datos, caja))
        i += 1
    x = y = alto_estante = 0
    sitio = {}
    for i, im, _, _ in sorted(piezas, key=lambda t: -t[1].height):
        if x + im.width + AIRE > ANCHO:
            x, y, alto_estante = 0, y + alto_estante + AIRE, 0
        sitio[i] = (x + AIRE // 2, y + AIRE // 2)
        x += im.width + AIRE
        alto_estante = max(alto_estante, im.height)
    atlas = Image.new('RGBA', (ANCHO, y + alto_estante + AIRE), (0, 0, 0, 0))
    lista = []
    for i, im, d, caja in piezas:
        px, py = sitio[i]
        atlas.paste(im, (px, py))
        lista.append({
            'i': i, 'x': px, 'y': py, 'w': im.width, 'h': im.height,
            'ax': round(d['ancla'][0] - caja[0], 1),
            'ay': round(d['ancla'][1] - caja[1], 1),
            'ancho': d['ancho'], 'fondo': d['fondo'],
            'alto': round(d['alto'], 3), 'torre': d['torre'],
        })
    os.makedirs(destino, exist_ok=True)
    atlas.save(f'{destino}/edificios.webp', lossless=False, quality=90, method=6)
    json.dump({'px_por_unidad': piezas[0][2]['px_por_unidad'], 'edificios': lista},
              open(f'{destino}/edificios.json', 'w'), separators=(',', ':'))
    print(f'{len(lista)} edificios, atlas {atlas.width}x{atlas.height}')


if __name__ == '__main__':
    main(*sys.argv[1:])
