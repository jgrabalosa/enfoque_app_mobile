import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import '../azar.dart';
import '../vista_mundo.dart';
import 'colocador_ciudad.dart';
import 'escena_ciudad.dart';
import 'paleta_neotokyo.dart';
import 'texturas_ciudad.dart';

/// La ciudad de Neotokyo+ **toda por código**: el suelo (calles mojadas,
/// farolas, avenidas de neón y el río) lo pinta un shader; los edificios son
/// cajas con perspectiva desde arriba (los altos se abren hacia fuera al
/// moverse, como en los juegos de vista cenital), con ventanas y borde de
/// neón; los coches son luces que circulan. No hay ni un PNG.
class PintorCiudadCodigo extends PintorCiudad {
  PintorCiudadCodigo({this.rutaShader = 'shaders/ciudad_noche.frag'});

  final String rutaShader;

  @override
  String get nombre => 'Código';

  TexturasCiudad? _texturas;

  /// Las texturas, cuando ya están preparadas.
  @protected
  TexturasCiudad? get texturas => _texturas;

  /// Si la pantalla es la vista isométrica (la de «Neotokyo+ 3D»): el suelo
  /// se dibuja girado.
  @protected
  bool get isometrico => false;
  FragmentShader? _suelo;

  bool get conShader => _suelo != null;

  @override
  String? get aviso => conShader ? null : 'sin shader';

  // Lo que depende solo de la escena: se calcula una vez por escena.
  EscenaCiudad? _escena;
  List<Edificio> _ordenados = const [];
  List<_Coche> _coches = const [];

  /// La torre de la plaza del centro: siempre está.
  static final Edificio torre = Edificio(
    numero: -1,
    manzana: -1,
    indice: 0,
    rect: Rect.fromCenter(center: Offset.zero, width: 64, height: 64),
    altura: 380,
    neon: 0,
    tejado: TejadoCiudad.antena,
  );

  @override
  Future<void> preparar() async {
    if (_texturas != null) return;
    _texturas = TexturasCiudad.crear();
    try {
      _suelo = (await FragmentProgram.fromAsset(rutaShader)).fragmentShader();
    } catch (e) {
      debugPrint('Ciudad sin shader: $e');
    }
  }

  @override
  void liberar() {
    _texturas?.liberar();
    _texturas = null;
    _suelo?.dispose();
    _suelo = null;
    _escena = null;
  }

  @protected
  void alCambiarEscena(EscenaCiudad escena) {
    if (identical(escena, _escena)) return;
    _escena = escena;
    _ordenados = [torre, ...escena.edificios]
      ..sort((a, b) => a.altura.compareTo(b.altura));
    final semilla = escena.colocador.semilla;
    final cuantos = math.min(escena.calles.length * 2, 360);
    _coches = [
      for (var k = 0; k < cuantos; k++)
        _Coche(
          tramo: k % escena.calles.length,
          sentido: azarMundo(semilla, k, 71) < 0.5 ? 1 : -1,
          fase: azarMundo(semilla, k, 72),
          velocidad: 35 + azarMundo(semilla, k, 73) * 55,
        ),
    ];
  }

  @override
  void pintar(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaCiudad escena, {
    required double segundos,
    int? nueva,
    double aparicion = 1,
  }) {
    final texturas = _texturas;
    if (texturas == null) return;
    alCambiarEscena(escena);

    pintarSuelo(canvas, tamano, vista, escena, segundos);

    canvas.save();
    canvas.translate(tamano.width / 2, tamano.height / 2);
    canvas.scale(vista.escala);
    canvas.translate(-vista.centro.dx, -vista.centro.dy);
    final visible = vista.visible(tamano, margen: 260);
    final px = 1 / vista.escala; // un píxel, en unidades del mundo

    pintarPlaza(canvas, segundos);
    for (final h in escena.hitos) {
      if (visible.overlaps(h.rect)) pintarHito(canvas, h, segundos, px);
    }
    pintarCoches(canvas, escena, texturas, visible, segundos, px);
    _pintarEdificios(
      canvas,
      tamano,
      vista,
      escena,
      texturas,
      visible,
      segundos,
      nueva,
      aparicion,
      px,
    );
    _pintarFoco(canvas, tamano, vista, segundos);
    canvas.restore();

    _pintarCartel(canvas, tamano, vista, escena, segundos);
  }

  // ── El suelo ─────────────────────────────────────────────────────────────

