import 'dart:ui';

import '../vista_mundo.dart';
import 'colocador_galaxia.dart';

/// Todo lo que hay que dibujar de una galaxia con [cantidad] piezas, ya
/// colocado. Se rehace solo cuando cambian las piezas o la semilla, nunca
/// por fotograma.
class EscenaGalaxia {
  EscenaGalaxia(this.colocador, this.cantidad)
    : estrellas = [for (var n = 0; n < cantidad; n++) colocador.estrella(n)] {
    hitos = colocador.hitosCon(completas);
  }

  final ColocadorGalaxia colocador;
  final int cantidad;
  final List<EstrellaColocada> estrellas;
  late final List<Hito> hitos;

  static const int _porConstelacion = ColocadorGalaxia.piezasPorConstelacion;

  /// Constelaciones cerradas (con sus 10 estrellas).
  int get completas => cantidad ~/ _porConstelacion;

  /// La constelación en la que cae la próxima estrella. Con la última
  /// cerrada, ya es la siguiente.
  int get actual => cantidad ~/ _porConstelacion;

  /// La constelación de la última estrella que hay (la de hoy). Sin
  /// estrellas, la primera.
  int get deLaUltima =>
      cantidad == 0 ? 0 : ColocadorGalaxia.constelacionDe(cantidad - 1);

  /// Cuántas estrellas tiene ya la constelación de la última (1 a 10).
  int get enLaUltima =>
      cantidad == 0 ? 0 : (cantidad - 1) % _porConstelacion + 1;

  /// El radio de lo que hay, para la vista «Todo».
  double get radio => colocador.radioCon(deLaUltima + 1);

  /// La última estrella (la de hoy), o `null` si no hay ninguna.
  EstrellaColocada? get ultima => cantidad == 0 ? null : estrellas.last;
}

/// Una forma de dibujar la galaxia. El laboratorio tiene varias, y todas
/// reciben **la misma escena y la misma vista**: así la comparación es justa,
/// solo cambia el dibujo (`encargos/focus-mundos.md` §3).
abstract class PintorGalaxia {
  /// Lo que se ve en el botón del laboratorio.
  String get nombre;

  /// Lo que haya que preparar una vez (texturas, el shader). Se espera antes
  /// del primer [pintar].
  Future<void> preparar();

  /// Pinta un fotograma. [segundos] es el reloj de la animación; [nueva], la
  /// estrella que está apareciendo, y [aparicion], cuánto le falta (0 a 1).
  void pintar(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaGalaxia escena, {
    required double segundos,
    int? nueva,
    double aparicion = 1,
  });

  void liberar() {}
}
