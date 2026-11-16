import 'dart:ui';

import '../vista_mundo.dart';
import 'escena_galaxia.dart';
import 'paleta_profundidad.dart';

/// El pintor más simple posible: puntos, líneas y círculos. Feo a propósito:
/// sirve para comprobar dónde cae cada estrella, el zoom y lo que cuesta
/// mover 1.000 piezas sin efectos.
class PintorPrueba extends PintorGalaxia {
  @override
  String get nombre => 'Prueba';

  @override
  Future<void> preparar() async {}

  @override
  void pintar(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaGalaxia escena, {
    required double segundos,
    int? nueva,
    double aparicion = 1,
  }) {
    canvas.drawRect(
      Offset.zero & tamano,
      Paint()..color = PaletaProfundidad.fondo,
    );
    final visible = vista.visible(tamano, margen: 300);

    final hito = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x5586A8FF);
    for (final h in escena.hitos) {
      if (!visible.contains(h.centro)) continue;
      canvas.drawCircle(
        vista.aPantalla(h.centro, tamano),
        h.radio * vista.escala,
        hito,
      );
    }

    final linea = Paint()
      ..color = const Color(0x668FB3FF)
      ..strokeWidth = 1;
    final punto = Paint()..color = const Color(0xFFE8EEFF);
    final hoy = Paint()..color = PaletaProfundidad.amarillo;
    for (final e in escena.estrellas) {
      if (!visible.contains(e.posicion)) continue;
      final p = vista.aPantalla(e.posicion, tamano);
      final union = e.unidaA;
      if (union != null) {
        canvas.drawLine(
          p,
          vista.aPantalla(escena.estrellas[union].posicion, tamano),
          linea,
        );
      }
      final radio =
          (e.cierra ? 5.0 : 3.0) * (e.numero == nueva ? aparicion : 1);
      canvas.drawCircle(
        p,
        radio,
        e.numero == escena.cantidad - 1 ? hoy : punto,
      );
    }
  }
}
