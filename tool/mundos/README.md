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

Aún no lo usa la app: es para decidir el camino.
