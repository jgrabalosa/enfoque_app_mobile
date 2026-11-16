"""Pasa un render 3D a lápiz de color sobre el papel de Dulce.

    python3 lapiz_post.py ENTRADA_SIN_EXTENSION SALIDA.png

Lee ENTRADA_color.png (con transparencia), ENTRADA_normal.png y
ENTRADA_prof.png (jardin_blender.py).

Lo mismo que hace un ilustrador:
- **contorno a grafito** donde cambia la forma (saltos de profundidad y de
  normal), que tiembla un poco y se corta a ratos;
- **color a rayas** en el ángulo de la mano: la presión sale de lo oscuro
  que es el color; con poca presión, el pigmento solo agarra en el diente
  del papel (motas); en las sombras, una segunda capa cruzada;
- el dibujo **se deshace hacia los bordes**, en lápiz suelto sobre el papel.
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

PAPEL = np.array([1.0, 0.988, 0.961])
GRAFITO = np.array([0.353, 0.333, 0.376])
ANGULO = -0.95  # el de la mano, como en la app


def ruido(forma, escala, semilla):
    """Ruido suave (bilineal de una rejilla aleatoria)."""
    rng = np.random.default_rng(semilla)
    h, w = forma
    gh, gw = int(h / escala) + 3, int(w / escala) + 3
    g = rng.random((gh, gw))
    y, x = np.mgrid[0:h, 0:w] / escala
    return ndimage.map_coordinates(g, [y, x], order=3, mode='wrap')


def diente(forma, semilla, grano=1.6):
    a = ruido(forma, grano, semilla)
    b = ruido(forma, grano * 0.5, semilla + 1)
    h, w = forma
    rng = np.random.default_rng(semilla + 2)
    g = rng.random((int(h / (grano * 0.8)) + 3, int(w / (grano * 3.5)) + 3))
    y, x = np.mgrid[0:h, 0:w]
    c = ndimage.map_coordinates(g, [y / (grano * 0.8), x / (grano * 3.5)], order=1)
    return a * 0.55 + b * 0.25 + c * 0.2


def rayas(forma, angulo, separacion, semilla):
    """Rayas como trazos de lápiz: el ángulo y la separación varían un poco
    (la mano no es una máquina), cada raya tiene su presión, se afina en las
    puntas y se corta a ratos."""
    h, w = forma
    y, x = np.mgrid[0:h, 0:w].astype(float)
    ang = angulo
    sep = separacion
    # La mano no es una máquina: las rayas se ondulan un poco (se desplazan,
    # no se giran; girar según la posición haría ondas de muaré).
    tiembla = (ruido(forma, 30, semilla) - 0.5) * separacion * 0.8 + (ruido(forma, 140, semilla + 1) - 0.5) * separacion * 3
    u = x * np.cos(ang) + y * np.sin(ang)
    v = -x * np.sin(ang) + y * np.cos(ang) + tiembla
    s = v / sep
    raya = np.floor(s)
    dentro = s - raya
    rng = np.random.default_rng(semilla + 5)
    tabla = rng.random(4096)
    idx = raya.astype(int) % 4096
    grosor = 0.5 + 0.25 * tabla[(idx * 3 + 1) % 4096]
    perfil = np.clip(1 - np.abs(dentro - 0.5) / (grosor / 2), 0, 1) ** 0.6
    presion = 0.7 + 0.5 * tabla[idx]
    largo = 18 + 40 * tabla[(idx * 7 + 3) % 4096]
    fase = tabla[(idx * 13 + 5) % 4096]
    t = ((u / largo) + fase) % 1.0
    # Cada trazo: entra fino, aprieta en medio y sale fino; entre trazos, un
    # hueco corto.
    trazo = np.clip(np.sin(np.clip(t * 1.15, 0, 1) * np.pi), 0, 1) ** 0.5
    return perfil * presion * (0.25 + 0.75 * trazo)


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def a_lapiz(entrada, salida, semilla=3, boceto=False):
    rgba = np.asarray(Image.open(entrada + '_color.png').convert('RGBA')).astype(float) / 255
    color, alfa = rgba[..., :3], rgba[..., 3]
    normal = np.asarray(Image.open(entrada + '_normal.png').convert('RGB')).astype(float) / 255
    prof = np.asarray(Image.open(entrada + '_prof.png')).astype(float) / 65535
    altura = np.asarray(Image.open(entrada + '_altura.png')).astype(float) / 65535 * 3
    forma = alfa.shape
    h, w = forma
    k = w / 1100  # escala respecto a la resolución de base

    # El dibujo se deshace hacia los bordes: más flojo y a trozos.
    # Solo el suelo (lo que mira hacia arriba) se deshace hacia fuera; las
    # plantas y el árbol se dibujan enteros.
    y, x = np.mgrid[0:h, 0:w]
    arriba = 1 - suave(0.02, 0.06, altura)  # el suelo: lo que está a ras
    cy, cx = h * 0.6, w / 2
    d = np.hypot((x - cx) / (w * 0.42), (y - cy) / (h * 0.24))
    lejos = suave(0.62, 1.0, d + (ruido(forma, 110, semilla) - 0.5) * 0.3)
    borde = 1 - lejos * arriba
    dentro = alfa * borde

    # En boceto, lo plantado (todo lo que no es el suelo ni el árbol) no se
    # colorea: se queda en papel y solo lleva el trazo (más abajo).
    plantado = np.zeros(forma)
    if boceto:
        ident = np.rint(np.asarray(Image.open(entrada + '_indice.png')).astype(float))
        plantado = suave(0.02, 0.06, altura) * (ident >= 1000)
    lum0 = color @ np.array([0.299, 0.587, 0.114])

    # Cuánto se cubre: todo lo que tiene color se cubre bastante (si no, las
    # luces se quedan en blanco); lo oscuro y lo saturado, más.
    lum = color @ np.array([0.299, 0.587, 0.114])
    sat = color.max(-1) - color.min(-1)
    cubre = np.clip(0.72 + 0.5 * (1 - lum) + 0.2 * sat, 0, 1) * dentro * (1 - plantado)

    t = diente(forma, semilla, grano=1.6 * k)
    capa1 = rayas(forma, ANGULO, 3.4 * k, semilla)
    capa2 = rayas(forma, ANGULO + 1.1, 4.2 * k, semilla + 11)

    def agarra(p, r):
        liston = 0.9 - 0.8 * p
        return suave(liston - 0.1, liston + 0.1, 0.55 * r + 0.45 * t) * np.clip(p * 3, 0, 1)

    m1 = agarra(cubre, capa1)
    # Del papel al color del render donde agarra el lápiz; el centro de cada
    # trazo, algo más cargado.
    claro = 1 - (1 - color) * 0.88
    tinta_color = np.clip(claro * (1 - 0.1 * capa1[..., None]), 0, 1)
    color_final = PAPEL + (tinta_color - PAPEL) * m1[..., None]
    # Las sombras, con una segunda capa cruzada del mismo color, más oscuro.
    sombra = np.clip((0.5 - lum) * 2.0, 0, 1) * dentro * (1 - plantado)
    m2 = agarra(sombra, capa2)
    color_final = color_final * (1 - m2[..., None] * (1 - np.clip(color * 0.75, 0, 1)) * 0.45)

    # Contornos: saltos de profundidad y de normal.
    # La segunda derivada: en un plano inclinado es cero (la primera no).
    gz = np.abs(ndimage.laplace(ndimage.gaussian_filter(prof, 0.7))) * 2500
    gn = sum(np.hypot(ndimage.sobel(normal[..., c], 0), ndimage.sobel(normal[..., c], 1)) for c in range(3))
    ga = np.hypot(ndimage.sobel(alfa, 0), ndimage.sobel(alfa, 1))
    borde_forma = np.clip(np.maximum.reduce([gz, gn * 0.45, ga]) - 0.5, 0, 1)
    if boceto:
        # El trazo del boceto: donde cambia de pieza (cada pétalo y cada hoja
        # tiene su número), una línea de un píxel.
        cambia = np.zeros(forma)
        cambia[:, 1:] = np.maximum(cambia[:, 1:], ident[:, 1:] != ident[:, :-1])
        cambia[1:, :] = np.maximum(cambia[1:, :], ident[1:, :] != ident[:-1, :])
        cambia = ndimage.gaussian_filter(cambia, 0.5) * 1.2
        borde_forma = borde_forma * (1 - plantado) + np.clip(cambia, 0, 1) * plantado
    # El trazo tiembla: se desplaza con un ruido suave.
    dy = (ruido(forma, 25, semilla + 20) - 0.5) * 2.4
    dx = (ruido(forma, 25, semilla + 21) - 0.5) * 2.4
    borde_forma = ndimage.map_coordinates(borde_forma, [y + dy, x + dx], order=1)
    borde_forma = np.clip(borde_forma * 1.4, 0, 1)
    presion_linea = (0.55 + 0.45 * ruido(forma, 18, semilla + 22)) * borde
    linea = suave(0.85 - 0.8 * presion_linea, 0.95 - 0.8 * presion_linea, 0.6 * borde_forma + 0.4 * t) * borde_forma

    if boceto:
        # El boceto: el contorno a grafito, más fino, con un segundo repaso
        # que no cae justo encima (como cuando se encaja un dibujo), y unas
        # pocas rayas sueltas en lo más oscuro.
        dy2 = (ruido(forma, 20, semilla + 30) - 0.5) * 3.2
        dx2 = (ruido(forma, 20, semilla + 31) - 0.5) * 3.2
        repaso = ndimage.map_coordinates(borde_forma, [y + dy2, x + dx2], order=1)
        p2 = 0.4 + 0.4 * ruido(forma, 14, semilla + 32)
        repaso = suave(0.85 - 0.8 * p2, 0.95 - 0.8 * p2, 0.6 * repaso + 0.4 * t) * repaso
        sombra_b = np.clip((0.42 - lum0) * 2.5, 0, 1) * plantado
        rayas_b = agarra(sombra_b * 0.55, capa1)
        trazo_b = np.clip(linea * 0.7 + repaso * 0.25 + rayas_b * 0.3, 0, 1) * plantado
        linea = linea * (1 - plantado)

    papel = PAPEL * (1 + (t - 0.5)[..., None] * 0.05)
    final = papel / PAPEL * color_final
    # El contorno, del color de lo que perfila pero más oscuro, con grafito.
    oscuro = np.clip(color * 0.45, 0, 1) * 0.5 + GRAFITO * 0.5
    final = final * (1 - linea[..., None] * 0.85 * (1 - oscuro))
    if boceto:
        final = final * (1 - trazo_b[..., None] * (1 - GRAFITO))
    imagen = Image.fromarray((np.clip(final, 0, 1) * 255).astype(np.uint8))
    if w > 1100:
        imagen = imagen.resize((1100, round(h * 1100 / w)), Image.LANCZOS)
    imagen.save(salida)


if __name__ == '__main__':
    a_lapiz(sys.argv[1], sys.argv[2], boceto=len(sys.argv) > 3 and sys.argv[3] == 'boceto')
