import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../azar.dart';
import '../vista_mundo.dart';
import 'colocador_ciudad.dart';
import 'escena_ciudad.dart';
import 'paleta_neotokyo.dart';
import 'pintor_ciudad.dart';

/// La vista isométrica de Neotokyo+ («Neotokyo+ 3D»): la misma cámara con la
/// que se renderizaron los edificios en Blender (girada 45° y mirando 30°
/// hacia abajo, sin perspectiva).
///
/// La ciudad sigue colocada en el suelo (x, y) como siempre; lo que cambia
/// es la pantalla, que pasa a ser el plano de la cámara (u, v):
///
///     u = (x + y) / √2        v = (x − y) / (2√2)
///
/// y una altura z sube la pantalla z · 0,866. Una unidad de Blender son
/// [unidad] unidades del mundo.
abstract final class Iso {
  static const double unidad = 60;
  static const double _r2 = math.sqrt2;

  /// Del suelo a la pantalla isométrica.
  static Offset de(Offset suelo) =>
      Offset((suelo.dx + suelo.dy) / _r2, (suelo.dx - suelo.dy) / (2 * _r2));

  /// De la pantalla isométrica al suelo.
  static Offset alSuelo(Offset p) =>
      Offset(p.dx / _r2 + p.dy * _r2, p.dx / _r2 - p.dy * _r2);

  /// La parte del suelo que cae dentro de [pantalla] (un rectángulo de la
  /// vista isométrica): el rectángulo que la envuelve.
  static Rect sueloDe(Rect pantalla) {
    final esquinas = [
      alSuelo(pantalla.topLeft),
      alSuelo(pantalla.topRight),
      alSuelo(pantalla.bottomLeft),
      alSuelo(pantalla.bottomRight),
    ];
    return Rect.fromLTRB(
      esquinas.map((p) => p.dx).reduce(math.min),
      esquinas.map((p) => p.dy).reduce(math.min),
      esquinas.map((p) => p.dx).reduce(math.max),
      esquinas.map((p) => p.dy).reduce(math.max),
    );
  }

  /// La transformación del suelo a la pantalla, para `canvas.transform`: lo
  /// plano (calles, hitos, coches) se dibuja tal cual y sale tumbado.
  static final Float64List matriz = Float64List.fromList([
    1 / _r2, 1 / (2 * _r2), 0, 0, //
    1 / _r2, -1 / (2 * _r2), 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  ]);
}

/// La escena de la ciudad vista en isométrico: las mismas piezas, los mismos
/// edificios; solo cambia dónde quedan las regiones en la pantalla, para que
/// la cámara del laboratorio (Hoy, Cerca, Todo) funcione igual.
class EscenaCiudadIso extends EscenaCiudad {
  EscenaCiudadIso(super.colocador, super.cantidad);

  /// La manzana sube en la pantalla con sus edificios: el centro se pone un
  /// poco por encima del suelo para que quepan.
  @override
  Offset centroRegion(int region) =>
      Iso.de(colocador.manzana(region).rect.center) - const Offset(0, 70);

  @override
  double get ladoRegion => ColocadorCiudad.pasoCelda * 1.1;
}

/// Un edificio del kit: dónde está en el atlas y lo que mide.
class PiezaKit {
  const PiezaKit({
    required this.fuente,
    required this.ancla,
    required this.ancho,
    required this.fondo,
    required this.alto,
    required this.torre,
  });

  /// Su rectángulo en el atlas.
  final Rect fuente;

  /// Dónde cae el centro de su base, en píxeles desde la esquina de
  /// [fuente].
  final Offset ancla;

  /// La huella y la altura, en unidades de Blender.
  final double ancho;
  final double fondo;
  final double alto;
  final bool torre;
}

/// Los edificios renderizados con Blender: una imagen con todos y la lista
/// de dónde está cada uno (`tool/mundos/README.md`).
class KitNeotokyo {
  KitNeotokyo._(this.imagen, this.pxPorUnidad, this.piezas);

  static const String ruta = 'assets/mundos/neotokyo/edificios';

  final ui.Image imagen;
  final double pxPorUnidad;
  final List<PiezaKit> piezas;

  late final List<PiezaKit> normales = [
    for (final p in piezas)
      if (!p.torre) p,
  ];
  late final PiezaKit torre = piezas.firstWhere((p) => p.torre);

