# Arte de los mundos, renderizado por código

**Prueba (16-nov-2026)** para la ciudad de Neotokyo+: en vez de dibujar los
edificios en directo, se renderizan en 3D con Blender desde Python (todo por
script, con una semilla) y la app los coloca como imágenes, como hacen los
constructores de ciudades. Ver `encargos/focus-mundos-calidad.md` §5 en el
proyecto.

Necesita el módulo de Blender para Python: `pip install bpy` (Python 3.13).

- `ciudad_blender.py escena SALIDA.png`: una manzana montada en 3D (cruce,
  suelo mojado, 10 edificios), en vista isométrica.
- `ciudad_blender.py sprites CARPETA`: cada edificio suelto, con fondo
  transparente.
- `montaje.py CARPETA`: el suelo solo y los 10 edificios sueltos con la
  misma cámara y escala, más dónde va cada uno (`montaje.json`), para
  montarlos como lo haría la app.

- `ciudad_blender.py kit CARPETA DESDE HASTA`: el kit de la app, 48
  edificios (16 huellas × 3) y la torre de la plaza, cada uno con su JSON
  (huella, altura, dónde cae la base). Los 49: `kit CARPETA 0 49`, unos 3
  minutos.
- `empaquetar_kit.py CARPETA`: los junta en el atlas que usa la app,
  `assets/mundos/neotokyo/edificios.webp` + `edificios.json`.

La app los usa en el laboratorio, en el mundo «Neotokyo+ 3D»
(`lib/mundos/ciudad/ciudad_isometrica.dart`).

## El jardín de Dulce en 3D a lápiz (prueba, 16-nov)

- `jardin_blender.py escena SALIDA`: un parterre con 10 plantas, el árbol y
  los caminos, con la misma cámara que Neotokyo+ 3D. Saca el color, las
  normales, la profundidad y la altura (`SALIDA_color.png`, `_normal`,
  `_prof`, `_altura`).
- `plantas_blender.py`: las plantas (tulipanes, margaritas, lavanda, rosal,
  hortensia, girasol y amapolas), con pétalos y hojas como láminas curvas.
- `lapiz_post.py SALIDA RESULTADO.png`: lo pasa a lápiz de color sobre el
  papel de Dulce (contorno que tiembla, rayado en el ángulo de la mano,
  pigmento que agarra en el diente del papel y el suelo que se deshace hacia
  fuera).
