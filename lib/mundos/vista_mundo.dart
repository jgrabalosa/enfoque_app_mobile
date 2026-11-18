import 'dart:math' as math;
import 'dart:ui';

/// Qué parte del mundo se ve: el punto del mundo que cae en el centro de la
/// pantalla y cuántos píxeles lógicos ocupa una unidad del mundo.
class VistaMundo {
  const VistaMundo({required this.centro, required this.escala});

  final Offset centro;
  final double escala;

  /// Del mundo a la pantalla de tamaño [tamano].
  Offset aPantalla(Offset mundo, Size tamano) =>
      (mundo - centro) * escala + tamano.center(Offset.zero);

  /// De la pantalla al mundo.
  Offset aMundo(Offset pantalla, Size tamano) =>
      (pantalla - tamano.center(Offset.zero)) / escala + centro;

  /// El rectángulo del mundo que se ve, con [margen] unidades de más por
  /// cada lado (para lo que tiene halo).
  Rect visible(Size tamano, {double margen = 0}) => Rect.fromCenter(
    center: centro,
    width: tamano.width / escala + 2 * margen,
    height: tamano.height / escala + 2 * margen,
  );

  /// La misma vista con la escala [nueva], sin mover el punto [foco] de la
  /// pantalla: ese punto del mundo se queda debajo de los dedos.
  VistaMundo conEscala(double nueva, Offset foco, Size tamano) {
    final mundo = aMundo(foco, tamano);
    return VistaMundo(
      centro: mundo - (foco - tamano.center(Offset.zero)) / nueva,
      escala: nueva,
    );
  }

  /// Arrastrada [delta] píxeles.
  VistaMundo movida(Offset delta) =>
      VistaMundo(centro: centro - delta / escala, escala: escala);

  /// Entre esta vista y [otra], en [t] (0 a 1). La escala va en logaritmo,
  /// para que el zoom se vea a velocidad constante.
  VistaMundo hacia(VistaMundo otra, double t) => VistaMundo(
    centro: Offset.lerp(centro, otra.centro, t)!,
    escala: escala * math.pow(otra.escala / escala, t).toDouble(),
  );
}
