import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../vista_mundo.dart';
import 'colocador_galaxia.dart';
import 'escena_galaxia.dart';
import 'paleta_profundidad.dart';
import 'texturas_galaxia.dart';

/// La galaxia **toda por código** (opción 1 de `encargos/focus-mundos.md`
/// §5): el cielo lo pinta un shader en la GPU y las estrellas son imágenes
/// generadas al arrancar, colocadas en lote con `drawAtlas` y sumadas como
/// luz. No hay ni un PNG.
class PintorCodigo extends PintorGalaxia {
  PintorCodigo({this.rutaShader = 'shaders/cielo_galaxia.frag'});

  final String rutaShader;

  /// El tamaño de una estrella en el mundo (la de cierre, el doble largo).
  static const double tamanoEstrella = 46;

  /// Por debajo de esto, en píxeles, las estrellas no encogen más: de lejos
  /// los brazos siguen brillando en vez de desaparecer.
  static const double minimoPx = 9;

  @override
  String get nombre => 'Código';

  TexturasGalaxia? _texturas;
  FragmentShader? _cielo;

  /// Si el shader no carga (un móvil que no lo admite, o los tests), el
  /// fondo es un degradado. Lo enseña el laboratorio.
  bool get conShader => _cielo != null;

  @override
  Future<void> preparar() async {
    _texturas ??= TexturasGalaxia.crear();
    if (_cielo != null) return;
    try {
      final programa = await FragmentProgram.fromAsset(rutaShader);
      _cielo = programa.fragmentShader();
    } catch (e) {
      debugPrint('Galaxia sin shader: $e');
    }
  }

  @override
  void liberar() {
    _texturas?.liberar();
    _texturas = null;
    _cielo?.dispose();
    _cielo = null;
  }

  @override
  void pintar(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaGalaxia escena, {
    required double segundos,
    int? nueva,
    double aparicion = 1,
  }) {
    final texturas = _texturas;
    if (texturas == null) return;
    _pintarCielo(canvas, tamano, vista, escena);
    _pintarHitos(canvas, tamano, vista, escena, texturas);
    _pintarLineas(canvas, tamano, vista, escena, nueva, aparicion);
    _pintarEstrellas(
      canvas,
      tamano,
      vista,
      escena,
      texturas,
      segundos,
      nueva,
      aparicion,
    );
  }

  void _pintarCielo(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaGalaxia escena,
  ) {
    final rect = Offset.zero & tamano;
    final cielo = _cielo;
    if (cielo == null) {
      final centro = vista.aPantalla(Offset.zero, tamano);
      canvas.drawRect(rect, Paint()..color = PaletaProfundidad.fondo);
      canvas.drawCircle(
        centro,
        ColocadorGalaxia.radioInicial * vista.escala,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = Gradient.radial(
            centro,
            ColocadorGalaxia.radioInicial * vista.escala,
            const [Color(0xCCFFD9A0), Color(0x00FFD9A0)],
          ),
      );
      return;
    }
    final c = escena.colocador;
    cielo
      ..setFloat(0, tamano.width)
      ..setFloat(1, tamano.height)
      ..setFloat(2, vista.centro.dx)
      ..setFloat(3, vista.centro.dy)
      ..setFloat(4, vista.escala)
      ..setFloat(5, (c.semilla % 1000) / 1000)
      ..setFloat(6, escena.radio)
      ..setFloat(7, c.giroBrazos)
      ..setFloat(8, c.giroInicial)
      ..setFloat(9, ColocadorGalaxia.radioInicial);
    canvas.drawRect(rect, Paint()..shader = cielo);
  }

  void _pintarHitos(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaGalaxia escena,
    TexturasGalaxia texturas,
  ) {
    if (escena.hitos.isEmpty) return;
    final visible = vista.visible(tamano, margen: 400);
    final transformaciones = <RSTransform>[];
    final rects = <Rect>[];
    final colores = <Color>[];
    const lado = TexturasGalaxia.ladoHito;
    for (final h in escena.hitos) {
      if (!visible.contains(h.centro)) continue;
      final p = vista.aPantalla(h.centro, tamano);
      transformaciones.add(
        RSTransform.fromComponents(
          rotation: h.giro,
          scale: math.max(h.radio * 2 * vista.escala, 28) / lado,
          anchorX: lado / 2,
          anchorY: lado / 2,
          translateX: p.dx,
          translateY: p.dy,
        ),
      );
      rects.add(texturas.rectHito(h.variante));
      colores.add(PaletaProfundidad.hitos[h.variante].withValues(alpha: 0.8));
    }
    if (transformaciones.isEmpty) return;
    canvas.drawAtlas(
      texturas.hitos,
      transformaciones,
      rects,
      colores,
      BlendMode.modulate,
      null,
      Paint()
        ..blendMode = BlendMode.plus
        ..filterQuality = FilterQuality.medium,
    );
  }

