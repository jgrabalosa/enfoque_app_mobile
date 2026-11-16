import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

import '../azar.dart';
import '../ciudad/ciudad_isometrica.dart' show Iso;
import '../vista_mundo.dart';
import 'colocador_jardin.dart';
import 'escena_jardin.dart';
import 'pintor_jardin.dart' show PintorJardin;

/// «Dulce 3D»: el jardín de Dulce en isométrico, con plantas modeladas en
/// Blender y pasadas a lápiz de color (`tool/mundos/kit_jardin.py`), la
/// misma receta que Neotokyo+ 3D.
///
/// La colocación es la de [ColocadorJardin] (parterres en espiral de girasol
/// desde el árbol, un hito cada 4, caminos); aquí solo cambia cómo se ve.
/// Una unidad de Blender son [JardinIso.unidad] unidades del mundo: el
/// parterre de Blender mide 1,1 de radio, el del colocador, 125.
abstract final class JardinIso {
  static const double radioBlender = 1.1;
  static const double unidad = ColocadorJardin.radioParterre / radioBlender;

  /// Las especies del kit y lo altas que son (para ponerlas detrás).
  static const Map<String, double> alturas = {
    'girasol': 1.0,
    'tulipanes': 0.55,
    'lavanda': 0.5,
    'amapolas': 0.45,
    'rosal': 0.42,
    'hortensia': 0.38,
    'margaritas': 0.3,
  };

  static const int variantes = 4;
}

/// La escena del jardín vista en isométrico: las mismas piezas; las
/// regiones, donde caen en la pantalla.
class EscenaJardinIso extends EscenaJardin {
  EscenaJardinIso(super.colocador, super.cantidad);

  /// El parterre sube en la pantalla con sus plantas: el centro de la vista
  /// se pone algo por encima del suelo.
  @override
  Offset centroRegion(int region) =>
      Iso.de(colocador.parterre(region).centro) -
      const Offset(0, 0.45 * JardinIso.unidad);

  @override
  double get ladoRegion => ColocadorJardin.radioParterre * 1.55;
}

/// Una pieza del kit: dónde está en el atlas y dónde cae su base.
class PiezaJardin {
  const PiezaJardin({
    required this.nombre,
    required this.tipo,
    required this.boceto,
    required this.fuente,
    required this.ancla,
    required this.pxPorUnidad,
    this.especie,
    this.variante = 0,
    this.hito,
  });

  final String nombre;
  final String tipo;
  final bool boceto;
  final Rect fuente;
  final Offset ancla;
  final double pxPorUnidad;
  final String? especie;
  final int variante;
  final String? hito;
}

/// El kit del jardín: un atlas con todas las piezas a lápiz.
class KitJardin {
  KitJardin._(this.imagen, List<PiezaJardin> piezas) {
    for (final p in piezas) {
      _porClave[(p.nombre, p.boceto)] = p;
    }
  }

  static const String ruta = 'assets/mundos/dulce/jardin';

  final ui.Image imagen;
  final Map<(String, bool), PiezaJardin> _porClave = {};

  static Future<KitJardin> cargar() async {
    final json =
        jsonDecode(await rootBundle.loadString('$ruta.json'))
            as Map<String, dynamic>;
    final datos = await rootBundle.load('$ruta.webp');
    final codec = await ui.instantiateImageCodec(datos.buffer.asUint8List());
    final imagen = (await codec.getNextFrame()).image;
    codec.dispose();
    return KitJardin._(imagen, [
      for (final e in json['piezas'] as List)
        PiezaJardin(
          nombre: e['nombre'] as String,
          tipo: e['tipo'] as String,
          boceto: e['version'] == 'boceto',
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
          pxPorUnidad: (e['px_por_unidad'] as num).toDouble(),
          especie: e['especie'] as String?,
          variante: (e['variante'] as num?)?.toInt() ?? 0,
          hito: e['hito'] as String?,
        ),
    ]);
  }

  PiezaJardin pieza(String nombre, {bool boceto = false}) =>
      _porClave[(nombre, boceto)] ?? _porClave[(nombre, false)]!;

  bool tiene(String nombre) => _porClave.containsKey((nombre, false));

  void liberar() => imagen.dispose();
}

