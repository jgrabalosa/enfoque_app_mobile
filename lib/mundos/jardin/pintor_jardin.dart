import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

import '../escena_mundo.dart';
import '../vista_mundo.dart';
import 'colocador_jardin.dart';
import 'dibujos_jardin.dart';
import 'escena_jardin.dart';
import 'flores.dart';
import 'paleta_dulce.dart';
import 'texturas_jardin.dart';

/// Una forma de dibujar el jardín.
typedef PintorJardin = PintorMundo<EscenaJardin>;

/// El jardín de Dulce **a lápiz de color**, lo más real posible
/// (`encargos/focus-mundos.md` §12).
///
/// - El papel, con su diente, lo pinta un shader pegado al mundo.
/// - Todo se dibuja con [Lapiz]: trazos con presión que el pigmento
///   convierte en motas según el relieve del papel.
/// - Las capas se mezclan con `multiply`, como se cargan los lápices de
///   verdad: el color de encima oscurece al de debajo.
/// - **El parterre que se está llenando va a grafito**, como un boceto. Al
///   completarse (10 flores), se colorea entero y le crece el seto.
class PintorJardinLapiz extends PintorJardin {
  PintorJardinLapiz({this.densidad});

  /// Píxeles físicos por lógico. Si no se da, el de la pantalla.
  final double? densidad;

  @override
  String get nombre => 'Lápiz';

  TexturasJardin? _texturas;
  CacheDibujos? _cache;
  FragmentShader? _papel;

  @override
  String? get aviso => _papel == null ? 'sin papel' : null;

