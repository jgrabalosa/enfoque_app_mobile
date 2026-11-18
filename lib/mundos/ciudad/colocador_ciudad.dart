import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../azar.dart';
import 'nombres_barrios.dart';

/// Dónde va cada edificio de la ciudad de Neotokyo+
/// (`encargos/focus-mundos.md` §11). Solo números: no dibuja nada, y con la
/// misma [semilla] da siempre lo mismo.
///
/// - La ciudad es una cuadrícula de **celdas**. La del centro es la plaza
///   con la torre; las demás se ocupan en espiral cuadrada, hacia fuera.
/// - Cada celda es una **manzana** de [piezasPorManzana] edificios (uno por
///   sesión) o, cada 4 manzanas, un **hito**: parque, plaza, estación o
///   estadio.
/// - Entre celdas, calles; cada tres celdas, una avenida más ancha. Un río
///   cruza la ciudad y las manzanas lo esquivan.
/// - Cada manzana se parte en 10 parcelas de tamaños distintos, y en cada
///   una va un edificio. Más altos cuanto más cerca del centro.
///
/// Las unidades son del mundo, no píxeles.
class ColocadorCiudad {
  ColocadorCiudad(this.semilla)
    : rioVertical = azarMundo(semilla, 0, 1) < 0.5,
      rioFase = azarMundo(semilla, 0, 2) * 2 * math.pi,
      rioDesplazamiento =
          (azarMundo(semilla, 0, 3) < 0.5 ? -1 : 1) *
          (1.6 + azarMundo(semilla, 0, 4)) *
          pasoCelda;

  static const int piezasPorManzana = 10;

  /// Lo que mide una manzana (es cuadrada).
  static const double ladoManzana = 200;

  /// El ancho de una calle normal.
  static const double calle = 36;

  /// Lo que añade una avenida a una calle (cada tres celdas).
  static const double extraAvenida = 44;

  static const double pasoCelda = ladoManzana + calle;

  /// Una de cada [manzanasPorHito] + 1 celdas es un hito.
  static const int manzanasPorHito = 4;

  /// El ancho del río.
  static const double anchoRio = 150;

  final int semilla;

  /// Si el río baja de arriba abajo (si no, cruza de lado a lado).
  final bool rioVertical;
  final double rioFase;
  final double rioDesplazamiento;

  final List<(int, int)> _celdas = [];
  int _espiral = 0;
  final Map<int, Manzana> _manzanas = {};

  /// El centro de la celda (i, j) en el mundo. Las avenidas desplazan las
  /// celdas que tienen detrás.
  static Offset centroCelda(int i, int j) => Offset(_eje(i), _eje(j));

  static double _eje(int i) =>
      i * pasoCelda + _floorDiv(i + 1, 3) * extraAvenida;

  /// La celda (i, j) en el mundo.
  static Rect rectCelda(int i, int j) => Rect.fromCenter(
    center: centroCelda(i, j),
    width: ladoManzana,
    height: ladoManzana,
  );

  /// El centro del río en la coordenada [a] (x si cruza, y si baja).
  double rioEn(double a) =>
      rioDesplazamiento + 260 * math.sin(a / 900 + rioFase);

  /// Si el punto [p] cae en el agua.
  bool enElRio(Offset p, {double margen = 0}) {
    final (a, b) = rioVertical ? (p.dy, p.dx) : (p.dx, p.dy);
    return (b - rioEn(a)).abs() < anchoRio / 2 + margen;
  }

  bool _celdaEnElRio(int i, int j) {
    final r = rectCelda(i, j).inflate(14);
    for (var k = 0; k <= 8; k++) {
      final t = k / 8;
      // Recorre el lado que va a lo largo del río y mira si el río pasa por
      // dentro de la celda.
      if (rioVertical) {
        final y = r.top + r.height * t;
        final x = rioEn(y);
        if (x + anchoRio / 2 > r.left && x - anchoRio / 2 < r.right) {
          return true;
        }
      } else {
        final x = r.left + r.width * t;
        final y = rioEn(x);
        if (y + anchoRio / 2 > r.top && y - anchoRio / 2 < r.bottom) {
          return true;
        }
      }
    }
    return false;
  }