/// Una planta de un parterre: su especie, su dibujo y su sitio.
class PlantaJardin {
  const PlantaJardin({
    required this.numero,
    required this.parterre,
    required this.suelo,
    required this.especie,
    required this.variante,
    required this.escala,
  });

  final int numero;
  final int parterre;

  /// Dónde está, en el suelo (unidades del mundo).
  final Offset suelo;
  final String especie;
  final int variante;
  final double escala;
}

/// Coloca las plantas de cada parterre como lo haría un jardinero: diez
/// sitios en espiral de girasol, y las especies altas en los sitios de atrás
/// para que se vean todas. La planta n.º k de un parterre ocupa el sitio k
/// (de dentro afuera), así que un parterre a medias es un ramillete.
class PlantasJardin {
  PlantasJardin(this.colocador);

  final ColocadorJardin colocador;
  final Map<int, List<PlantaJardin>> _porParterre = {};

  static const double _aureo = 2.399963229728653;
  static const List<String> _especies = [
    'tulipanes',
    'margaritas',
    'lavanda',
    'rosal',
    'hortensia',
    'girasol',
    'amapolas',
  ];

  List<PlantaJardin> de(int m) => _porParterre.putIfAbsent(m, () {
    final s = colocador.semilla;
    final p = colocador.parterre(m);
    final giro = azarMundo(s, m, 71) * 2 * math.pi;
    // Los diez sitios, en unidades de Blender, con su número de orden.
    final sitios = <(Offset, int)>[
      for (var k = 0; k < ColocadorJardin.piezasPorParterre; k++)
        (
          Offset.fromDirection(
            k * _aureo + giro,
            0.8 * math.sqrt((k + 0.6) / 10.3),
          ),
          k,
        ),
    ]..sort((a, b) => (a.$1.dx - a.$1.dy).compareTo(b.$1.dx - b.$1.dy));
    // Las especies: las siete, más tres al azar (sin repetir el girasol).
    final sinGirasol = _especies.where((e) => e != 'girasol').toList();
    final especies = <(String, double)>[
      for (final (i, e) in _especies.indexed)
        (e, -JardinIso.alturas[e]! + azarMundo(s, m * 10 + i, 72) * 0.05),
      for (var i = 0; i < 3; i++)
        () {
          final e =
              sinGirasol[(azarMundo(s, m * 10 + i, 73) * sinGirasol.length)
                  .floor()];
          return (
            e,
            -JardinIso.alturas[e]! + azarMundo(s, m * 10 + i, 74) * 0.05,
          );
        }(),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final plantas = List<PlantaJardin?>.filled(
      ColocadorJardin.piezasPorParterre,
      null,
    );
    for (var i = 0; i < sitios.length; i++) {
      final (sitio, k) = sitios[i];
      final especie = especies[i].$1;
      final numero = m * ColocadorJardin.piezasPorParterre + k;
      plantas[k] = PlantaJardin(
        numero: numero,
        parterre: m,
        suelo: p.centro + sitio * JardinIso.unidad,
        especie: especie,
        variante: (azarMundo(s, numero, 81) * JardinIso.variantes).floor(),
        escala: 0.92 + azarMundo(s, numero, 82) * 0.16,
      );
    }
    return [for (final p in plantas) p!];
  });

  PlantaJardin planta(int numero) {
    final m = ColocadorJardin.parterreDe(numero);
    return de(m)[numero % ColocadorJardin.piezasPorParterre];
  }
}

/// Dulce en isométrico, a lápiz: el papel, manchas de césped bajo cada
/// parterre, losas por los caminos, los parterres y, de atrás adelante, las
/// plantas, el árbol y los hitos. El parterre que se está llenando va en
/// boceto (a grafito) y se colorea al completarse.
class PintorJardin3D extends PintorJardin {
  @override
  String get nombre => 'Lápiz 3D';

  KitJardin? _kit;
  FragmentShader? _papel;
  String? _fallo;

  @override
  String? get aviso => _fallo ?? (_papel == null ? 'sin papel' : null);

  EscenaJardin? _escena;
  PlantasJardin? _plantas;