  static Future<KitNeotokyo> cargar() async {
    final json =
        jsonDecode(await rootBundle.loadString('$ruta.json'))
            as Map<String, dynamic>;
    final datos = await rootBundle.load('$ruta.webp');
    final codec = await ui.instantiateImageCodec(datos.buffer.asUint8List());
    final imagen = (await codec.getNextFrame()).image;
    codec.dispose();
    return KitNeotokyo._(imagen, (json['px_por_unidad'] as num).toDouble(), [
      for (final e in json['edificios'] as List)
        PiezaKit(
          fuente: Rect.fromLTWH(
            (e['x'] as num).toDouble(),
            (e['y'] as num).toDouble(),
            (e['w'] as num).toDouble(),
            (e['h'] as num).toDouble(),
          ),
          ancla: Offset(
            (e['ax'] as num).toDouble(),
            (e['ay'] as num).toDouble(),
          ),
          ancho: (e['ancho'] as num).toDouble(),
          fondo: (e['fondo'] as num).toDouble(),
          alto: (e['alto'] as num).toDouble(),
          torre: e['torre'] as bool,
        ),
    ]);
  }

  /// La pieza que le toca a [e] y a qué escala (unidades de Blender por cada
  /// unidad de Blender del kit). Se busca la que mejor encaja en su parcela
  /// y su altura, y se elige al azar (siempre igual) entre las tres mejores
  /// para que no salga siempre la misma.
  (PiezaKit, double) elegir(Edificio e, int semilla) {
    final w = e.rect.width / Iso.unidad;
    final d = e.rect.height / Iso.unidad;
    final h = e.altura / Iso.unidad;
    final costes = <(double, PiezaKit, double)>[];
    for (final p in normales) {
      final escala = math.min(w / p.ancho, d / p.fondo);
      final forma = (math.log(p.ancho / p.fondo) - math.log(w / d)).abs();
      final altura = (math.log(p.alto * escala / h)).abs();
      costes.add((forma * 1.5 + altura, p, escala));
    }
    costes.sort((a, b) => a.$1.compareTo(b.$1));
    final k = (azarMundo(semilla, e.numero, 61) * 3).floor();
    final (_, pieza, escala) = costes[k];
    return (pieza, escala);
  }

  void liberar() => imagen.dispose();
}

/// Neotokyo+ en isométrico con los edificios de Blender: el suelo es el
/// mismo shader de la ciudad (girado), los hitos y los coches son los
/// mismos (tumbados), y los edificios son imágenes renderizadas, ordenadas
/// de atrás adelante, con su reflejo en el asfalto mojado.
class PintorCiudadBlender extends PintorCiudadCodigo {
  PintorCiudadBlender({super.rutaShader});

  @override
  String get nombre => 'Blender';

  @override
  bool get isometrico => true;

  KitNeotokyo? _kit;
  String? _fallo;

  @override
  String? get aviso => _fallo ?? super.aviso;

  // Lo que depende solo de la escena.
  EscenaCiudad? _escena;
  List<_Colocado> _colocados = const [];

  @override
  Future<void> preparar() async {
    await super.preparar();
    if (_kit != null) return;
    try {
      _kit = await KitNeotokyo.cargar();
    } catch (e) {
      _fallo = 'sin kit';
      debugPrint('Neotokyo+ sin kit de edificios: $e');
    }
  }

  @override
  void liberar() {
    _kit?.liberar();
    _kit = null;
    _escena = null;
    super.liberar();
  }

