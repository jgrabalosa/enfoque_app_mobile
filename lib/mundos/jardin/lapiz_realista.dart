import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../azar.dart';

/// El lápiz de color del jardín de Dulce, lo más real posible.
///
/// Se dibuja en dos tiempos, como pasa con un lápiz de verdad:
///
/// 1. **La presión.** Cada trazo deja en un lienzo cuánto se ha apretado en
///    cada punto: fino y flojo en las puntas, más firme en medio, con
///    temblores lentos. Los trazos se suman: donde se repasa, se aprieta más.
/// 2. **El pigmento** ([Pigmento]): un shader decide, píxel a píxel, si el
///    pigmento agarra según el relieve del papel. Con poca presión salen
///    motas; apretando, el color se cierra.
///
/// Todo sale de una semilla: el mismo dibujo sale siempre igual.
abstract final class Lapiz {
  /// El ángulo de la mano: todo el rayado del jardín va igual, como si lo
  /// hubiera hecho la misma persona (diestra, de abajo a la izquierda hacia
  /// arriba a la derecha).
  static const double anguloMano = -0.95;

  /// Un trazo por los [puntos], con su presión (0 a 1) y su grosor.
  static void trazo(
    Canvas c,
    List<Offset> puntos, {
    required int semilla,
    double ancho = 2.4,
    double presion = 0.7,
    double temblor = 0.5,
    double puntas = 0.18,
    double paso = 1.4,
  }) {
    final muestras = _remuestrear(puntos, paso);
    if (muestras.length < 2) return;
    final n = muestras.length;
    var largo = 0.0;
    final acumulado = <double>[0];
    for (var i = 1; i < n; i++) {
      largo += (muestras[i] - muestras[i - 1]).distance;
      acumulado.add(largo);
    }
    if (largo < 0.5) return;
    final posiciones = <Offset>[];
    final colores = <Color>[];
    Offset? izqAnt, cenAnt, derAnt;
    Color? cAnt;
    final fase = azarMundo(semilla, 1, 901) * 100;
    for (var i = 0; i < n; i++) {
      final t = acumulado[i] / largo;
      final antes = muestras[math.max(0, i - 1)];
      final despues = muestras[math.min(n - 1, i + 1)];
      var d = despues - antes;
      if (d.distance == 0) d = const Offset(1, 0);
      d = d / d.distance;
      final normal = Offset(-d.dy, d.dx);
      // Las puntas: se entra y se sale del papel.
      final entrada = _suave((t / puntas).clamp(0.0, 1.0));
      final salida = _suave(((1 - t) / (puntas * 0.8)).clamp(0.0, 1.0));
      final perfil = math.min(entrada, salida);
      // La mano no aprieta igual todo el rato.
      final s = acumulado[i];
      final variacion =
          1 +
          0.22 * math.sin(s / 9 + fase) +
          0.12 * math.sin(s / 3.1 + fase * 1.7);
      final p = (presion * (0.35 + 0.65 * perfil) * variacion).clamp(0.0, 1.0);
      final w = ancho * (0.55 + 0.45 * perfil) * 0.5;
      final tiembla =
          temblor * (math.sin(s / 13 + fase) + 0.5 * math.sin(s / 5.3 + fase));
      final centro = muestras[i] + normal * tiembla;
      final izq = centro + normal * w;
      final der = centro - normal * w;
      final color = Color.fromRGBO(255, 255, 255, p);
      if (cenAnt != null) {
        // Dos cuadrados por tramo: del borde (transparente) al centro.
        for (final (a1, a2, b1, b2, ca1, ca2, cb1, cb2) in [
          (izqAnt!, izq, cenAnt, centro, _nada, _nada, cAnt!, color),
          (cenAnt, centro, derAnt!, der, cAnt, color, _nada, _nada),
        ]) {
          posiciones.addAll([a1, a2, b1, a2, b2, b1]);
          colores.addAll([ca1, ca2, cb1, ca2, cb2, cb1]);
        }
      }
      izqAnt = izq;
      cenAnt = centro;
      derAnt = der;
      cAnt = color;
    }
    c.drawVertices(
      Vertices(VertexMode.triangles, posiciones, colors: colores),
      BlendMode.dst,
      Paint()..blendMode = BlendMode.plus,
    );
  }

