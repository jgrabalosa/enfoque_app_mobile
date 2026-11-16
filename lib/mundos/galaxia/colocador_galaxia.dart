import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../azar.dart';
import 'nombres_constelaciones.dart';

/// Dónde va cada estrella de la galaxia de Profundidad
/// (`encargos/focus-mundos.md` §2 y §3).
///
/// Solo números: no dibuja nada. Con la misma [semilla] y el mismo número de
/// pieza da siempre el mismo sitio, así que las posiciones no se guardan en
/// ninguna parte: se calculan.
///
/// - Cada [piezasPorConstelacion] piezas forman una constelación.
/// - Las constelaciones van una detrás de otra por los [brazos] de una espiral
///   logarítmica, repartidas entre ellos por turnos (0, 1, 2, 0, 1…), y
///   siempre hacia fuera: lo nuevo aparece en el borde.
/// - Cada constelación es una figura de 10 estrellas (un trazo con una rama)
///   que sale de la semilla.
///
/// Las unidades son del mundo, no píxeles: la cámara decide la escala.
class ColocadorGalaxia {
  ColocadorGalaxia(this.semilla)
    : giroBrazos = 1.55 + _azar(semilla, 0, 1) * 0.35,
      giroInicial = _azar(semilla, 0, 2) * 2 * math.pi;

  static const int piezasPorConstelacion = 10;
  static const int brazos = 3;

  /// Dónde empiezan los brazos: dentro de este radio está el núcleo.
  static const double radioInicial = 260;

  /// Cuánto se aleja del centro cada constelación nueva de un mismo brazo.
  static const double pasoRadial = 105;

  /// Cuántas constelaciones salen entre dos hitos (nebulosas y cúmulos).
  static const int constelacionesPorHito = 4;

  final int semilla;

  /// Cuánto se enrollan los brazos (de la espiral `θ = giro · ln(r / r0)`).
  final double giroBrazos;

  /// El ángulo del primer brazo: gira la galaxia entera.
  final double giroInicial;

  final Map<int, Constelacion> _constelaciones = {};

  /// La constelación a la que va la pieza [numero].
  static int constelacionDe(int numero) => numero ~/ piezasPorConstelacion;

  /// El sitio de la pieza [numero] (desde 0).
  EstrellaColocada estrella(int numero) {
    assert(numero >= 0);
    final c = constelacion(constelacionDe(numero));
    final i = numero % piezasPorConstelacion;
    final unidaA = c.unionDe(i);
    return EstrellaColocada(
      numero: numero,
      constelacion: c.numero,
      indice: i,
      posicion: c.centro + c.figura[i],
      unidaA: unidaA == null ? null : c.numero * piezasPorConstelacion + unidaA,
      escala: 0.8 + _azar(semilla, numero, 11) * 0.45,
      giro: _azar(semilla, numero, 12) * 2 * math.pi,
      variante: (_azar(semilla, numero, 13) * VariantesEstrella.normales)
          .floor(),
    );
  }

  /// La constelación [numero] (desde 0), con su figura. Se calcula una vez y
  /// se guarda.
  Constelacion constelacion(int numero) =>
      _constelaciones.putIfAbsent(numero, () => _calcular(numero));

  /// El radio de la galaxia con [constelaciones] constelaciones, contando el
  /// tamaño de la última figura.
  double radioCon(int constelaciones) {
    if (constelaciones <= 0) return radioInicial;
    final vuelta = (constelaciones - 1) ~/ brazos;
    return radioInicial + vuelta * pasoRadial + 140;
  }

  /// Los hitos que ya han salido con [constelacionesCompletas]: uno cada
  /// [constelacionesPorHito], junto a la constelación que lo trae.
  List<Hito> hitosCon(int constelacionesCompletas) => [
    for (
      var c = constelacionesPorHito - 1;
      c < constelacionesCompletas;
      c += constelacionesPorHito
    )
      _hito(c),
  ];

  Hito _hito(int c) {
    final con = constelacion(c);
    // Hacia fuera del brazo, para que no tape la figura.
    final fuera = con.centro / con.centro.distance;
    final lado = _azar(semilla, c, 21) < 0.5 ? -1.0 : 1.0;
    final perpendicular = Offset(-fuera.dy, fuera.dx) * lado;
    return Hito(
      constelacion: c,
      centro: con.centro + fuera * 110 + perpendicular * 70,
      radio: 170 + _azar(semilla, c, 22) * 110,
      variante: (_azar(semilla, c, 23) * Hito.variantes).floor(),
      giro: _azar(semilla, c, 24) * 2 * math.pi,
    );
  }

  Constelacion _calcular(int numero) {
    final brazo = numero % brazos;
    final vuelta = numero ~/ brazos;
    // Un poco de juego en el radio y en el ángulo, para que no parezcan
    // cuentas en un hilo.
    final r =
        radioInicial +
        vuelta * pasoRadial +
        (_azar(semilla, numero, 1) - 0.5) * pasoRadial * 0.3;
    final angulo =
        giroInicial +
        brazo * 2 * math.pi / brazos +
        giroBrazos * math.log(r / radioInicial) +
        (_azar(semilla, numero, 2) - 0.5) * 50 / r;
    final centro = Offset(r * math.cos(angulo), r * math.sin(angulo));
    // La dirección del brazo en ese punto: la figura se tumba a lo largo.
    final tangente = angulo + math.atan(giroBrazos);
    final figura = _figura(numero, tangente);
    return Constelacion(
      numero: numero,
      brazo: brazo,
      centro: centro,
      figura: figura,
      rama: _rama(numero),
      nombre: NombresConstelaciones.de(semilla, numero),
    );
  }