  @protected
  void pintarSuelo(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaCiudad escena,
    double segundos,
  ) {
    final rect = Offset.zero & tamano;
    final suelo = _suelo;
    if (suelo == null) {
      canvas.drawRect(rect, Paint()..color = PaletaNeotokyo.fondo);
      return;
    }
    final c = escena.colocador;
    suelo
      ..setFloat(0, tamano.width)
      ..setFloat(1, tamano.height)
      ..setFloat(2, vista.centro.dx)
      ..setFloat(3, vista.centro.dy)
      ..setFloat(4, vista.escala)
      ..setFloat(5, (c.semilla % 1000) / 1000)
      ..setFloat(6, escena.radio)
      ..setFloat(7, c.rioVertical ? 1 : 0)
      ..setFloat(8, c.rioFase)
      ..setFloat(9, c.rioDesplazamiento)
      ..setFloat(10, segundos % 1000)
      ..setFloat(11, isometrico ? 1 : 0);
    canvas.drawRect(rect, Paint()..shader = suelo);
  }

  // ── La plaza del centro y los hitos ──────────────────────────────────────

  @protected
  void pintarPlaza(Canvas canvas, double s) {
    final plaza = ColocadorCiudad.rectCelda(0, 0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plaza.deflate(6), const Radius.circular(18)),
      Paint()..color = const Color(0xFF1B1030),
    );
    // Anillos de luz alrededor de la torre, que laten.
    for (var k = 1; k <= 3; k++) {
      final pulso = 0.5 + 0.5 * math.sin(s * 1.2 - k * 0.9);
      canvas.drawCircle(
        Offset.zero,
        34.0 + k * 18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..blendMode = BlendMode.plus
          ..color = PaletaNeotokyo.rosa.withValues(alpha: 0.18 + 0.25 * pulso),
      );
    }
  }

  @protected
  void pintarHito(Canvas canvas, HitoCiudad h, double s, double px) {
    final r = h.rect.deflate(6);
    final suma = Paint()..blendMode = BlendMode.plus;
    switch (h.tipo) {
      case TipoHitoCiudad.parque:
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(14)),
          Paint()..color = const Color(0xFF0C241E),
        );
        // Un estanque.
        final estanque = Rect.fromCenter(
          center: r.center + Offset(30 * (h.giro - 0.5), 20),
          width: 70,
          height: 44,
        );
        canvas.drawOval(estanque, Paint()..color = const Color(0xFF06223A));
        canvas.drawOval(
          estanque,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..blendMode = BlendMode.plus
            ..color = PaletaNeotokyo.cian.withValues(alpha: 0.5),
        );
        // Caminos con farolillos.
        final camino = Paint()
          ..strokeWidth = 5
          ..color = const Color(0xFF241B2E);
        canvas.drawLine(r.topLeft, r.bottomRight, camino);
        canvas.drawLine(r.bottomLeft, r.topRight, camino);
        for (var k = 1; k < 8; k++) {
          final t = k / 8;
          for (final p in [
            Offset.lerp(r.topLeft, r.bottomRight, t)!,
            Offset.lerp(r.bottomLeft, r.topRight, t)!,
          ]) {
            canvas.drawCircle(p, 5, suma..color = const Color(0x66FFD9A0));
          }
        }
        // Árboles.
        for (var k = 0; k < 26; k++) {
          final p = Offset(
            r.left + 12 + azarMundo(h.numero, k, 81) * (r.width - 24),
            r.top + 12 + azarMundo(h.numero, k, 82) * (r.height - 24),
          );
          if (estanque.inflate(10).contains(p)) continue;
          final radio = 8 + azarMundo(h.numero, k, 83) * 7;
          canvas.drawCircle(p, radio, Paint()..color = const Color(0xFF14412F));
          canvas.drawCircle(
            p - Offset(radio * 0.3, radio * 0.3),
            radio * 0.45,
            Paint()..color = const Color(0xFF1F5E44),
          );
        }
      case TipoHitoCiudad.plaza:
        canvas.drawRect(r, Paint()..color = const Color(0xFF231433));
        final rejilla = Paint()
          ..strokeWidth = 1
          ..blendMode = BlendMode.plus
          ..color = PaletaNeotokyo.rosa.withValues(alpha: 0.12);
        for (var k = 1; k < 8; k++) {
          final x = r.left + r.width * k / 8;
          final y = r.top + r.height * k / 8;
          canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), rejilla);
          canvas.drawLine(Offset(r.left, y), Offset(r.right, y), rejilla);
        }
        // La fuente: ondas que salen del centro.
        for (var k = 0; k < 4; k++) {
          final t = ((s * 0.35 + k / 4) % 1);
          canvas.drawCircle(
            r.center,
            10 + t * 60,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..blendMode = BlendMode.plus
              ..color = PaletaNeotokyo.cian.withValues(alpha: 0.6 * (1 - t)),
          );
        }
        canvas.drawCircle(
          r.center,
          10,
          suma..color = PaletaNeotokyo.cian.withValues(alpha: 0.7),
        );
      case TipoHitoCiudad.estacion:
        canvas.drawRect(r, Paint()..color = const Color(0xFF15102A));
        final vertical = h.giro < 0.5;
        // Las vías, de lado a lado (y algo más allá).
        final vias = Paint()
          ..strokeWidth = 2
          ..blendMode = BlendMode.plus
          ..color = const Color(0x55B9A6FF);
        for (final d in [-22.0, -12.0, 12.0, 22.0]) {
          final a = vertical
              ? Offset(r.center.dx + d, r.top - 30)
              : Offset(r.left - 30, r.center.dy + d);
          final b = vertical
              ? Offset(r.center.dx + d, r.bottom + 30)
              : Offset(r.right + 30, r.center.dy + d);
          canvas.drawLine(a, b, vias);
        }
        // El andén, con su borde amarillo.
        final anden = vertical
            ? Rect.fromCenter(
                center: r.center,
                width: 16,
                height: r.height * 0.7,
              )
            : Rect.fromCenter(
                center: r.center,
                width: r.width * 0.7,
                height: 16,
              );
        canvas.drawRect(anden, Paint()..color = const Color(0xFF2B2140));
        canvas.drawRect(
          anden,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..blendMode = BlendMode.plus
            ..color = PaletaNeotokyo.amarillo.withValues(alpha: 0.7),
        );
        // Un tren de luz que pasa.
        final t = (s * 0.12 + h.giro) % 1;
        final largo = r.longestSide + 60;
        for (var k = 0; k < 6; k++) {
          final pos = -30 + (t * (largo + 120) - 60) - k * 14;
          if (pos < -30 || pos > largo - 30) continue;
          final vagon = vertical
              ? Rect.fromLTWH(r.center.dx + 13, r.top + pos, 8, 12)
              : Rect.fromLTWH(r.left + pos, r.center.dy + 13, 12, 8);
          canvas.drawRect(
            vagon,
            suma..color = PaletaNeotokyo.cian.withValues(alpha: 0.85),
          );
        }
      case TipoHitoCiudad.estadio:
        canvas.drawRect(r, Paint()..color = const Color(0xFF140E26));
        final ovalo = r.deflate(14);
        canvas.drawOval(ovalo, Paint()..color = const Color(0xFF2A1B3F));
        canvas.drawOval(
          ovalo.deflate(16),
          Paint()..color = const Color(0xFF0F3A2A),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: ovalo.center,
            width: ovalo.width * 0.45,
            height: ovalo.height * 0.3,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0x88FFFFFF),
        );
        canvas.drawOval(
          ovalo,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..blendMode = BlendMode.plus
            ..color = PaletaNeotokyo.rosa.withValues(alpha: 0.55),
        );
        // Los focos de las cuatro esquinas.
        for (final p in [
          ovalo.topLeft,
          ovalo.topRight,
          ovalo.bottomLeft,
          ovalo.bottomRight,
        ]) {
          canvas.drawCircle(p, 16, suma..color = const Color(0x55FFFFFF));
          canvas.drawCircle(p, 5, suma..color = const Color(0xDDFFFFFF));
        }
    }
  }

  // ── Los coches ───────────────────────────────────────────────────────────

  @protected
  void pintarCoches(
    Canvas canvas,
    EscenaCiudad escena,
    TexturasCiudad texturas,
    Rect visible,
    double s,
    double px,
  ) {
    if (_coches.isEmpty || px > 14) return;
    final transformaciones = <RSTransform>[];
    final rects = <Rect>[];
    final colores = <Color>[];
    const lado = TexturasCiudad.ladoLuz * 1.0;
    final fuente = Rect.fromLTWH(0, 0, lado, lado);
    final tamano = math.max(12.0, 3 * px);
    // Se apagan suavemente al alejarse.
    final alfa = (1 - (px - 6) / 8).clamp(0.0, 1.0);
    for (final c in _coches) {
      final (a, b) = escena.calles[c.tramo];
      final largo = (b - a).distance;
      if (largo == 0) continue;
      var t = (c.fase + s * c.velocidad / largo) % 1;
      if (c.sentido < 0) t = 1 - t;
      final dir = (b - a) / largo * c.sentido.toDouble();
      // Cada sentido, por su carril.
      final carril = Offset(-dir.dy, dir.dx) * 7;
      final p = Offset.lerp(a, b, t)! + carril;
      if (!visible.contains(p)) continue;
      for (final (delante, color) in [
        (true, const Color(0xFFFFF4DA)),
        (false, const Color(0xFFFF3355)),
      ]) {
        final q = p + dir * (delante ? 4 : -4);
        transformaciones.add(
          RSTransform.fromComponents(
            rotation: 0,
            scale: tamano / lado,
            anchorX: lado / 2,
            anchorY: lado / 2,
            translateX: q.dx,
            translateY: q.dy,
          ),
        );
        rects.add(fuente);
        colores.add(color.withValues(alpha: alfa * (delante ? 0.95 : 0.8)));
      }
    }
    if (transformaciones.isEmpty) return;
    canvas.drawAtlas(
      texturas.luz,
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

  // ── Los edificios ────────────────────────────────────────────────────────

  void _pintarEdificios(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaCiudad escena,
    TexturasCiudad texturas,
    Rect visible,
    double s,
    int? nueva,
    double aparicion,
    double px,
  ) {
    final cam = vista.centro;
    // La altura de la cámara: con ella, los edificios altos se abren hacia
    // fuera más de cerca que de lejos.
    final alturaCamara =
        math.min(tamano.width, tamano.height) / vista.escala * 1.15;
    final hoy = escena.cantidad - 1;

    final posiciones = <double>[];
    final texturasXY = <double>[];
    final colores = <int>[];
    final tejados = <(Edificio, List<Offset>, double)>[];

    const porUnidad = 0.6; // texeles de ventana por unidad del mundo
    const liso = TexturasCiudad.puntoLiso;
    final cAbajo = PaletaNeotokyo.fachadaAbajo;
    final cArriba = PaletaNeotokyo.fachadaArriba;

    for (final e in _ordenados) {
      if (!visible.overlaps(e.rect)) continue;
      var altura = e.altura;
      if (e.numero == nueva) altura *= _Curvas.easeOutCubic(aparicion);
      final h = math.min(altura, alturaCamara * 0.7);
      final k = alturaCamara / (alturaCamara - h);
      final base = [
        e.rect.topLeft,
        e.rect.topRight,
        e.rect.bottomRight,
        e.rect.bottomLeft,
      ];
      final tejado = [for (final p in base) cam + (p - cam) * k];
      // Cada pared, con su luz: más clara la que mira al oeste y al norte.
      const luces = [0.78, 1.0, 0.62, 0.9];
      final u0 = (e.numero * 13 % 64).toDouble();
      for (var lado = 0; lado < 4; lado++) {
        final a0 = base[lado], a1 = base[(lado + 1) % 4];
        final b0 = tejado[lado], b1 = tejado[(lado + 1) % 4];
        final largo = (a1 - a0).distance * porUnidad;
        final alto = h * porUnidad;
        final luz = luces[lado];
        final abajo = _multiplicar(cAbajo, luz);
        final arriba = _multiplicar(cArriba, luz);
        posiciones.addAll([
          a0.dx, a0.dy, a1.dx, a1.dy, b1.dx, b1.dy, //
          a0.dx, a0.dy, b1.dx, b1.dy, b0.dx, b0.dy,
        ]);
        texturasXY.addAll([
          u0, alto, u0 + largo, alto, u0 + largo, 0, //
          u0, alto, u0 + largo, 0, u0, 0,
        ]);
        colores.addAll([abajo, abajo, arriba, abajo, arriba, arriba]);
      }
      // El tejado, con el trozo liso de la textura.
      final cTejado = _multiplicar(
        PaletaNeotokyo.tejado,
        (0.9 + 0.3 * azarMundo(e.numero, 0, 91)) / TexturasCiudad.grisLiso,
      );
      posiciones.addAll([
        tejado[0].dx, tejado[0].dy, tejado[1].dx, tejado[1].dy, //
        tejado[2].dx, tejado[2].dy, tejado[0].dx, tejado[0].dy,
        tejado[2].dx, tejado[2].dy, tejado[3].dx, tejado[3].dy,
      ]);
      for (var i = 0; i < 6; i++) {
        texturasXY.addAll([liso.dx, liso.dy]);
        colores.add(cTejado);
      }
      tejados.add((e, tejado, k));
    }
    if (posiciones.isEmpty) return;

    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      Float32List.fromList(posiciones),
      textureCoordinates: Float32List.fromList(texturasXY),
      colors: Int32List.fromList(colores),
    );
    canvas.drawVertices(
      vertices,
      BlendMode.modulate,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..shader = ImageShader(
          texturas.ventanas,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4Identidad.storage,
        ),
    );
    vertices.dispose();

    _pintarNeones(canvas, tejados, hoy, s, px);
  }

  /// El borde de neón de los tejados y lo que hay encima. Se pinta después
  /// de todos los edificios: es luz y no la tapa nada.
  void _pintarNeones(
    Canvas canvas,
    List<(Edificio, List<Offset>, double)> tejados,
    int hoy,
    double s,
    double px,
  ) {
    final porColor = List.generate(NeonCiudad.colores, (_) => <double>[]);
    final deHoy = <double>[];
    final detalle = px < 3; // los detalles del tejado, solo de cerca
    final suma = Paint()..blendMode = BlendMode.plus;

    for (final (e, t, _) in tejados) {
      final conNeon =
          e.cierra ||
          e.numero == hoy ||
          e.numero < 0 ||
          azarMundo(e.numero, 0, 92) < 0.62;
      if (conNeon) {
        final destino = e.numero == hoy ? deHoy : porColor[e.neon];
        for (var i = 0; i < 4; i++) {
          final a = t[i], b = t[(i + 1) % 4];
          destino.addAll([a.dx, a.dy, b.dx, b.dy]);
        }
      }
      if (!detalle) continue;
      final centro = (t[0] + t[2]) / 2;
      final lado = math.min((t[1] - t[0]).distance, (t[3] - t[0]).distance);
      final color = PaletaNeotokyo.neones[e.neon];
      switch (e.tejado) {
        case TejadoCiudad.helipuerto when lado > 34:
          canvas.drawCircle(
            centro,
            lado * 0.32,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = const Color(0x99F5EEFF),
          );
          final hh = lado * 0.14;
          final trazo = Paint()
            ..strokeWidth = 1.6
            ..color = const Color(0xCCF5EEFF);
          canvas.drawLine(
            centro + Offset(-hh, -hh),
            centro + Offset(-hh, hh),
            trazo,
          );
          canvas.drawLine(
            centro + Offset(hh, -hh),
            centro + Offset(hh, hh),
            trazo,
          );
          canvas.drawLine(
            centro + Offset(-hh, 0),
            centro + Offset(hh, 0),
            trazo,
          );
        case TejadoCiudad.antena:
          final parpadeo = math.sin(s * 3 + e.numero) > 0.2 ? 1.0 : 0.15;
          canvas.drawCircle(
            centro,
            e.numero < 0 ? 9 : 5,
            suma..color = const Color(0xFFFF3355).withValues(alpha: parpadeo),
          );
          canvas.drawCircle(
            centro,
            e.numero < 0 ? 26 : 14,
            suma
              ..color = const Color(
                0xFFFF3355,
              ).withValues(alpha: 0.25 * parpadeo),
          );
        case TejadoCiudad.jardin when lado > 24:
          final piscina = Rect.fromCenter(
            center: centro,
            width: lado * 0.5,
            height: lado * 0.3,
          );
          canvas.drawRect(piscina, Paint()..color = const Color(0xFF0A5A73));
          canvas.drawRect(
            piscina.inflate(3),
            suma..color = PaletaNeotokyo.cian.withValues(alpha: 0.18),
          );
        case TejadoCiudad.maquinas when lado > 20:
          for (var k = 0; k < 3; k++) {
            final p =
                centro +
                Offset(
                  (azarMundo(e.numero, k, 93) - 0.5) * lado * 0.6,
                  (azarMundo(e.numero, k, 94) - 0.5) * lado * 0.6,
                );
            canvas.drawRect(
              Rect.fromCenter(center: p, width: 7, height: 5),
              Paint()..color = const Color(0xFF3A3150),
            );
          }
        case TejadoCiudad.cartel:
          // El cartel de neón del que cierra la manzana: parpadea de vez en
          // cuando, como los de verdad.
          final fallo = (s * 0.7 + e.numero * 0.37) % 7 < 0.12 ? 0.3 : 1.0;
          final cartel = Rect.fromCenter(
            center: centro,
            width: lado * 0.62,
            height: lado * 0.22,
          );
          canvas.drawRect(
            cartel.inflate(6),
            suma..color = color.withValues(alpha: 0.22 * fallo),
          );
          canvas.drawRect(
            cartel,
            suma..color = color.withValues(alpha: 0.85 * fallo),
          );
        default:
          break;
      }
    }

    void trazar(List<double> lineas, Color color, double ancho, double alfa) {
      if (lineas.isEmpty) return;
      final lista = Float32List.fromList(lineas);
      final pincel = Paint()
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus;
      canvas.drawRawPoints(
        PointMode.lines,
        lista,
        pincel
          ..strokeWidth = ancho * 5 * px
          ..color = color.withValues(alpha: 0.16 * alfa),
      );
      canvas.drawRawPoints(
        PointMode.lines,
        lista,
        pincel
          ..strokeWidth = ancho * px
          ..color = TexturasCiudad.claro(color).withValues(alpha: alfa),
      );
    }

    for (var c = 0; c < NeonCiudad.colores; c++) {
      trazar(porColor[c], PaletaNeotokyo.neones[c], 1.3, 0.85);
    }
    final pulso = 0.7 + 0.3 * math.sin(s * 2 * math.pi / 2.4);
    trazar(deHoy, PaletaNeotokyo.amarillo, 2.2, pulso);
  }

  /// El foco de la torre, que barre la ciudad despacio.
  void _pintarFoco(Canvas canvas, Size tamano, VistaMundo vista, double s) {
    final alturaCamara =
        math.min(tamano.width, tamano.height) / vista.escala * 1.15;
    final h = math.min(torre.altura, alturaCamara * 0.7);
    final cima =
        vista.centro +
        (Offset.zero - vista.centro) * (alturaCamara / (alturaCamara - h));
    const largo = 900.0;
    final angulo = s * 0.35;
    final dir = Offset(math.cos(angulo), math.sin(angulo));
    final normal = Offset(-dir.dy, dir.dx);
    final fin = cima + dir * largo;
    final path = Path()
      ..moveTo(cima.dx, cima.dy)
      ..lineTo((fin + normal * 110).dx, (fin + normal * 110).dy)
      ..lineTo((fin - normal * 110).dx, (fin - normal * 110).dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(cima, fin, const [
          Color(0x33FFE9F4),
          Color(0x00FFE9F4),
        ]),
    );
  }

  /// El nombre de la manzana de hoy, en neón, encima de ella (solo de
  /// cerca).
  void _pintarCartel(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaCiudad escena,
    double s,
  ) {
    if (escena.cantidad == 0 || vista.escala < 0.45) return;
    final m = escena.colocador.manzana(escena.deLaUltima);
    pintarNombre(canvas, m.nombre, vista.aPantalla(m.rect.topCenter, tamano));
  }

  /// [nombre] en neón rosa, centrado encima de [punto] (en la pantalla).
  @protected
  static void pintarNombre(Canvas canvas, String nombre, Offset punto) {
    final texto = TextPainter(
      text: TextSpan(
        text: nombre.toUpperCase(),
        style: TextStyle(
          color: TexturasCiudad.claro(PaletaNeotokyo.rosa),
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
          shadows: const [
            Shadow(color: PaletaNeotokyo.rosa, blurRadius: 8),
            Shadow(color: PaletaNeotokyo.rosa, blurRadius: 22),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texto.paint(canvas, punto - Offset(texto.width / 2, texto.height + 14));
    texto.dispose();
  }

  static int _multiplicar(Color c, double f) => Color.from(
    alpha: 1,
    red: (c.r * f).clamp(0.0, 1.0),
    green: (c.g * f).clamp(0.0, 1.0),
    blue: (c.b * f).clamp(0.0, 1.0),
  ).toARGB32();
}

/// La matriz identidad, para la textura de ventanas: un texel por unidad de
/// sus coordenadas.
abstract final class Matrix4Identidad {
  static final Float64List storage = Float64List.fromList([
    1, 0, 0, 0, //
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  ]);
}

class _Coche {
  const _Coche({
    required this.tramo,
    required this.sentido,
    required this.fase,
    required this.velocidad,
  });

  final int tramo;
  final int sentido;
  final double fase;
  final double velocidad;
}

/// Las curvas de animación que hacen falta aquí, sin traer `material`.
abstract final class _Curvas {
  static double easeOutCubic(double t) {
    final x = 1 - t;
    return 1 - x * x * x;
  }
}
