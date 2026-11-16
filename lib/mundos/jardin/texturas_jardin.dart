import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:ui';

import 'dibujos_jardin.dart';
import 'flores.dart';
import 'lapiz_realista.dart';

/// Lo que el jardín dibuja una vez y luego solo reproduce.
///
/// - **Las flores:** cada especie en [Flor.variantes] dibujos, en cuatro
///   atlas (uno por capa: grafito, hojas, pétalos y centro), con las flores
///   en celdas de [Flores.lado] píxeles. Se colorean al pintarlas.
/// - **Lo demás** (el árbol, los parterres, los caminos, los hitos): se
///   dibuja cuando aparece en pantalla y se guarda ([CacheDibujos]).
class TexturasJardin {
  TexturasJardin._(
    this.pigmento,
    this.grafito,
    this.hojas,
    this.petalos,
    this.centro,
  );

  /// Celdas por fila en los atlas de flores.
  static const int porFila = 4;

  final Pigmento pigmento;
  final ui.Image grafito;
  final ui.Image hojas;
  final ui.Image petalos;
  final ui.Image centro;

  static Future<TexturasJardin> crear() async {
    final pigmento = await Pigmento.cargar();
    final flores = [
      for (final e in EspecieFlor.values)
        for (var v = 0; v < 3; v++) Flores.hornear(pigmento, e, v),
    ];
    final filas = (flores.length / porFila).ceil();
    ui.Image atlas(ui.Image Function(FlorHorneada f) capa) {
      final grabadora = ui.PictureRecorder();
      final c = Canvas(grabadora);
      for (final (k, f) in flores.indexed) {
        c.drawImage(capa(f), celdaDe(k).topLeft, Paint());
      }
      return grabadora.endRecording().toImageSync(
        porFila * Flores.lado,
        filas * Flores.lado,
      );
    }

    final t = TexturasJardin._(
      pigmento,
      atlas((f) => f.grafito),
      atlas((f) => f.hojas),
      atlas((f) => f.petalos),
      atlas((f) => f.centro),
    );
    for (final f in flores) {
      f.liberar();
    }
    return t;
  }

  /// La celda de la flor número [k] (especie × 3 + variante).
  static Rect celdaDe(int k) => Rect.fromLTWH(
    (k % porFila) * Flores.lado.toDouble(),
    (k ~/ porFila) * Flores.lado.toDouble(),
    Flores.lado.toDouble(),
    Flores.lado.toDouble(),
  );

  void liberar() {
    for (final i in [grafito, hojas, petalos, centro]) {
      i.dispose();
    }
  }
}

/// Un dibujo del jardín ya pasado a pigmento y coloreado: una sola imagen,
/// blanca donde no hay lápiz, que se pinta con `multiply` sobre el papel.
class DibujoHorneado {
  DibujoHorneado(this.mundo, this.imagen);

  final Rect mundo;
  final ui.Image imagen;

  int get pixeles => imagen.width * imagen.height;

  void liberar() => imagen.dispose();
}

/// Los dibujos del jardín ya horneados, por clave y resolución. Se hornean
/// unos pocos por fotograma (para no dar tirones al alejarse) y, al pasar de
/// [limitePixeles], salen los que hace más que no se usan.
class CacheDibujos {
  CacheDibujos(this.pigmento);

  final Pigmento pigmento;
  static const int limitePixeles = 14000000;

  /// Cuántos dibujos se hornean como mucho en un fotograma.
  static const int porFotograma = 2;

  final LinkedHashMap<Object, DibujoHorneado> _cache = LinkedHashMap();
  int _pixeles = 0;
  int _horneadosAhora = 0;

  /// Llamar al empezar cada fotograma.
  void nuevoFotograma() => _horneadosAhora = 0;

  /// Si quedó algo por hornear en este fotograma: hay que pedir otro.
  bool faltan = false;

  /// El dibujo de [clave] a [pxPorUnidad] píxeles por unidad del mundo. Si
  /// no está y ya se hornearon bastantes en este fotograma, da el mismo
  /// dibujo a otra resolución si lo hay, o nada.
  DibujoHorneado? obtener(
    Object clave,
    double pxPorUnidad,
    DibujoJardin Function() dibujo, {
    required int semilla,
  }) {
    final completa = (clave, pxPorUnidad);
    final hay = _cache.remove(completa);
    if (hay != null) {
      _cache[completa] = hay;
      return hay;
    }
    if (_horneadosAhora >= porFotograma) {
      faltan = true;
      for (final otra in const [2.0, 1.0, 0.5, 0.25]) {
        final o = _cache[(clave, otra)];
        if (o != null) return o;
      }
      return null;
    }
    _horneadosAhora++;
    final d = dibujo();
    final ancho = (d.mundo.width * pxPorUnidad).ceil().clamp(1, 4096);
    final alto = (d.mundo.height * pxPorUnidad).ceil().clamp(1, 4096);
    // Cada color se hornea aparte (el pigmento es por capa) y se juntan en
    // una imagen sobre blanco, mezclándolos como lápices: `multiply`.
    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora)
      ..drawRect(
        Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    final capas = <ui.Image>[];
    for (final (k, capa) in d.capas.indexed) {
      final imagen = pigmento.hornear(
        ancho,
        alto,
        (c) {
          c.scale(pxPorUnidad);
          c.translate(-d.mundo.left, -d.mundo.top);
          capa.dibujo(c);
        },
        semilla: semilla + k,
        grano: 0.72 * pxPorUnidad,
      );
      capas.add(imagen);
      lienzo.drawImage(
        imagen,
        Offset.zero,
        Paint()
          ..blendMode = BlendMode.multiply
          ..colorFilter = ColorFilter.mode(capa.color, BlendMode.modulate),
      );
    }
    final horneado = DibujoHorneado(
      d.mundo,
      grabadora.endRecording().toImageSync(ancho, alto),
    );
    for (final i in capas) {
      i.dispose();
    }
    _cache[completa] = horneado;
    _pixeles += horneado.pixeles;
    while (_pixeles > limitePixeles && _cache.length > 1) {
      final viejo = _cache.remove(_cache.keys.first)!;
      _pixeles -= viejo.pixeles;
      viejo.liberar();
    }
    return horneado;
  }

  void vaciar() {
    for (final d in _cache.values) {
      d.liberar();
    }
    _cache.clear();
    _pixeles = 0;
  }
}
