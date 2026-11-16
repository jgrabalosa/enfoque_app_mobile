import 'dart:ui';

import '../escena_mundo.dart';
import 'colocador_jardin.dart';

/// Todo lo que hay que dibujar de un jardín con [cantidad] piezas, ya
/// colocado. Se rehace solo cuando cambian las piezas o la semilla.
class EscenaJardin implements EscenaMundo {
  EscenaJardin(this.colocador, this.cantidad)
    : flores = [for (var n = 0; n < cantidad; n++) colocador.flor(n)] {
    hitos = colocador.hitosCon(completas);
    final huecos = <int>[
      for (var m = 0; m < parterresConFlores; m++)
        ColocadorJardin.huecoDeParterre(m),
      for (final h in hitos) ColocadorJardin.huecoDeHito(h.numero),
    ]..sort();
    caminos = [
      for (final k in huecos)
        (colocador.vecinoAnterior(k) ?? Offset.zero, colocador.centroHueco(k)),
    ];
  }

  final ColocadorJardin colocador;
  @override
  final int cantidad;
  final List<Flor> flores;
  late final List<HitoJardin> hitos;

  /// Los caminos de grava: de cada parterre u hito al más cercano de los
  /// que ya estaban (al primero, desde el árbol).
  late final List<(Offset, Offset)> caminos;

  static const int _porParterre = ColocadorJardin.piezasPorParterre;

  int get parterresConFlores =>
      cantidad == 0 ? 0 : ColocadorJardin.parterreDe(cantidad - 1) + 1;

  /// Si el parterre [m] ya tiene sus 10 flores: entonces se colorea.
  bool completo(int m) => m < completas;

  @override
  int get piezasPorRegion => _porParterre;

  @override
  int get completas => cantidad ~/ _porParterre;

  @override
  int get deLaUltima =>
      cantidad == 0 ? 0 : ColocadorJardin.parterreDe(cantidad - 1);

  @override
  int get enLaUltima => cantidad == 0 ? 0 : (cantidad - 1) % _porParterre + 1;

  @override
  String nombreRegion(int region) => colocador.parterre(region).nombre;

  @override
  Offset centroRegion(int region) => colocador.parterre(region).centro;

  @override
  double get ladoRegion => ColocadorJardin.radioParterre * 1.7;

  @override
  double get radio => colocador.radioCon(deLaUltima + 1);
}