  void _pintarLineas(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaGalaxia escena,
    int? nueva,
    double aparicion,
  ) {
    // De lejos, las líneas solo ensucian: se apagan al alejarse.
    final alfa = ((vista.escala - 0.12) / 0.35).clamp(0.0, 1.0);
    if (alfa == 0) return;
    final visible = vista.visible(tamano, margen: 120);
    final normales = <double>[];
    final deHoy = <double>[];
    for (final e in escena.estrellas) {
      final union = e.unidaA;
      if (union == null || !visible.contains(e.posicion)) continue;
      final a = vista.aPantalla(e.posicion, tamano);
      var b = vista.aPantalla(escena.estrellas[union].posicion, tamano);
      // La línea de la estrella nueva crece con ella.
      if (e.numero == nueva) b = Offset.lerp(a, b, aparicion)!;
      final destino = e.constelacion == escena.deLaUltima ? deHoy : normales;
      destino.addAll([a.dx, a.dy, b.dx, b.dy]);
    }
    final pincel = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    if (normales.isNotEmpty) {
      canvas.drawRawPoints(
        PointMode.lines,
        Float32List.fromList(normales),
        pincel..color = PaletaProfundidad.linea.withValues(alpha: 0.28 * alfa),
      );
    }
    if (deHoy.isNotEmpty) {
      canvas.drawRawPoints(
        PointMode.lines,
        Float32List.fromList(deHoy),
        pincel
          ..strokeWidth = 1.4
          ..color = PaletaProfundidad.amarillo.withValues(alpha: 0.45 * alfa),
      );
    }
  }

  void _pintarEstrellas(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaGalaxia escena,
    TexturasGalaxia texturas,
    double segundos,
    int? nueva,
    double aparicion,
  ) {
    final margen = math.max(tamanoEstrella * 2, minimoPx * 2 / vista.escala);
    final visible = vista.visible(tamano, margen: margen);
    final hoy = escena.cantidad - 1;
    final transformaciones = <RSTransform>[];
    final rects = <Rect>[];
    final colores = <Color>[];
    const lado = TexturasGalaxia.ladoEstrella;

    void anadir(
      EstrellaColocada e,
      int sprite,
      double factor,
      Color color,
      double giro,
    ) {
      final p = vista.aPantalla(e.posicion, tamano);
      final px = math.max(tamanoEstrella * e.escala * vista.escala, minimoPx);
      transformaciones.add(
        RSTransform.fromComponents(
          rotation: giro,
          scale: px * factor / lado,
          anchorX: lado / 2,
          anchorY: lado / 2,
          translateX: p.dx,
          translateY: p.dy,
        ),
      );
      rects.add(texturas.rectEstrella(sprite));
      colores.add(color);
    }

    for (final e in escena.estrellas) {
      if (!visible.contains(e.posicion)) continue;
      final esHoy = e.numero == hoy;
      final sprite = e.cierra
          ? VariantesEstrella.normales + (e.constelacion % 2)
          : e.variante;
      var factor = e.cierra ? 1.8 : 1.0;
      // Un parpadeo muy suave, distinto en cada estrella.
      var brillo = 0.82 + 0.18 * math.sin(segundos * 1.7 + e.numero * 2.39);
      if (esHoy) {
        factor *= 1.25 + 0.12 * math.sin(segundos * 2 * math.pi / 2.4);
        brillo = 1;
      }
      if (e.numero == nueva) factor *= _rebote(aparicion);
      final base = esHoy
          ? PaletaProfundidad.amarillo
          : PaletaProfundidad.estrellas[e.variante];
      // Los destellos no giran: así parecen luz y no un dibujo.
      final giro = (e.cierra || e.variante == 5) ? 0.0 : e.giro;
      anadir(e, sprite, factor, base.withValues(alpha: brillo), giro);
    }

    // El fogonazo de la estrella que aparece: crece y se apaga.
    if (nueva != null && nueva < escena.estrellas.length && aparicion < 1) {
      anadir(
        escena.estrellas[nueva],
        VariantesEstrella.normales + 1,
        1.2 + 3.5 * aparicion,
        PaletaProfundidad.amarillo.withValues(alpha: (1 - aparicion) * 0.9),
        0,
      );
    }

    if (transformaciones.isEmpty) return;
    canvas.drawAtlas(
      texturas.estrellas,
      transformaciones,
      rects,
      colores,
      BlendMode.modulate,
      null,
      Paint()
        ..blendMode = BlendMode.plus
        ..filterQuality = FilterQuality.medium,
    );
  }

  /// Crece un poco más de la cuenta y vuelve (0 → 1).
  static double _rebote(double t) {
    const s = 1.70158;
    final x = t - 1;
    return 1 + (s + 1) * x * x * x + s * x * x;
  }
}