  /// Desde qué estrella sale la rama (las 3 últimas cuelgan de ella).
  int _rama(int numero) => 2 + (_azar(semilla, numero, 3) * 3).floor();

  /// Una figura de 10 estrellas: un trazo de 7 que gira poco a poco y una
  /// rama de 3 que sale de [_rama]. Centrada en su centro de masas, sin dos
  /// estrellas pegadas y sin pasar de [radioFigura].
  List<Offset> _figura(int numero, double angulo) {
    final puntos = <Offset>[];
    var dir = angulo + (_azar(semilla, numero, 4) - 0.5) * 1.2;
    var p = Offset.zero;
    var sal = 100;
    for (var i = 0; i < piezasPorConstelacion; i++) {
      if (i == 7) {
        // La rama: vuelve a la estrella de [_rama] y sale hacia un lado.
        p = puntos[_rama(numero)];
        dir += (_azar(semilla, numero, 5) < 0.5 ? -1 : 1) * 1.4;
      }
      if (i > 0) {
        final paso = 22 + _azar(semilla, numero, sal++) * 12;
        final giro = (_azar(semilla, numero, sal++) - 0.5) * 1.3;
        // Si cae encima de otra, prueba a torcer más, a un lado y al otro.
        var elegido =
            p + Offset(math.cos(dir + giro), math.sin(dir + giro)) * paso;
        for (var intento = 1; intento <= 8; intento++) {
          if (puntos.every((q) => (q - elegido).distance >= _separacion)) {
            break;
          }
          final extra = (intento.isOdd ? 1 : -1) * ((intento + 1) ~/ 2) * 0.55;
          final d = dir + giro + extra;
          elegido = p + Offset(math.cos(d), math.sin(d)) * paso;
        }
        dir = math.atan2(elegido.dy - p.dy, elegido.dx - p.dx);
        p = elegido;
      }
      puntos.add(p);
    }
    final centro =
        puntos.fold(Offset.zero, (a, b) => a + b) / puntos.length.toDouble();
    final centrados = [for (final q in puntos) q - centro];
    final lejos = centrados.map((q) => q.distance).reduce(math.max);
    if (lejos <= radioFigura) return centrados;
    return [for (final q in centrados) q * (radioFigura / lejos)];
  }

  /// Lo más que se aleja una estrella del centro de su constelación: así no
  /// se mete en la de al lado.
  static const double radioFigura = 62;

  /// Lo mínimo entre dos estrellas de una misma figura, antes de encogerla.
  static const double _separacion = 20;
}

/// Una constelación: 10 estrellas en una figura, en un brazo.
class Constelacion {
  const Constelacion({
    required this.numero,
    required this.brazo,
    required this.centro,
    required this.figura,
    required this.rama,
    required this.nombre,
  });

  final int numero;
  final int brazo;

  /// Su sitio en el mundo.
  final Offset centro;

  /// Dónde va cada una de sus 10 estrellas, respecto a [centro].
  final List<Offset> figura;

  /// La estrella de la que sale la rama.
  final int rama;

  final String nombre;

  /// Con qué estrella se une por una línea la estrella [indice] de la figura,
  /// o `null` si es la primera.
  int? unionDe(int indice) {
    if (indice == 0) return null;
    if (indice == 7) return rama;
    return indice - 1;
  }
}

/// Una estrella ya colocada.
class EstrellaColocada {
  const EstrellaColocada({
    required this.numero,
    required this.constelacion,
    required this.indice,
    required this.posicion,
    required this.unidaA,
    required this.escala,
    required this.giro,
    required this.variante,
  });

  final int numero;
  final int constelacion;

  /// Su sitio dentro de la constelación (0 a 9).
  final int indice;

  final Offset posicion;

  /// El número de la estrella con la que se une por una línea, o `null`.
  final int? unidaA;

  /// Variación de tamaño (alrededor de 1) y de giro, para que no se repitan.
  final double escala;
  final double giro;

  /// Cuál de las [VariantesEstrella.normales] estrellas normales es.
  final int variante;

  /// La última de su constelación: la cierra y brilla más.
  bool get cierra => indice == ColocadorGalaxia.piezasPorConstelacion - 1;
}

/// Una nebulosa o un cúmulo que sale cada pocas constelaciones y da forma a
/// la galaxia vista de lejos.
class Hito {
  const Hito({
    required this.constelacion,
    required this.centro,
    required this.radio,
    required this.variante,
    required this.giro,
  });

  static const int variantes = 4;

  final int constelacion;
  final Offset centro;
  final double radio;
  final int variante;
  final double giro;
}

/// Cuántas estrellas distintas hay. Las dibuja el pintor; aquí solo se elige.
abstract final class VariantesEstrella {
  static const int normales = 6;
}

double _azar(int semilla, int numero, int sal) =>
    azarMundo(semilla, numero, sal);

/// Lo mismo, para quien elige nombres.
double azarGalaxia(int semilla, int numero, int sal) =>
    _azar(semilla, numero, sal);
