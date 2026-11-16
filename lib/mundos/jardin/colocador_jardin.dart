import 'dart:math' as math;
import 'dart:ui' show Offset, Path, Rect;

import '../azar.dart';
import 'flores.dart';
import 'nombres_parterres.dart';
import 'paleta_dulce.dart';

/// Dónde va cada flor del jardín de Dulce (`encargos/focus-mundos.md` §12).
/// Solo números: no dibuja nada, y con la misma [semilla] da siempre lo
/// mismo.
///
/// - En el centro, un **árbol** grande. Alrededor, **huecos** colocados en
///   espiral de girasol (cada uno girado el ángulo áureo respecto al
///   anterior): el jardín, visto entero, también es una flor.
/// - Cada hueco es un **parterre** de [piezasPorParterre] flores (una por
///   sesión) o, cada 4 parterres, un **hito**: una fuente, una pérgola, un
///   banco bajo un árbol o un estanque con su puente.
/// - Dentro de cada parterre, las flores también van en espiral de girasol,
///   desde el centro: un parterre a medias se ve como un ramillete, no como
///   un hueco.
///
/// Las unidades son del mundo, no píxeles.
class ColocadorJardin {
  ColocadorJardin(this.semilla) : giro = azarMundo(semilla, 0, 1) * 2 * math.pi;

  static const int piezasPorParterre = 10;
  static const int parterresPorHito = 4;

  /// Lo que mide un parterre de radio (antes de su forma propia).
  static const double radioParterre = 125;

  /// Lo que mide una flor de radio (los pétalos; las hojas asoman más).
  static const double radioFlor = 34;

  /// El radio de la copa del árbol del centro.
  static const double radioArbol = 120;

  /// La separación de la espiral de huecos.
  static const double _paso = 215;
  static const double _inicio = 2.5;
  static const double _aureo = 2.399963229728653;

  final int semilla;
  final double giro;
  final Map<int, Parterre> _parterres = {};

  /// El centro del hueco [k].
  Offset centroHueco(int k) {
    final r = _paso * math.sqrt(k + _inicio);
    final a = giro + k * _aureo;
    return Offset(math.cos(a), math.sin(a)) * r;
  }

  static int huecoDeParterre(int m) => m + m ~/ parterresPorHito;

  static int huecoDeHito(int h) =>
      huecoDeParterre(h * parterresPorHito + parterresPorHito - 1) + 1;

  static int parterreDe(int numero) => numero ~/ piezasPorParterre;

  Parterre parterre(int m) => _parterres.putIfAbsent(m, () => _calcular(m));

  /// La flor de la pieza [numero] (desde 0).
  Flor flor(int numero) {
    final p = parterre(parterreDe(numero));
    return p.flores[numero % piezasPorParterre];
  }

  HitoJardin hito(int h) => HitoJardin(
    numero: h,
    centro: centroHueco(huecoDeHito(h)),
    tipo:
        TipoHitoJardin.values[(azarMundo(semilla, h, 51) *
                TipoHitoJardin.values.length)
            .floor()],
    giro: azarMundo(semilla, h, 52) * 2 * math.pi,
  );

  List<HitoJardin> hitosCon(int parterresCompletos) => [
    for (var h = 0; h < parterresCompletos ~/ parterresPorHito; h++) hito(h),
  ];

  /// Lo lejos del centro que llega el jardín con [parterres] parterres.
  double radioCon(int parterres) {
    if (parterres <= 0) return radioArbol + 40;
    final ultimo = huecoDeParterre(parterres - 1);
    return centroHueco(ultimo).distance + radioParterre * 1.3;
  }

  /// El hueco más cercano al [k] de los que ya había antes: por ahí llega
  /// su camino (al primero, desde el árbol).
  Offset? vecinoAnterior(int k) {
    Offset? mejor;
    var distancia = double.infinity;
    final c = centroHueco(k);
    for (var j = 0; j < k; j++) {
      final d = (centroHueco(j) - c).distance;
      if (d < distancia) {
        distancia = d;
        mejor = centroHueco(j);
      }
    }
    // Si el árbol queda más cerca, el camino sale del árbol.
    if (c.distance - radioArbol < distancia) return Offset.zero;
    return mejor;
  }