  /// Los edificios con su pieza, su escala y su sitio, ordenados de atrás
  /// adelante: en esta cámara, de menor a mayor x − y.
  void _colocar(EscenaCiudad escena, KitNeotokyo kit) {
    if (identical(escena, _escena)) return;
    _escena = escena;
    final semilla = escena.colocador.semilla;
    final torre = kit.torre;
    _colocados = [
      _Colocado(
        edificio: PintorCiudadCodigo.torre,
        pieza: torre,
        escala:
            (PintorCiudadCodigo.torre.rect.width / Iso.unidad) / torre.ancho,
        kit: kit,
      ),
      for (final e in escena.edificios)
        () {
          final (pieza, escala) = kit.elegir(e, semilla);
          return _Colocado(edificio: e, pieza: pieza, escala: escala, kit: kit);
        }(),
    ]..sort((a, b) => a.orden.compareTo(b.orden));
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
    final texturas = this.texturas;
    final kit = _kit;
    if (texturas == null) return;
    alCambiarEscena(escena);

    pintarSuelo(canvas, tamano, vista, escena, segundos);
    if (kit == null) return;
    _colocar(escena, kit);

    canvas.save();
    canvas.translate(tamano.width / 2, tamano.height / 2);
    canvas.scale(vista.escala);
    canvas.translate(-vista.centro.dx, -vista.centro.dy);
    final pantalla = vista.visible(tamano, margen: 80);
    final px = 1 / vista.escala;

    // Lo plano, tumbado sobre el suelo.
    canvas.save();
    canvas.transform(Iso.matriz);
    final suelo = Iso.sueloDe(pantalla.inflate(200));
    pintarPlaza(canvas, segundos);
    for (final h in escena.hitos) {
      if (suelo.overlaps(h.rect)) pintarHito(canvas, h, segundos, px);
    }
    pintarCoches(canvas, escena, texturas, suelo, segundos, px * 0.7);
    canvas.restore();

    // Los edificios que se ven: los altos asoman por arriba aunque su base
    // esté por debajo de la pantalla.
    final visibles = [
      for (final c in _colocados)
        if (c.cabeEn(pantalla)) c,
    ];
    final aparece = _aparicion(aparicion);
    _pintarReflejos(canvas, kit, visibles, nueva, aparece);
    _pintarEdificios(canvas, kit, visibles, nueva, aparece, px);
    _pintarFoco(canvas, segundos);
    canvas.restore();

    _pintarCartel(canvas, tamano, vista, escena);
  }

  static double _aparicion(double t) {
    final x = 1 - t.clamp(0.0, 1.0);
    return 1 - x * x * x;
  }

  /// El reflejo de cada edificio en el asfalto mojado: la imagen dada la
  /// vuelta por la base, tenue y sumando luz.
  void _pintarReflejos(
    Canvas canvas,
    KitNeotokyo kit,
    List<_Colocado> visibles,
    int? nueva,
    double aparece,
  ) {
    final transformaciones = <RSTransform>[];
    final rects = <Rect>[];
    final colores = <Color>[];
    for (final c in visibles) {
      final alfa = c.edificio.numero == nueva ? 0.16 * aparece : 0.16;
      if (alfa <= 0) continue;
      transformaciones.add(c.transformacion(volteado: true));
      rects.add(c.pieza.fuente);
      colores.add(Color.fromRGBO(255, 255, 255, alfa));
    }
    if (transformaciones.isEmpty) return;
    canvas.save();
    canvas.scale(1, -1);
    canvas.drawAtlas(
      kit.imagen,
      transformaciones,
      rects,
      colores,
      BlendMode.modulate,
      null,
      Paint()
        ..blendMode = BlendMode.plus
        ..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  /// Los edificios, de atrás adelante, en tandas de una sola llamada. El
  /// que está apareciendo sube desde el suelo, recortado por su base.
  void _pintarEdificios(
    Canvas canvas,
    KitNeotokyo kit,
    List<_Colocado> visibles,
    int? nueva,
    double aparece,
    double px,
  ) {
    final pintura = Paint()..filterQuality = FilterQuality.medium;
    var transformaciones = <RSTransform>[];
    var rects = <Rect>[];
    void soltar() {
      if (transformaciones.isEmpty) return;
      canvas.drawAtlas(
        kit.imagen,
        transformaciones,
        rects,
        null,
        null,
        null,
        pintura,
      );
      transformaciones = [];
      rects = [];
    }

    for (final c in visibles) {
      if (c.edificio.numero == nueva && aparece < 1) {
        soltar();
        _pintarNuevo(canvas, kit, c, aparece, pintura);
        continue;
      }
      transformaciones.add(c.transformacion());
      rects.add(c.pieza.fuente);
    }
    soltar();
  }

  void _pintarNuevo(
    Canvas canvas,
    KitNeotokyo kit,
    _Colocado c,
    double aparece,
    Paint pintura,
  ) {
    final base = c.base;
    final alto = c.pieza.ancla.dy * c.escalaPx;
    canvas.save();
    // Solo lo que está por encima del suelo (y la huella de delante).
    canvas.clipRect(
      Rect.fromLTRB(
        base.dx - 400,
        base.dy - alto - 50,
        base.dx + 400,
        base.dy + c.bajoBase,
      ),
    );
    canvas.translate(0, (1 - aparece) * alto);
    canvas.drawAtlas(
      kit.imagen,
      [c.transformacion()],
      [c.pieza.fuente],
      null,
      null,
      null,
      pintura,
    );
    canvas.restore();
    // Un destello en la base mientras sube.
    final destello = (1 - aparece);
    if (destello > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: base, width: 160, height: 80),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(base, 80, [
            PaletaNeotokyo.amarillo.withValues(alpha: 0.5 * destello),
            PaletaNeotokyo.amarillo.withValues(alpha: 0),
          ]),
      );
    }
  }

