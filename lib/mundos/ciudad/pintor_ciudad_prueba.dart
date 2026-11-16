import 'dart:ui';

import '../vista_mundo.dart';
import 'colocador_ciudad.dart';
import 'escena_ciudad.dart';
import 'paleta_neotokyo.dart';

/// El pintor más simple de la ciudad: calles, plantas de los edificios y
/// los hitos como rectángulos. Feo a propósito: sirve para comprobar dónde
/// cae cada cosa y lo que cuesta sin efectos.
class PintorCiudadPrueba extends PintorCiudad {
  @override
  String get nombre => 'Prueba';

  @override
  Future<void> preparar() async {}

  @override
  void pintar(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaCiudad escena, {
    required double segundos,
    int? nueva,
    double aparicion = 1,
  }) {
    canvas.drawRect(
      Offset.zero & tamano,
      Paint()..color = PaletaNeotokyo.fondo,
    );
    canvas.save();
    canvas.translate(tamano.width / 2, tamano.height / 2);
    canvas.scale(vista.escala);
    canvas.translate(-vista.centro.dx, -vista.centro.dy);
    final px = 1 / vista.escala;
    final calle = Paint()
      ..strokeWidth = px
      ..color = const Color(0x6600E5FF);
    for (final (a, b) in escena.calles) {
      canvas.drawLine(a, b, calle);
    }
    final hito = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * px
      ..color = PaletaNeotokyo.amarillo;
    for (final h in escena.hitos) {
      canvas.drawRect(h.rect, hito);
    }
    canvas.drawRect(
      ColocadorCiudad.rectCelda(0, 0),
      hito..color = PaletaNeotokyo.rosa,
    );
    final hoy = escena.cantidad - 1;
    for (final e in escena.edificios) {
      final brillo = (e.altura / 250).clamp(0.2, 1.0);
      canvas.drawRect(
        e.rect,
        Paint()
          ..color = e.numero == hoy
              ? PaletaNeotokyo.amarillo
              : PaletaNeotokyo.neones[e.neon].withValues(alpha: brillo),
      );
    }
    canvas.restore();
  }
}