  Parterre _calcular(int m) {
    final centro = centroHueco(huecoDeParterre(m));
    final escala = 0.94 + azarMundo(semilla, m, 21) * 0.12;
    final a2 = 0.04 + azarMundo(semilla, m, 22) * 0.06;
    final a3 = azarMundo(semilla, m, 23) * 0.05;
    final f2 = azarMundo(semilla, m, 24) * 2 * math.pi;
    final f3 = azarMundo(semilla, m, 25) * 2 * math.pi;
    final radio = radioParterre * escala;
    double borde(double a) =>
        radio * (1 + a2 * math.sin(2 * a + f2) + a3 * math.sin(3 * a + f3));

    final forma = Path();
    for (var i = 0; i <= 72; i++) {
      final a = i / 72 * 2 * math.pi;
      final p = centro + Offset(math.cos(a), math.sin(a)) * borde(a);
      if (i == 0) {
        forma.moveTo(p.dx, p.dy);
      } else {
        forma.lineTo(p.dx, p.dy);
      }
    }
    forma.close();

    final flores = <Flor>[];
    final giroFlores = azarMundo(semilla, m, 26) * 2 * math.pi;
    for (var k = 0; k < piezasPorParterre; k++) {
      final numero = m * piezasPorParterre + k;
      final a = giroFlores + k * _aureo;
      final r = radio * 0.88 * math.sqrt((k + 1) / (piezasPorParterre + 0.5));
      final temblor = Offset(
        (azarMundo(semilla, numero, 31) - 0.5) * 8,
        (azarMundo(semilla, numero, 32) - 0.5) * 8,
      );
      final especie = _especie(numero);
      flores.add(
        Flor(
          numero: numero,
          parterre: m,
          indice: k,
          centro: centro + Offset(math.cos(a), math.sin(a)) * r + temblor,
          especie: especie,
          variante: (azarMundo(semilla, numero, 34) * Flor.variantes).floor(),
          color: _color(especie, numero),
          hojas: (azarMundo(semilla, numero, 36) * PaletaDulce.verdes.length)
              .floor(),
          giro: azarMundo(semilla, numero, 37) * 2 * math.pi,
          escala: 0.88 + azarMundo(semilla, numero, 38) * 0.24,
        ),
      );
    }
    return Parterre(
      numero: m,
      centro: centro,
      radio: radio,
      forma: forma,
      flores: flores,
      nombre: NombresParterres.de(semilla, m),
    );
  }

  EspecieFlor _especie(int numero) {
    final x = azarMundo(semilla, numero, 33);
    // La rosa y la margarita, las que más; la hortensia, la que menos.
    const pesos = [0.24, 0.2, 0.16, 0.26, 0.14];
    var acumulado = 0.0;
    for (var i = 0; i < pesos.length; i++) {
      acumulado += pesos[i];
      if (x < acumulado) return EspecieFlor.values[i];
    }
    return EspecieFlor.rosa;
  }

  int _color(EspecieFlor e, int numero) {
    final posibles = PaletaDulce.coloresDe[e]!;
    return posibles[(azarMundo(semilla, numero, 35) * posibles.length).floor()];
  }
}

/// Un parterre: su forma en el suelo y sus 10 flores.
class Parterre {
  const Parterre({
    required this.numero,
    required this.centro,
    required this.radio,
    required this.forma,
    required this.flores,
    required this.nombre,
  });

  final int numero;
  final Offset centro;
  final double radio;

  /// El borde del parterre, en el mundo.
  final Path forma;
  final List<Flor> flores;
  final String nombre;

  Rect get caja => forma.getBounds().inflate(ColocadorJardin.radioFlor * 1.6);
}

/// Una flor: qué es, dónde va y de qué color.
class Flor {
  const Flor({
    required this.numero,
    required this.parterre,
    required this.indice,
    required this.centro,
    required this.especie,
    required this.variante,
    required this.color,
    required this.hojas,
    required this.giro,
    required this.escala,
  });

  /// Cuántos dibujos distintos hay de cada especie.
  static const int variantes = 3;

  final int numero;
  final int parterre;
  final int indice;
  final Offset centro;
  final EspecieFlor especie;
  final int variante;

  /// Cuál de [PaletaDulce.lapices] lleva en los pétalos.
  final int color;

  /// Cuál de [PaletaDulce.verdes] lleva en las hojas.
  final int hojas;
  final double giro;
  final double escala;
}

enum TipoHitoJardin { fuente, pergola, banco, estanque }

/// Lo que sale cada 4 parterres completos.
class HitoJardin {
  const HitoJardin({
    required this.numero,
    required this.centro,
    required this.tipo,
    required this.giro,
  });

  final int numero;
  final Offset centro;
  final TipoHitoJardin tipo;
  final double giro;
}