  static const Color _nada = Color(0x00FFFFFF);

  /// El contorno de [forma], a mano: tiembla un poco y se pasa del inicio.
  /// [desde] y [hasta] (0 a 1) dejan dibujar solo un tramo.
  static void contorno(
    Canvas c,
    Path forma, {
    required int semilla,
    double ancho = 2.0,
    double presion = 0.75,
    double desde = 0,
    double hasta = 1,
    int pasadas = 2,
  }) {
    var k = 0;
    for (final m in forma.computeMetrics()) {
      for (var pasada = 0; pasada < pasadas; pasada++) {
        final sem = semilla * 7 + k * 13 + pasada;
        final extra = m.isClosed && desde == 0 && hasta == 1
            ? 0.04 + azarMundo(sem, 2, 902) * 0.05
            : 0.0;
        final ini = (desde + azarMundo(sem, 3, 902) * 0.02) * m.length;
        final fin =
            math.min(hasta + extra, hasta == 1 ? 1 + extra : hasta) * m.length;
        final puntos = <Offset>[];
        for (var s = ini; s <= fin; s += 2) {
          final t = m.getTangentForOffset(s % m.length);
          if (t != null) puntos.add(t.position);
        }
        trazo(
          c,
          puntos,
          semilla: sem,
          ancho: ancho * (pasada == 0 ? 1 : 0.8),
          presion: presion * (pasada == 0 ? 1 : 0.55),
          temblor: 0.6 + pasada * 0.4,
          puntas: 0.08,
        );
      }
      k++;
    }
  }

  /// Rellena [forma] a rayas paralelas en el ángulo de la mano, como se
  /// colorea con lápiz. [presion] dice cuánto se aprieta en cada punto (más
  /// en la sombra). Las rayas se pasan o se quedan cortas en el borde, un
  /// poco, como cuando se colorea de verdad.
  static void rayado(
    Canvas c,
    Path forma, {
    required int semilla,
    required double Function(Offset) presion,
    double separacion = 2.6,
    double ancho = 2.6,
    double angulo = anguloMano,
    double desborde = 1.4,
  }) {
    final caja = forma.getBounds().inflate(4);
    final dir = Offset(math.cos(angulo), math.sin(angulo));
    final normal = Offset(-dir.dy, dir.dx);
    final centro = caja.center;
    final radio =
        math.sqrt(caja.width * caja.width + caja.height * caja.height) / 2;
    // Se mira si la raya está dentro cada [paso]; donde cambia, se afina
    // partiendo el tramo en dos unas cuantas veces. Mucho más rápido que
    // mirar punto a punto, y el borde sale igual de fino.
    final paso = math.max(1.0, caja.shortestSide / 40);
    final precision = paso / 16;
    double borde(Offset base, double fuera, double dentro) {
      var a = fuera;
      var b = dentro;
      while ((b - a).abs() > precision) {
        final m = (a + b) / 2;
        if (forma.contains(base + dir * m)) {
          b = m;
        } else {
          a = m;
        }
      }
      return b;
    }

    var linea = 0;
    for (var o = -radio; o <= radio; o += separacion) {
      linea++;
      final desplaz =
          o + (azarMundo(semilla, linea, 903) - 0.5) * separacion * 0.6;
      final base = centro + normal * desplaz;
      double? entra;
      var tramo = 0;
      var antes = false;
      var sAntes = -radio - paso;
      for (var s = -radio; s <= radio + paso; s += paso) {
        final dentro = s <= radio && forma.contains(base + dir * s);
        if (dentro && !antes) {
          entra = borde(base, sAntes, s);
        }
        if (!dentro && antes && entra != null) {
          final sale = borde(base, s, sAntes);
          _raya(
            c,
            base + dir * entra,
            base + dir * sale,
            dir,
            semilla,
            linea,
            tramo++,
            presion,
            ancho,
            desborde,
          );
          entra = null;
        }
        antes = dentro;
        sAntes = s;
      }
    }
  }

