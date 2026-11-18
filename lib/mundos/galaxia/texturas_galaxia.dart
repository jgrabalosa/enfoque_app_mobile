import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'colocador_galaxia.dart';
import 'paleta_profundidad.dart';

/// Las imágenes de las estrellas y de los hitos, **hechas por código** al
/// preparar el pintor: no hay ningún PNG. Se suman al fondo (son luz).
///
/// **Sin recuadros** (lo que vio Quim el 16-nov): todo se apaga del todo
/// antes del borde de su imagen, y entre una estrella y la siguiente del
/// atlas hay [margenEstrella] píxeles vacíos. Si no, al alejarse, la GPU usa
/// versiones reducidas de la imagen (mipmaps) en las que cada estrella se
/// mezcla con la de al lado, y se ven rectángulos.
class TexturasGalaxia {
  TexturasGalaxia._(this.estrellas, this.hitos);

  /// Lo que ocupa el dibujo de una estrella (el halo llega justo a su borde).
  static const int ladoEstrella = 128;

  /// Hueco vacío a cada lado de cada estrella del atlas.
  static const int margenEstrella = 32;

  /// Lo que ocupa cada estrella en el atlas, con su hueco.
  static const int celdaEstrella = ladoEstrella + 2 * margenEstrella;

  /// Lado de la imagen de cada hito (cada uno, en su propia imagen).
  static const int ladoHito = 384;

  /// Las 6 normales (0 a 5) y las 2 que cierran constelación (6 y 7), en fila.
  static const int estrellasEnAtlas = VariantesEstrella.normales + 2;

  /// Los dos colores de cada nebulosa: el de fuera y el de las vetas. Como
  /// las regiones de formación de estrellas de las fotos (rosa y ámbar) y
  /// cerca del amarillo de Profundidad; una, con algo de violeta oscuro.
  static const List<(Color, Color)> coloresNebulosa = [
    (Color(0xFFB8456F), Color(0xFFFF9A5C)),
    (Color(0xFF6A3F8F), Color(0xFFE0668E)),
    (Color(0xFFC26A2E), Color(0xFFFFC266)),
  ];

  final Image estrellas;

  /// Una imagen por variante de hito: 0 a 2, nebulosas; 3, cúmulo.
  final List<Image> hitos;

  /// La celda entera, con su hueco: así lo que se muestrea alrededor de la
  /// estrella es transparente.
  Rect rectEstrella(int i) => Rect.fromLTWH(
    i * celdaEstrella.toDouble(),
    0,
    celdaEstrella.toDouble(),
    celdaEstrella.toDouble(),
  );

  /// [nebulosa] es el programa de `shaders/nebulosa.frag`; sin él, las
  /// nebulosas se dibujan con manchas suaves.
  static TexturasGalaxia crear({FragmentProgram? nebulosa}) =>
      TexturasGalaxia._(_atlasEstrellas(), [
        for (var i = 0; i < Hito.variantes; i++)
          i < coloresNebulosa.length ? _nebulosa(i, nebulosa) : _cumulo(i),
      ]);

  void liberar() {
    estrellas.dispose();
    for (final h in hitos) {
      h.dispose();
    }
  }

  static Image _atlasEstrellas() {
    const s = ladoEstrella * 1.0;
    const celda = celdaEstrella * 1.0;
    final grabadora = PictureRecorder();
    final canvas = Canvas(grabadora);
    for (var i = 0; i < estrellasEnAtlas; i++) {
      final c = Offset(i * celda + celda / 2, celda / 2);
      final cierra = i >= VariantesEstrella.normales;
      // El halo, como el de una estrella en una foto: cae muy deprisa cerca
      // del centro y deja una luz tenue y larga, a cero justo en su borde.
      _brillo(
        canvas,
        c,
        s / 2,
        cierra ? 0.55 : 0.38,
        const [0, 0.04, 0.1, 0.24, 0.5, 1],
        const [1, 0.5, 0.16, 0.05, 0.015, 0],
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
        final r = cierra ? 9.0 : 6.0;
        _brillo(canvas, c, r, 1, const [0, 0.35, 1], const [1, 0.75, 0]);
      }
      // Destellos de cuatro puntas: la variante 5 y las que cierran.
      if (i == 5 || cierra) {
        // Finos, como las aspas de difracción de un telescopio.
        final largo = s * (cierra ? 0.48 : 0.34);
        final grosor = cierra ? 1.5 : 1.1;
        _destello(canvas, c, largo, grosor, 0.7, 0);
        _destello(canvas, c, largo, grosor, 0.7, math.pi / 2);
        if (i == 7) {
          _destello(canvas, c, largo * 0.5, 0.9, 0.35, math.pi / 4);
          _destello(canvas, c, largo * 0.5, 0.9, 0.35, -math.pi / 4);
        }
      }
    }
    return grabadora.endRecording().toImageSync(
      celdaEstrella * estrellasEnAtlas,
      celdaEstrella,
    );
  }

