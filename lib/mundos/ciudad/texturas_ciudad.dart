import 'dart:math' as math;
import 'dart:ui';

import 'paleta_neotokyo.dart';

/// Las imágenes de la ciudad, **hechas por código** al preparar el pintor.
class TexturasCiudad {
  TexturasCiudad._(this.ventanas, this.luz);

  /// Una fachada con ventanas que se repite por las paredes. Las dos últimas
  /// filas son una franja gris lisa: en las paredes, la línea entre plantas;
  /// los tejados se pintan con ese trozo, y el color lo pone el vértice.
  /// (Una columna lisa haría rayas en diagonal: cada pared son dos
  /// triángulos y la textura se estira distinto en cada uno.)
  final Image ventanas;

  /// Una luz redonda y suave (faros, farolas, la antena), que se apaga antes
  /// del borde.
  final Image luz;

  static const int ladoVentanas = 64;
  static const int ladoLuz = 64;

  /// Dónde se muestrea el trozo liso (para los tejados).
  static const Offset puntoLiso = Offset(32, 63);

  /// Lo que vale el trozo liso (gris medio): el vértice del tejado va al
  /// doble de su color para que salga el que toca.
  static const double grisLiso = 0.5;

  static TexturasCiudad crear() => TexturasCiudad._(_ventanas(), _luz());

  void liberar() {
    ventanas.dispose();
    luz.dispose();
  }

  static Image _ventanas() {
    const lado = ladoVentanas * 1.0;
    final grabadora = PictureRecorder();
    final canvas = Canvas(grabadora);
    // La fachada: gris oscuro (lo tiñe el color de la pared).
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, lado, lado),
      Paint()..color = const Color(0xFF241C38),
    );
    // La franja lisa, abajo.
    canvas.drawRect(
      const Rect.fromLTWH(0, lado - 2, lado, 2),
      Paint()..color = const Color(0xFF808080),
    );
    final azar = math.Random(4242);
    const colores = [
      Color(0xFFFFE9A8), // cálida
      Color(0xFFFFF4DA),
      Color(0xFF9FF3FF), // cian
      Color(0xFFFF9CCB), // rosa
    ];
    // Ventanas de 4 × 5 con 2 de separación, unas encendidas y otras no.
    for (var y = 3.0; y + 5 < lado - 2; y += 8) {
      for (var x = 1.0; x + 4 < lado; x += 6) {
        final r = azar.nextDouble();
        final Color c;
        if (r < 0.45) {
          c = const Color(0xFF120E1E);
        } else {
          final base =
              colores[azar.nextInt(10) < 7
                  ? azar.nextInt(2)
                  : 2 + azar.nextInt(2)];
          c = base.withValues(alpha: 0.55 + azar.nextDouble() * 0.45);
        }
        canvas.drawRect(Rect.fromLTWH(x, y, 4, 5), Paint()..color = c);
      }
    }
    return grabadora.endRecording().toImageSync(ladoVentanas, ladoVentanas);
  }

  static Image _luz() {
    const lado = ladoLuz * 1.0;
    final grabadora = PictureRecorder();
    final canvas = Canvas(grabadora);
    const c = Offset(lado / 2, lado / 2);
    canvas.drawCircle(
      c,
      lado / 2 - 2,
      Paint()
        ..shader = Gradient.radial(
          c,
          lado / 2 - 2,
          const [
            Color(0xFFFFFFFF),
            Color(0x99FFFFFF),
            Color(0x22FFFFFF),
            Color(0x00FFFFFF),
          ],
          const [0, 0.12, 0.4, 1],
        ),
    );
    return grabadora.endRecording().toImageSync(ladoLuz, ladoLuz);
  }

  /// El color de la luz de cada neón, más claro que el neón (para los
  /// halos).
  static Color claro(Color c) => Color.lerp(c, PaletaNeotokyo.texto, 0.25)!;
}