  static void _raya(
    Canvas c,
    Offset a,
    Offset b,
    Offset dir,
    int semilla,
    int linea,
    int tramo,
    double Function(Offset) presion,
    double ancho,
    double desborde,
  ) {
    final sem = semilla * 31 + linea * 7 + tramo;
    final ini = a - dir * ((azarMundo(sem, 1, 904) - 0.3) * desborde * 2);
    final fin = b + dir * ((azarMundo(sem, 2, 904) - 0.3) * desborde * 2);
    if ((fin - ini).distance < 1.5) return;
    final medio = Offset.lerp(ini, fin, 0.5)!;
    // Un poco curvada: la muñeca gira.
    final normal = Offset(-dir.dy, dir.dx);
    final curva = normal * ((azarMundo(sem, 3, 904) - 0.5) * 1.2);
    final puntos = [
      for (var k = 0; k <= 6; k++)
        Offset.lerp(ini, fin, k / 6)! +
            curva * (1 - math.pow(2 * k / 6 - 1, 2).toDouble()),
    ];
    trazo(
      c,
      puntos,
      semilla: sem,
      ancho: ancho * (0.85 + 0.3 * azarMundo(sem, 4, 904)),
      presion: presion(medio) * (0.8 + 0.35 * azarMundo(sem, 5, 904)),
      temblor: 0.25,
      puntas: 0.12,
      // Una raya larga no necesita tantos puntos: es casi recta.
      paso: math.max(1.4, (fin - ini).distance / 30),
    );
  }

  /// Punteado: motitas de lápiz (el centro de una margarita, la grava).
  static void puntos(
    Canvas c,
    Path forma, {
    required int semilla,
    required int cuantos,
    double tamano = 1.6,
    double presion = 0.8,
  }) {
    final caja = forma.getBounds();
    var hechos = 0;
    for (var k = 0; hechos < cuantos && k < cuantos * 8; k++) {
      final p = Offset(
        caja.left + azarMundo(semilla, k, 905) * caja.width,
        caja.top + azarMundo(semilla, k, 906) * caja.height,
      );
      if (!forma.contains(p)) continue;
      hechos++;
      final a = azarMundo(semilla, k, 907) * math.pi;
      final d = Offset(math.cos(a), math.sin(a)) * tamano * 0.5;
      trazo(
        c,
        [p - d, p, p + d],
        semilla: semilla + k,
        ancho: tamano * 1.4,
        presion: presion * (0.7 + 0.5 * azarMundo(semilla, k, 908)),
        temblor: 0,
        puntas: 0.3,
      );
    }
  }

  static List<Offset> _remuestrear(List<Offset> pts, double paso) {
    if (pts.length < 2) return pts;
    final r = <Offset>[pts.first];
    var resto = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final l = (b - a).distance;
      if (l == 0) continue;
      var s = paso - resto;
      while (s <= l) {
        r.add(Offset.lerp(a, b, s / l)!);
        s += paso;
      }
      resto = l - (s - paso);
    }
    if ((r.last - pts.last).distance > 0.3) r.add(pts.last);
    return r;
  }

  static double _suave(double t) => t * t * (3 - 2 * t);
}

/// Convierte lo que se apretó en pigmento sobre papel (`shaders/pigmento.frag`).
class Pigmento {
  Pigmento(this._programa);

  final FragmentProgram _programa;

  static Future<Pigmento> cargar() async =>
      Pigmento(await FragmentProgram.fromAsset('shaders/pigmento.frag'));

  /// Dibuja con [dibujo] (trazos de [Lapiz]) en un lienzo de [ancho] × [alto]
  /// píxeles y devuelve el pigmento que ha quedado: blanco con alfa. El
  /// [grano] (el diente del papel) va en píxeles.
  ui.Image hornear(
    int ancho,
    int alto,
    void Function(Canvas c) dibujo, {
    required int semilla,
    double grano = 2.4,
  }) {
    final grabadora = ui.PictureRecorder();
    dibujo(Canvas(grabadora));
    final presion = grabadora.endRecording().toImageSync(ancho, alto);
    final shader = _programa.fragmentShader()
      ..setFloat(0, ancho.toDouble())
      ..setFloat(1, alto.toDouble())
      ..setFloat(2, (semilla % 997) / 997)
      ..setFloat(3, grano)
      ..setImageSampler(0, presion);
    final g2 = ui.PictureRecorder();
    Canvas(g2).drawRect(
      Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
      Paint()..shader = shader,
    );
    return g2.endRecording().toImageSync(ancho, alto);
  }
}