  @override
  Future<void> preparar() async {
    if (_texturas != null) return;
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.caveat(fontWeight: FontWeight.w600),
      ]);
    } catch (e) {
      debugPrint('Jardín sin la letra a mano: $e');
    }
    final t = await TexturasJardin.crear();
    _texturas = t;
    _cache = CacheDibujos(t.pigmento);
    try {
      _papel = (await FragmentProgram.fromAsset(
        'shaders/papel.frag',
      )).fragmentShader();
    } catch (e) {
      debugPrint('Jardín sin papel: $e');
    }
  }

  @override
  void liberar() {
    _texturas?.liberar();
    _texturas = null;
    _cache?.vaciar();
    _cache = null;
    _papel?.dispose();
    _papel = null;
  }

  double get _dpr {
    if (densidad != null) return densidad!;
    final vistas = ui.PlatformDispatcher.instance.views;
    return vistas.isEmpty ? 1 : vistas.first.devicePixelRatio;
  }

  @override
  void pintar(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaJardin escena, {
    required double segundos,
    int? nueva,
    double aparicion = 1,
  }) {
    final t = _texturas;
    final cache = _cache;
    if (t == null || cache == null) return;
    cache.nuevoFotograma();
    _pintarPapel(canvas, tamano, vista, escena);

    // La resolución a la que se hornean los dibujos: la de la pantalla,
    // redondeada a un escalón (para no rehacerlos a cada pellizco).
    final pxPantalla = vista.escala * _dpr;
    final px = pxPantalla >= 1.4
        ? 2.0
        : pxPantalla >= 0.7
        ? 1.0
        : pxPantalla >= 0.35
        ? 0.5
        : 0.25;

    canvas.save();
    canvas.translate(tamano.width / 2, tamano.height / 2);
    canvas.scale(vista.escala);
    canvas.translate(-vista.centro.dx, -vista.centro.dy);
    final visible = vista.visible(tamano, margen: 80);
    final semilla = escena.colocador.semilla;

    // El parterre que se completa ahora mismo: su color va apareciendo.
    final completaAhora =
        nueva != null &&
            nueva % ColocadorJardin.piezasPorParterre ==
                ColocadorJardin.piezasPorParterre - 1
        ? ColocadorJardin.parterreDe(nueva)
        : null;

    void dibujo(Object clave, DibujoJardin Function() d, {double alfa = 1}) {
      if (alfa <= 0) return;
      final h = cache.obtener(clave, px, d, semilla: semilla);
      if (h == null || !visible.overlaps(h.mundo)) return;
      final i = h.imagen;
      canvas.drawImageRect(
        i,
        Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble()),
        h.mundo,
        Paint()
          ..blendMode = BlendMode.multiply
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(255, 255, 255, alfa.clamp(0.0, 1.0)),
      );
    }

    // Los caminos.
    for (final (a, b) in escena.caminos) {
      final caja = Rect.fromPoints(a, b).inflate(30);
      if (!visible.overlaps(caja)) continue;
      dibujo(('camino', a, b), () => DibujosJardin.camino(a, b, semilla));
    }
    // El árbol.
    if (visible.overlaps(Rect.fromCircle(center: Offset.zero, radius: 200))) {
      dibujo('arbol', () => DibujosJardin.arbol(semilla));
    }
    // Los hitos.
    for (final h in escena.hitos) {
      if (!visible.overlaps(Rect.fromCircle(center: h.centro, radius: 130))) {
        continue;
      }
      dibujo(('hito', h.numero), () => DibujosJardin.hito(h, semilla));
    }
    // Los parterres.
    for (var m = 0; m < escena.parterresConFlores; m++) {
      final p = escena.colocador.parterre(m);
      if (!visible.overlaps(p.caja.inflate(60))) continue;
      final completo = escena.completo(m);
      if (m == completaAhora && aparicion < 1) {
        // Se colorea ahora: del boceto al color, poco a poco.
        dibujo(
          ('parterre', m, false),
          () => DibujosJardin.parterre(p, semilla, completo: false),
          alfa: 1 - aparicion,
        );
        dibujo(
          ('parterre', m, true),
          () => DibujosJardin.parterre(p, semilla, completo: true),
          alfa: aparicion,
        );
        continue;
      }
      dibujo((
        'parterre',
        m,
        completo,
      ), () => DibujosJardin.parterre(p, semilla, completo: completo));
    }

    _pintarFlores(canvas, t, escena, visible, nueva, aparicion, completaAhora);
    canvas.restore();
  }

  void _pintarPapel(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaJardin escena,
  ) {
    final rect = Offset.zero & tamano;
    final papel = _papel;
    if (papel == null) {
      canvas.drawRect(rect, Paint()..color = PaletaDulce.papel);
      return;
    }
    papel
      ..setFloat(0, tamano.width)
      ..setFloat(1, tamano.height)
      ..setFloat(2, vista.centro.dx)
      ..setFloat(3, vista.centro.dy)
      ..setFloat(4, vista.escala)
      ..setFloat(5, (escena.colocador.semilla % 1000) / 1000);
    canvas.drawRect(rect, Paint()..shader = papel);
  }

  void _pintarFlores(
    Canvas canvas,
    TexturasJardin t,
    EscenaJardin escena,
    Rect visible,
    int? nueva,
    double aparicion,
    int? completaAhora,
  ) {
    final transformaciones = <RSTransform>[];
    final rects = <Rect>[];
    final colorGrafito = <Color>[];
    final colorHojas = <Color>[];
    final colorPetalos = <Color>[];
    final colorCentro = <Color>[];
    final conColor = <bool>[];
    const radio = ColocadorJardin.radioFlor;
    Flor? laNueva;
    for (final f in escena.flores) {
      if (!visible.inflate(radio * 2).contains(f.centro)) continue;
      if (f.numero == nueva && aparicion < 1) {
        laNueva = f;
        continue;
      }
      transformaciones.add(_transformacion(f));
      rects.add(TexturasJardin.celdaDe(f.especie.index * 3 + f.variante));
      final completo = escena.completo(f.parterre);
      final alfa = f.parterre == completaAhora ? aparicion : 1.0;
      conColor.add(completo);
      colorGrafito.add(PaletaDulce.grafito);
      final petalo = PaletaDulce.lapices[f.color];
      colorHojas.add(PaletaDulce.verdes[f.hojas].withValues(alpha: alfa));
      colorPetalos.add(petalo.withValues(alpha: alfa));
      colorCentro.add(
        (f.especie == EspecieFlor.rosa
                ? Color.lerp(petalo, const Color(0xFF3A1A2A), 0.35)!
                : PaletaDulce.centroDe[f.especie]!)
            .withValues(alpha: alfa),
      );
    }

    final pintura = Paint()
      ..blendMode = BlendMode.multiply
      ..filterQuality = FilterQuality.medium;
    void capa(ui.Image atlas, List<Color> colores, {bool soloColor = false}) {
      final tr = <RSTransform>[];
      final re = <Rect>[];
      final co = <Color>[];
      for (var i = 0; i < transformaciones.length; i++) {
        if (soloColor && !conColor[i]) continue;
        tr.add(transformaciones[i]);
        re.add(rects[i]);
        co.add(colores[i]);
      }
      if (tr.isEmpty) return;
      canvas.drawAtlas(atlas, tr, re, co, BlendMode.modulate, null, pintura);
    }

    capa(t.grafito, colorGrafito);
    capa(t.hojas, colorHojas, soloColor: true);
    capa(t.petalos, colorPetalos, soloColor: true);
    capa(t.centro, colorCentro, soloColor: true);

    // La flor nueva se va dibujando desde el centro hacia fuera.
    final f = laNueva;
    if (f != null) {
      final r = radio * f.escala * 1.5 * _facil(aparicion);
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: f.centro, radius: r)),
      );
      canvas.drawAtlas(
        t.grafito,
        [_transformacion(f)],
        [TexturasJardin.celdaDe(f.especie.index * 3 + f.variante)],
        [PaletaDulce.grafito.withValues(alpha: math.min(1, aparicion * 2))],
        BlendMode.modulate,
        null,
        pintura,
      );
      canvas.restore();
    }
  }

  static RSTransform _transformacion(Flor f) => RSTransform.fromComponents(
    rotation: f.giro,
    scale: f.escala * ColocadorJardin.radioFlor / Flores.radio,
    anchorX: Flores.lado / 2,
    anchorY: Flores.lado / 2,
    translateX: f.centro.dx,
    translateY: f.centro.dy,
  );

  static double _facil(double t) {
    final x = 1 - t.clamp(0.0, 1.0);
    return 1 - x * x * x;
  }
}
