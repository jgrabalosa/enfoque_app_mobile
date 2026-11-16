import 'dart:ui';

import '../escena_mundo.dart';
import 'colocador_ciudad.dart';

/// Todo lo que hay que dibujar de una ciudad con [cantidad] piezas, ya
/// colocado. Se rehace solo cuando cambian las piezas o la semilla.
class EscenaCiudad implements EscenaMundo {
  EscenaCiudad(this.colocador, this.cantidad)
    : edificios = [for (var n = 0; n < cantidad; n++) colocador.edificio(n)] {
    hitos = colocador.hitosCon(completas);
    final celdas = <(int, int)>{(0, 0)};
    for (var m = 0; m < manzanasConEdificios; m++) {
      celdas.add(colocador.manzana(m).celda);
    }
    for (final h in hitos) {
      celdas.add(h.celda);
    }
    ocupadas = celdas;
    calles = _calles(celdas);
  }

  final ColocadorCiudad colocador;
  @override
  final int cantidad;
  final List<Edificio> edificios;
  late final List<HitoCiudad> hitos;

  /// Las celdas con algo: la plaza del centro, las manzanas con algún
  /// edificio y los hitos.
  late final Set<(int, int)> ocupadas;

  /// Los tramos de calle alrededor de lo ocupado (de un cruce al siguiente),
  /// por donde circulan los coches.
  late final List<(Offset, Offset)> calles;

  static const int _porManzana = ColocadorCiudad.piezasPorManzana;

  int get manzanasConEdificios =>
      cantidad == 0 ? 0 : ColocadorCiudad.manzanaDe(cantidad - 1) + 1;

  @override
  int get piezasPorRegion => _porManzana;

  @override
  int get completas => cantidad ~/ _porManzana;

  @override
  int get deLaUltima =>
      cantidad == 0 ? 0 : ColocadorCiudad.manzanaDe(cantidad - 1);

  @override
  int get enLaUltima => cantidad == 0 ? 0 : (cantidad - 1) % _porManzana + 1;

  @override
  String nombreRegion(int region) => colocador.manzana(region).nombre;

  @override
  Offset centroRegion(int region) => colocador.manzana(region).rect.center;

  @override
  double get ladoRegion => ColocadorCiudad.pasoCelda;

  @override
  double get radio => colocador.radioCon(deLaUltima + 1);

  /// Las calles alrededor de cada celda ocupada: los cuatro lados, por el
  /// centro de la calle. Sin repetir los que comparten dos celdas.
  static List<(Offset, Offset)> _calles(Set<(int, int)> celdas) {
    final vistos = <String>{};
    final tramos = <(Offset, Offset)>[];
    void anadir(Offset a, Offset b) {
      final clave =
          '${a.dx.round()},${a.dy.round()},${b.dx.round()},${b.dy.round()}';
      if (vistos.add(clave)) tramos.add((a, b));
    }

    for (final (i, j) in celdas) {
      // A medio camino entre esta celda y la de al lado: el centro de la
      // calle, aunque sea avenida.
      final c = ColocadorCiudad.centroCelda(i, j);
      final izq = (ColocadorCiudad.centroCelda(i - 1, j).dx + c.dx) / 2;
      final der = (ColocadorCiudad.centroCelda(i + 1, j).dx + c.dx) / 2;
      final arr = (ColocadorCiudad.centroCelda(i, j - 1).dy + c.dy) / 2;
      final aba = (ColocadorCiudad.centroCelda(i, j + 1).dy + c.dy) / 2;
      anadir(Offset(izq, arr), Offset(der, arr));
      anadir(Offset(izq, aba), Offset(der, aba));
      anadir(Offset(izq, arr), Offset(izq, aba));
      anadir(Offset(der, arr), Offset(der, aba));
    }
    return tramos;
  }
}

/// Una forma de dibujar la ciudad.
typedef PintorCiudad = PintorMundo<EscenaCiudad>;