  /// La celda número [k] de las que se pueden ocupar (sin el centro ni el
  /// río), en espiral desde el centro.
  (int, int) celda(int k) {
    while (_celdas.length <= k) {
      _espiral++;
      final c = _espiralEn(_espiral);
      if (!_celdaEnElRio(c.$1, c.$2)) _celdas.add(c);
    }
    return _celdas[k];
  }

  /// La celda número [n] de una espiral cuadrada que empieza en (0, 0) y
  /// gira hacia fuera.
  static (int, int) _espiralEn(int n) {
    if (n == 0) return (0, 0);
    final capa = ((math.sqrt(n) + 1) / 2).floor();
    final lado = 2 * capa;
    final inicio = (2 * capa - 1) * (2 * capa - 1);
    final p = n - inicio;
    if (p < lado) return (capa, -capa + 1 + p);
    if (p < 2 * lado) return (capa - 1 - (p - lado), capa);
    if (p < 3 * lado) return (-capa, capa - 1 - (p - 2 * lado));
    return (-capa + 1 + (p - 3 * lado), -capa);
  }

  /// En qué número de celda va la manzana [m] (los hitos ocupan una de cada
  /// cinco).
  static int celdaDeManzana(int m) => m + m ~/ manzanasPorHito;

  /// En qué número de celda va el hito [h]: justo después de su cuarta
  /// manzana.
  static int celdaDeHito(int h) =>
      celdaDeManzana(h * manzanasPorHito + manzanasPorHito - 1) + 1;

  static int manzanaDe(int numero) => numero ~/ piezasPorManzana;

  /// La manzana [m], con sus parcelas. Se calcula una vez y se guarda.
  Manzana manzana(int m) => _manzanas.putIfAbsent(m, () => _calcular(m));

  /// El edificio de la pieza [numero] (desde 0).
  Edificio edificio(int numero) {
    final m = manzana(manzanaDe(numero));
    return m.edificios[numero % piezasPorManzana];
  }

  /// El hito [h].
  HitoCiudad hito(int h) {
    final (i, j) = celda(celdaDeHito(h));
    return HitoCiudad(
      numero: h,
      celda: (i, j),
      rect: rectCelda(i, j),
      tipo:
          TipoHitoCiudad.values[(azarMundo(semilla, h, 51) *
                  TipoHitoCiudad.values.length)
              .floor()],
      giro: azarMundo(semilla, h, 52),
    );
  }

  /// Los hitos que ya han salido con [manzanasCompletas].
  List<HitoCiudad> hitosCon(int manzanasCompletas) => [
    for (var h = 0; h < manzanasCompletas ~/ manzanasPorHito; h++) hito(h),
  ];

  Manzana _calcular(int m) {
    final (i, j) = celda(celdaDeManzana(m));
    final rect = rectCelda(i, j);
    final distancia = math.max(i.abs(), j.abs());
    // La acera: los edificios no tocan la calle.
    final parcelas = _partir(m, rect.deflate(8));
    // Se llena desde la esquina que mira al centro de la ciudad.
    final esquina = Offset(
      i > 0 ? rect.left : rect.right,
      j > 0 ? rect.top : rect.bottom,
    );
    parcelas.sort(
      (a, b) => (a.center - esquina).distance.compareTo(
        (b.center - esquina).distance,
      ),
    );
    final edificios = <Edificio>[];
    for (var k = 0; k < piezasPorManzana; k++) {
      final numero = m * piezasPorManzana + k;
      final cierra = k == piezasPorManzana - 1;
      // Más alto cuanto más cerca del centro: el skyline sale solo.
      final centro = math.exp(-distancia / 5);
      var altura =
          28 +
          (50 + 130 * centro) *
              math.pow(azarMundo(semilla, numero, 41), 1.4).toDouble();
      if (azarMundo(semilla, numero, 42) < 0.06 + 0.1 * centro) altura *= 1.6;
      if (cierra) altura = math.max(altura * 1.3, 90 + 60 * centro);
      edificios.add(
        Edificio(
          numero: numero,
          manzana: m,
          indice: k,
          rect: parcelas[k].deflate(4),
          altura: altura,
          neon: (azarMundo(semilla, numero, 43) * NeonCiudad.colores).floor(),
          tejado: cierra
              ? TejadoCiudad.cartel
              : TejadoCiudad.values[(azarMundo(semilla, numero, 44) *
                        (TejadoCiudad.values.length - 1))
                    .floor()],
        ),
      );
    }
    return Manzana(
      numero: m,
      celda: (i, j),
      rect: rect,
      edificios: edificios,
      nombre: NombresBarrios.de(semilla, m),
    );
  }

