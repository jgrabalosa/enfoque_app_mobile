import 'dart:math' as math;
import 'dart:ui';

import 'colocador_galaxia.dart';

/// Las imágenes de las estrellas y de los hitos, **dibujadas por código** al
/// preparar el pintor: no hay ningún PNG. Van en blanco y gris; el color lo
/// pone el pintor al tintarlas, y se suman al fondo (son luz), así que no
/// hace falta transparencia recortada.
class TexturasGalaxia {
  TexturasGalaxia._(this.estrellas, this.hitos);

  /// Lado de cada estrella en [estrellas].
  static const int ladoEstrella = 128;

  /// Lado de cada hito en [hitos].
  static const int ladoHito = 256;

  /// Las 6 normales (0 a 5) y las 2 que cierran constelación (6 y 7), en fila.
  static const int estrellasEnAtlas = VariantesEstrella.normales + 2;

  final Image estrellas;
  final Image hitos;

  Rect rectEstrella(int i) => Rect.fromLTWH(
    i * ladoEstrella.toDouble(),
    0,
    ladoEstrella.toDouble(),
    ladoEstrella.toDouble(),
  );

  Rect rectHito(int i) => Rect.fromLTWH(
    i * ladoHito.toDouble(),
    0,
    ladoHito.toDouble(),
    ladoHito.toDouble(),
  );

  static TexturasGalaxia crear() =>
      TexturasGalaxia._(_atlasEstrellas(), _atlasHitos());

  void liberar() {
    estrellas.dispose();
    hitos.dispose();
  }

  static Image _atlasEstrellas() {
    const s = ladoEstrella * 1.0;
    final grabadora = PictureRecorder();
    final canvas = Canvas(grabadora);
    for (var i = 0; i < estrellasEnAtlas; i++) {
      final c = Offset(i * s + s / 2, s / 2);
      final cierra = i >= VariantesEstrella.normales;
      // El halo: grande y suave.
      _brillo(
        canvas,
        c,
        s / 2,
        cierra ? 0.75 : 0.55,
        const [0, 0.1, 0.32, 1],
        const [1, 0.38, 0.09, 0],
      );
      // El núcleo: pequeño y casi blanco del todo.
      if (i == 4) {
        // Doble.
        _brillo(
          canvas,
          c + const Offset(-6, -2),
          7,
          1,
          const [0, 0.5, 1],
          const [1, 0.8, 0],
        );
        _brillo(
          canvas,
          c + const Offset(7, 3),
          5,
          0.9,
          const [0, 0.5, 1],
          const [1, 0.8, 0],
        );
      } else {
        final r = cierra ? 11.0 : 7.5;
        _brillo(canvas, c, r, 1, const [0, 0.45, 1], const [1, 0.85, 0]);
      }
      // Destellos de cuatro puntas: la variante 5 y las que cierran.
      if (i == 5 || cierra) {
        final largo = cierra ? s * 0.5 : s * 0.38;
        _destello(canvas, c, largo, cierra ? 2.2 : 1.6, 0.75, 0);
        _destello(canvas, c, largo, cierra ? 2.2 : 1.6, 0.75, math.pi / 2);
        if (i == 7) {
          _destello(canvas, c, largo * 0.55, 1.2, 0.4, math.pi / 4);
          _destello(canvas, c, largo * 0.55, 1.2, 0.4, -math.pi / 4);
        }
      }
    }
    return grabadora.endRecording().toImageSync(
      ladoEstrella * estrellasEnAtlas,
      ladoEstrella,
    );
  }

  static Image _atlasHitos() {
    const s = ladoHito * 1.0;
    final grabadora = PictureRecorder();
    final canvas = Canvas(grabadora);
    for (var i = 0; i < Hito.variantes; i++) {
      final c = Offset(i * s + s / 2, s / 2);
      final azar = math.Random(7919 * (i + 1));
      if (i < 3) {
        // Nebulosa: muchas manchas suaves que se solapan.
        // Poca intensidad cada una: si no, se suman en un disco macizo.
        for (var k = 0; k < 40; k++) {
          final d = _gauss(azar) * s * 0.16;
          final a = azar.nextDouble() * 2 * math.pi;
          final p = c + Offset(math.cos(a), math.sin(a) * 0.55) * d;
          final r = s * (0.05 + azar.nextDouble() * 0.16);
          _brillo(
            canvas,
            p,
            r,
            0.05 + azar.nextDouble() * 0.07,
            const [0, 0.4, 1],
            const [1, 0.4, 0],
          );
        }
        // Unas pocas estrellas dentro, para que no sea solo humo.
        for (var k = 0; k < 8; k++) {
          final d = _gauss(azar) * s * 0.12;
          final a = azar.nextDouble() * 2 * math.pi;
          final p = c + Offset(math.cos(a), math.sin(a)) * d;
          _brillo(
            canvas,
            p,
            2 + azar.nextDouble() * 2.5,
            0.8,
            const [0, 0.5, 1],
            const [1, 0.7, 0],
          );
        }
      } else {
        // Cúmulo: un resplandor y muchas estrellas pequeñas juntas.
        _brillo(
          canvas,
          c,
          s * 0.42,
          0.35,
          const [0, 0.4, 1],
          const [1, 0.3, 0],
        );
        for (var k = 0; k < 70; k++) {
          final d = _gauss(azar).abs() * s * 0.12;
          final a = azar.nextDouble() * 2 * math.pi;
          final p = c + Offset(math.cos(a), math.sin(a)) * d;
          _brillo(
            canvas,
            p,
            2.5 + azar.nextDouble() * 3,
            0.9,
            const [0, 0.5, 1],
            const [1, 0.7, 0],
          );
        }
      }
    }
    return grabadora.endRecording().toImageSync(
      ladoHito * Hito.variantes,
      ladoHito,
    );
  }

  /// Un círculo de luz blanca que se apaga hacia el borde.
  static void _brillo(
    Canvas canvas,
    Offset c,
    double radio,
    double intensidad,
    List<double> paradas,
    List<double> alfas,
  ) {
    canvas.drawCircle(
      c,
      radio,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = Gradient.radial(c, radio, [
          for (final a in alfas)
            Color.fromRGBO(255, 255, 255, (a * intensidad).clamp(0.0, 1.0)),
        ], paradas),
    );
  }

  /// Una raya de luz que se apaga hacia las puntas.
  static void _destello(
    Canvas canvas,
    Offset c,
    double largo,
    double grosor,
    double intensidad,
    double angulo,
  ) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angulo);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: largo * 2,
      height: grosor,
    );
    final blanco = Color.fromRGBO(255, 255, 255, intensidad);
    const nada = Color(0x00FFFFFF);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = Gradient.linear(
          rect.centerLeft,
          rect.centerRight,
          [nada, blanco, nada],
          const [0, 0.5, 1],
        ),
    );
    canvas.restore();
  }

  static double _gauss(math.Random r) {
    final u = 1 - r.nextDouble();
    final v = r.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }
}