  /// Una nebulosa con el shader: humo con remolinos y vetas de dos colores,
  /// que se apaga antes del borde.
  static Image _nebulosa(int i, FragmentProgram? programa) {
    const lado = ladoHito * 1.0;
    final grabadora = PictureRecorder();
    final canvas = Canvas(grabadora);
    final (a, b) = coloresNebulosa[i];
    if (programa != null) {
      final shader = programa.fragmentShader()
        ..setFloat(0, lado)
        ..setFloat(1, lado)
        ..setFloat(2, 0.17 + i * 0.29)
        ..setFloat(3, a.r)
        ..setFloat(4, a.g)
        ..setFloat(5, a.b)
        ..setFloat(6, b.r)
        ..setFloat(7, b.g)
        ..setFloat(8, b.b);
      canvas.drawRect(
        Offset.zero & const Size(lado, lado),
        Paint()..shader = shader,
      );
      final imagen = grabadora.endRecording().toImageSync(ladoHito, ladoHito);
      shader.dispose();
      return imagen;
    }
    // Sin shader: manchas suaves del color, que tampoco llegan al borde.
    final azar = math.Random(7919 * (i + 1));
    const c = Offset(lado / 2, lado / 2);
    for (var k = 0; k < 40; k++) {
      final d = (_gauss(azar) * 0.12).clamp(-0.22, 0.22) * lado;
      final ang = azar.nextDouble() * 2 * math.pi;
      final p = c + Offset(math.cos(ang), math.sin(ang) * 0.6) * d;
      final r = lado * (0.05 + azar.nextDouble() * 0.12);
      _brillo(
        canvas,
        p,
        r,
        0.06 + azar.nextDouble() * 0.06,
        const [0, 0.4, 1],
        const [1, 0.4, 0],
        color: k.isEven ? a : b,
      );
    }
    return grabadora.endRecording().toImageSync(ladoHito, ladoHito);
  }

  /// Un cúmulo: un resplandor y muchas estrellas pequeñas juntas.
  static Image _cumulo(int i) {
    const lado = ladoHito * 1.0;
    final grabadora = PictureRecorder();
    final canvas = Canvas(grabadora);
    const c = Offset(lado / 2, lado / 2);
    final azar = math.Random(7919 * (i + 1));
    // Dorado: los cúmulos viejos, como el núcleo.
    const dorado = Color(0xFFFFD58A);
    _brillo(
      canvas,
      c,
      lado * 0.36,
      0.35,
      const [0, 0.35, 1],
      const [1, 0.25, 0],
      color: dorado,
    );
    for (var k = 0; k < 90; k++) {
      final d = (_gauss(azar).abs() * 0.09).clamp(0.0, 0.3) * lado;
      final ang = azar.nextDouble() * 2 * math.pi;
      final p = c + Offset(math.cos(ang), math.sin(ang)) * d;
      _brillo(
        canvas,
        p,
        2.5 + azar.nextDouble() * 3.5,
        0.95,
        const [0, 0.5, 1],
        const [1, 0.7, 0],
        color: k % 5 == 0 ? PaletaProfundidad.estrellas[2] : dorado,
      );
    }
    return grabadora.endRecording().toImageSync(ladoHito, ladoHito);
  }

  /// Un círculo de luz que se apaga hacia el borde (blanca, si no se dice).
  static void _brillo(
    Canvas canvas,
    Offset c,
    double radio,
    double intensidad,
    List<double> paradas,
    List<double> alfas, {
    Color color = const Color(0xFFFFFFFF),
  }) {
    canvas.drawCircle(
      c,
      radio,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = Gradient.radial(c, radio, [
          for (final a in alfas)
            color.withValues(alpha: (a * intensidad).clamp(0.0, 1.0)),
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

  /// Para los tests: la luz más fuerte (0 a 1) en el contorno de [zona] de
  /// [imagen]. Si no es 0, al alejarse se vería el recuadro.
  @visibleForTesting
  static Future<double> luzEnElBorde(Image imagen, {Rect? zona}) async {
    final datos = (await imagen.toByteData())!.buffer.asUint8List();
    final w = imagen.width;
    final z =
        zona ?? Rect.fromLTWH(0, 0, w.toDouble(), imagen.height.toDouble());
    var maximo = 0;
    void mirar(int x, int y) {
      final i = (y * w + x) * 4;
      for (var k = 0; k < 4; k++) {
        maximo = math.max(maximo, datos[i + k]);
      }
    }

    final l = z.left.toInt(), t = z.top.toInt();
    final r = z.right.toInt() - 1, b = z.bottom.toInt() - 1;
    for (var x = l; x <= r; x++) {
      mirar(x, t);
      mirar(x, b);
    }
    for (var y = t; y <= b; y++) {
      mirar(l, y);
      mirar(r, y);
    }
    return maximo / 255;
  }
}