  /// Parte [rect] en 10 parcelas de tamaños distintos: cada vez se parte la
  /// más grande por su lado largo.
  List<Rect> _partir(int m, Rect rect) {
    final piezas = [rect];
    var sal = 300;
    while (piezas.length < piezasPorManzana) {
      piezas.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
      final r = piezas.removeAt(0);
      final t = 0.36 + azarMundo(semilla, m, sal++) * 0.28;
      if (r.width >= r.height) {
        final x = r.left + r.width * t;
        piezas
          ..add(Rect.fromLTRB(r.left, r.top, x, r.bottom))
          ..add(Rect.fromLTRB(x, r.top, r.right, r.bottom));
      } else {
        final y = r.top + r.height * t;
        piezas
          ..add(Rect.fromLTRB(r.left, r.top, r.right, y))
          ..add(Rect.fromLTRB(r.left, y, r.right, r.bottom));
      }
    }
    return piezas;
  }

  /// Lo lejos del centro que llega la ciudad con [manzanas] manzanas.
  double radioCon(int manzanas) {
    if (manzanas <= 0) return pasoCelda;
    var radio = pasoCelda;
    final ultima = celdaDeManzana(manzanas - 1);
    for (var k = 0; k <= ultima; k++) {
      final (i, j) = celda(k);
      radio = math.max(radio, centroCelda(i, j).distance + ladoManzana);
    }
    return radio;
  }

  static int _floorDiv(int a, int b) => (a / b).floor();
}

/// Una manzana: 10 edificios en 10 parcelas.
class Manzana {
  const Manzana({
    required this.numero,
    required this.celda,
    required this.rect,
    required this.edificios,
    required this.nombre,
  });

  final int numero;
  final (int, int) celda;
  final Rect rect;
  final List<Edificio> edificios;
  final String nombre;
}

/// Un edificio: la planta (en el suelo) y su altura.
class Edificio {
  const Edificio({
    required this.numero,
    required this.manzana,
    required this.indice,
    required this.rect,
    required this.altura,
    required this.neon,
    required this.tejado,
  });

  final int numero;
  final int manzana;

  /// Su sitio dentro de la manzana (0 a 9).
  final int indice;

  /// La planta, en el mundo.
  final Rect rect;

  /// Unidades del mundo, como la planta.
  final double altura;

  /// Cuál de los [NeonCiudad.colores] colores de neón lleva.
  final int neon;

  final TejadoCiudad tejado;

  /// El último de su manzana: la cierra, es más alto y lleva cartel.
  bool get cierra => indice == ColocadorCiudad.piezasPorManzana - 1;
}

/// Lo que hay en el tejado.
enum TejadoCiudad { liso, maquinas, helipuerto, antena, jardin, cartel }

/// Cuántos colores de neón hay. Los pinta el pintor; aquí solo se elige.
abstract final class NeonCiudad {
  static const int colores = 4;
}

enum TipoHitoCiudad { parque, plaza, estacion, estadio }

/// Una celda especial que sale cada 4 manzanas.
class HitoCiudad {
  const HitoCiudad({
    required this.numero,
    required this.celda,
    required this.rect,
    required this.tipo,
    required this.giro,
  });

  final int numero;
  final (int, int) celda;
  final Rect rect;
  final TipoHitoCiudad tipo;

  /// 0 a 1, para variar el dibujo.
  final double giro;
}
