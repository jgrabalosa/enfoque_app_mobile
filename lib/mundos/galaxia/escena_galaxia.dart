import 'dart:ui';

import '../escena_mundo.dart';
import 'colocador_galaxia.dart';

/// Todo lo que hay que dibujar de una galaxia con [cantidad] piezas, ya
/// colocado. Se rehace solo cuando cambian las piezas o la semilla, nunca
/// por fotograma.
class EscenaGalaxia implements EscenaMundo {
  EscenaGalaxia(this.colocador, this.cantidad)
    : estrellas = [for (var n = 0; n < cantidad; n++) colocador.estrella(n)] {
    hitos = colocador.hitosCon(completas);
  }

  final ColocadorGalaxia colocador;
  @override
  final int cantidad;
  final List<EstrellaColocada> estrellas;
  late final List<Hito> hitos;

  static const int _porConstelacion = ColocadorGalaxia.piezasPorConstelacion;

  @override
  int get piezasPorRegion => _porConstelacion;

  /// Constelaciones cerradas (con sus 10 estrellas).
  @override
  int get completas => cantidad ~/ _porConstelacion;

  /// La constelación en la que cae la próxima estrella. Con la última
  /// cerrada, ya es la siguiente.
  int get actual => cantidad ~/ _porConstelacion;

  /// La constelación de la última estrella que hay (la de hoy). Sin
  /// estrellas, la primera.
  @override
  int get deLaUltima =>
      cantidad == 0 ? 0 : ColocadorGalaxia.constelacionDe(cantidad - 1);

  /// Cuántas estrellas tiene ya la constelación de la última (1 a 10).
  @override
  int get enLaUltima =>
      cantidad == 0 ? 0 : (cantidad - 1) % _porConstelacion + 1;

  @override
  String nombreRegion(int region) => colocador.constelacion(region).nombre;

  @override
  Offset centroRegion(int region) => colocador.constelacion(region).centro;

  /// Una constelación mide como mucho dos veces el radio de su figura.
  @override
  double get ladoRegion => 140;

  /// El radio de lo que hay, para la vista «Todo».
  @override
  double get radio => colocador.radioCon(deLaUltima + 1);

  /// La última estrella (la de hoy), o `null` si no hay ninguna.
  EstrellaColocada? get ultima => cantidad == 0 ? null : estrellas.last;
}

/// Una forma de dibujar la galaxia.
typedef PintorGalaxia = PintorMundo<EscenaGalaxia>;