  @override
  Future<void> preparar() async {
    if (_kit != null) return;
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.caveat(fontWeight: FontWeight.w600),
      ]);
    } catch (e) {
      debugPrint('Jardín sin la letra a mano: $e');
    }
    try {
      _kit = await KitJardin.cargar();
    } catch (e) {
      _fallo = 'sin kit';
      debugPrint('Dulce 3D sin kit: $e');
    }
    try {
      _papel = (await FragmentProgram.fromAsset(
        'shaders/papel.frag',
      )).fragmentShader();
    } catch (e) {
      debugPrint('Dulce 3D sin papel: $e');
    }
  }

  @override
  void liberar() {
    _kit?.liberar();
    _kit = null;
    _papel?.dispose();
    _papel = null;
    _escena = null;
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
    _pintarPapel(canvas, tamano, vista, escena);
    final kit = _kit;
    if (kit == null) return;
    if (!identical(escena, _escena)) {
      _escena = escena;
      _plantas = PlantasJardin(escena.colocador);
    }
    final plantas = _plantas!;

    canvas.save();
    canvas.translate(tamano.width / 2, tamano.height / 2);
    canvas.scale(vista.escala);
    canvas.translate(-vista.centro.dx, -vista.centro.dy);
    final pantalla = vista.visible(tamano, margen: 60);
    final semilla = escena.colocador.semilla;

    final completaAhora =
        nueva != null &&
            nueva % ColocadorJardin.piezasPorParterre ==
                ColocadorJardin.piezasPorParterre - 1
        ? ColocadorJardin.parterreDe(nueva)
        : null;
    final colorAhora = _facil(aparicion);

    final suelo = _Tanda(kit);
    final cosas = <_Dibujo>[];

    // El césped y los parterres (lo plano), y lo que se levanta.
    void cesped(Offset centro, int v, double escala) =>
        suelo.poner(kit.pieza('cesped_$v'), Iso.de(centro), escala, 1);

    cesped(Offset.zero, 1, 1.6);
    cosas.add(_Dibujo(kit.pieza('arbol_0'), Offset.zero, 1.35, 1));
    for (final h in escena.hitos) {
      cesped(h.centro, h.numero % 3, 1.4);
      cosas.add(_Dibujo(kit.pieza('hito_${h.tipo.name}'), h.centro, 1.0, 1));
    }
    for (var m = 0; m < escena.parterresConFlores; m++) {
      final p = escena.colocador.parterre(m);
      cesped(p.centro, (m + 1) % 3, 1.4);
    }
    // Las losas de los caminos, entre bordes.
    for (final (a, b) in escena.caminos) {
      _losas(suelo, kit, a, b, semilla);
    }
    // Los parterres: en boceto hasta que están completos.
    final planos = _Tanda(kit);
    for (var m = 0; m < escena.parterresConFlores; m++) {
      final p = escena.colocador.parterre(m);
      final base = Iso.de(p.centro);
      final v = m % 3;
      if (m == completaAhora && colorAhora < 1) {
        planos.poner(kit.pieza('parterre_$v', boceto: true), base, 1, 1);
        planos.poner(kit.pieza('parterre_$v'), base, 1, colorAhora);
      } else {
        planos.poner(
          kit.pieza('parterre_$v', boceto: !escena.completo(m)),
          base,
          1,
          1,
        );
      }
    }
    // Las plantas.
    for (var n = 0; n < escena.cantidad; n++) {
      final pl = plantas.planta(n);
      final nombre = 'planta_${pl.especie}_${pl.variante}';
      final completo = escena.completo(pl.parterre);
      var crece = 1.0;
      var alfa = 1.0;
      if (n == nueva && aparicion < 1) {
        crece = 0.3 + 0.7 * _facil(aparicion);
        alfa = math.min(1, aparicion * 2.5);
      }
      if (pl.parterre == completaAhora && colorAhora < 1) {
        cosas.add(
          _Dibujo(
            kit.pieza(nombre, boceto: true),
            pl.suelo,
            pl.escala * crece,
            alfa,
          ),
        );
        cosas.add(
          _Dibujo(kit.pieza(nombre), pl.suelo, pl.escala * crece, colorAhora),
        );
      } else {
        cosas.add(
          _Dibujo(
            kit.pieza(nombre, boceto: !completo),
            pl.suelo,
            pl.escala * crece,
            alfa,
          ),
        );
      }
    }

    suelo.pintar(canvas, pantalla);
    planos.pintar(canvas, pantalla);
    // De atrás adelante: en esta cámara, de menor a mayor x − y.
    cosas.sort((a, b) => a.orden.compareTo(b.orden));
    final delante = _Tanda(kit);
    for (final c in cosas) {
      delante.poner(c.pieza, Iso.de(c.suelo), c.escala, c.alfa);
    }
    delante.pintar(canvas, pantalla);
    canvas.restore();

    _pintarNombre(canvas, tamano, vista, escena);
  }

  void _losas(_Tanda t, KitJardin kit, Offset a, Offset b, int semilla) {
    final d = b - a;
    final largo = d.distance;
    if (largo == 0) return;
    final u = d / largo;
    final desde = a == Offset.zero
        ? ColocadorJardin.radioArbol * 0.9
        : ColocadorJardin.radioParterre * 1.05;
    final hasta = largo - ColocadorJardin.radioParterre * 1.05;
    final paso = 0.32 * JardinIso.unidad;
    var k = 0;
    for (var s = desde + paso / 2; s < hasta; s += paso) {
      final n = Offset(-u.dy, u.dx);
      final temblor =
          n * ((azarMundo(semilla, (a.dx + s).round(), 91) - 0.5) * 8);
      t.poner(kit.pieza('losa_${k % 3}'), Iso.de(a + u * s + temblor), 1, 1);
      k++;
    }
  }

  /// El nombre del parterre de hoy, escrito a mano a lápiz, delante.
  void _pintarNombre(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaJardin escena,
  ) {
    if (escena.cantidad == 0 || vista.escala < 0.35) return;
    final p = escena.colocador.parterre(escena.deLaUltima);
    final abajo =
        Iso.de(p.centro) +
        Offset(0, JardinIso.radioBlender * 0.7 * JardinIso.unidad);
    final punto = vista.aPantalla(abajo, tamano);
    final texto = TextPainter(
      text: TextSpan(
        text: p.nombre,
        style: GoogleFonts.caveat(
          textStyle: const TextStyle(
            color: Color(0xD95A5560),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texto.paint(canvas, punto + Offset(-texto.width / 2, 6));
    texto.dispose();
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
      canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFCF5));
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

  static double _facil(double t) {
    final x = 1 - t.clamp(0.0, 1.0);
    return 1 - x * x * x;
  }
}

/// Algo que se levanta del suelo (planta, árbol, hito), para ordenarlo.
class _Dibujo {
  _Dibujo(this.pieza, this.suelo, this.escala, this.alfa)
    : orden = suelo.dx - suelo.dy;

  final PiezaJardin pieza;
  final Offset suelo;
  final double escala;
  final double alfa;
  final double orden;
}

/// Una tanda de piezas del atlas que se pintan en una sola llamada.
class _Tanda {
  _Tanda(this.kit);

  final KitJardin kit;
  final List<RSTransform> _tr = [];
  final List<Rect> _rects = [];
  final List<Color> _colores = [];
  final List<Rect> _cajas = [];

  void poner(PiezaJardin p, Offset base, double escala, double alfa) {
    if (alfa <= 0) return;
    final s = escala * JardinIso.unidad / p.pxPorUnidad;
    _tr.add(
      RSTransform.fromComponents(
        rotation: 0,
        scale: s,
        anchorX: p.ancla.dx,
        anchorY: p.ancla.dy,
        translateX: base.dx,
        translateY: base.dy,
      ),
    );
    _rects.add(p.fuente);
    _colores.add(Color.fromRGBO(255, 255, 255, alfa.clamp(0.0, 1.0)));
    _cajas.add(
      Rect.fromLTWH(
        base.dx - p.ancla.dx * s,
        base.dy - p.ancla.dy * s,
        p.fuente.width * s,
        p.fuente.height * s,
      ),
    );
  }

  void pintar(Canvas canvas, Rect pantalla) {
    final tr = <RSTransform>[];
    final re = <Rect>[];
    final co = <Color>[];
    for (var i = 0; i < _tr.length; i++) {
      if (!_cajas[i].overlaps(pantalla)) continue;
      tr.add(_tr[i]);
      re.add(_rects[i]);
      co.add(_colores[i]);
    }
    if (tr.isEmpty) return;
    canvas.drawAtlas(
      kit.imagen,
      tr,
      re,
      co,
      BlendMode.modulate,
      null,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}