  /// El foco de la torre: sale de su punta y barre la ciudad, tumbado como
  /// todo lo demás.
  void _pintarFoco(Canvas canvas, double s) {
    final torre = _colocados.where((c) => c.edificio.numero == -1);
    if (torre.isEmpty) return;
    final t = torre.first;
    final cima = t.base - Offset(0, t.pieza.ancla.dy * t.escalaPx * 0.97);
    const largo = 900.0;
    final angulo = s * 0.35;
    final dir = Offset(math.cos(angulo), math.sin(angulo) * 0.5);
    final normal = Offset(-math.sin(angulo), math.cos(angulo) * 0.5);
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
          Color(0x2EFFE9F4),
          Color(0x00FFE9F4),
        ]),
    );
  }

  /// El nombre de la manzana de hoy, encima de su edificio más alto.
  void _pintarCartel(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaCiudad escena,
  ) {
    if (escena.cantidad == 0 || vista.escala < 0.45) return;
    final m = escena.colocador.manzana(escena.deLaUltima);
    var arriba = Iso.de(m.rect.center).dy;
    for (final c in _colocados) {
      if (c.edificio.manzana == m.numero &&
          c.edificio.numero < escena.cantidad) {
        arriba = math.min(arriba, c.base.dy - c.pieza.ancla.dy * c.escalaPx);
      }
    }
    final punto = vista.aPantalla(
      Offset(Iso.de(m.rect.center).dx, arriba),
      tamano,
    );
    PintorCiudadCodigo.pintarNombre(canvas, m.nombre, punto);
  }
}

/// Un edificio con su pieza del kit, ya puesto en la pantalla isométrica.
class _Colocado {
  _Colocado({
    required this.edificio,
    required this.pieza,
    required this.escala,
    required KitNeotokyo kit,
  }) : base = Iso.de(edificio.rect.center),
       escalaPx = escala * Iso.unidad / kit.pxPorUnidad,
       bajoBase =
           (edificio.rect.width + edificio.rect.height) / (4 * math.sqrt2) + 3,
       orden = edificio.rect.center.dx - edificio.rect.center.dy;

  final Edificio edificio;
  final PiezaKit pieza;

  /// Unidades de Blender de la ciudad por cada una del kit.
  final double escala;

  /// El centro de su base, en la pantalla isométrica.
  final Offset base;

  /// Unidades del mundo por cada píxel de la imagen.
  final double escalaPx;

  /// Lo que la huella baja por debajo de [base] (la esquina de delante).
  final double bajoBase;

  final double orden;

  RSTransform transformacion({bool volteado = false}) =>
      RSTransform.fromComponents(
        rotation: 0,
        scale: escalaPx,
        anchorX: pieza.ancla.dx,
        anchorY: pieza.ancla.dy,
        translateX: base.dx,
        translateY: volteado ? -base.dy : base.dy,
      );

  /// Si algo de él cae en [pantalla].
  bool cabeEn(Rect pantalla) {
    final izq = base.dx - pieza.ancla.dx * escalaPx;
    final der = izq + pieza.fuente.width * escalaPx;
    final arriba = base.dy - pieza.ancla.dy * escalaPx;
    // Con el reflejo, llega tan abajo como alto es.
    final abajo = base.dy + pieza.ancla.dy * escalaPx;
    return der >= pantalla.left &&
        izq <= pantalla.right &&
        abajo >= pantalla.top &&
        arriba <= pantalla.bottom;
  }
}
