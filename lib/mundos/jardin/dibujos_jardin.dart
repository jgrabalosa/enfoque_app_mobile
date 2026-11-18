import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'package:google_fonts/google_fonts.dart';

import '../azar.dart';
import 'colocador_jardin.dart';
import 'lapiz_realista.dart';
import 'paleta_dulce.dart';

/// Una capa de un dibujo a lápiz: todo lo que va de un mismo color.
class CapaLapiz {
  const CapaLapiz(this.color, this.dibujo);

  final Color color;

  /// Dibuja la presión de esta capa, en unidades del mundo.
  final void Function(Canvas c) dibujo;
}

/// Un dibujo del jardín (el árbol, un parterre, un camino, un hito): dónde
/// cae en el mundo y sus capas, una por color.
class DibujoJardin {
  const DibujoJardin(this.mundo, this.capas);

  final Rect mundo;
  final List<CapaLapiz> capas;
}

/// Los dibujos del jardín, aparte de las flores. Todo en unidades del mundo:
/// el grosor de la mina es [_mina] (más o menos lo que mide en las flores).
abstract final class DibujosJardin {
  static const double _mina = 0.8;
  static const double _rayas = 0.9;

  static final Paint _borrar = Paint()..blendMode = BlendMode.clear;

  // ── El árbol del centro ────────────────────────────────────────────────

  static DibujoJardin arbol(int semilla) {
    const r = ColocadorJardin.radioArbol;
    final copa = _copa(Offset.zero, r, semilla);
    final sombra = _copa(Offset(r * 0.22, r * 0.28), r * 0.98, semilla);
    final grupos = [
      for (var k = 0; k < 7; k++)
        _copa(
          Offset.fromDirection(
            k * 0.9 + azarMundo(semilla, k, 3) * 6,
            r * 0.45,
          ),
          r * 0.32,
          semilla + k + 1,
          bultos: 6,
        ),
    ];
    // La luz viene de arriba a la izquierda: abajo a la derecha, más oscuro.
    double lado(Offset p) => (0.5 + (p.dx + p.dy) / (r * 2.6)).clamp(0.0, 1.0);
    return DibujoJardin(Rect.fromCircle(center: Offset.zero, radius: r * 1.5), [
      CapaLapiz(PaletaDulce.grafito, (c) {
        Lapiz.rayado(
          c,
          sombra,
          semilla: semilla + 10,
          separacion: _rayas * 1.2,
          ancho: _mina,
          presion: (_) => 0.5,
        );
        c.drawPath(copa, _borrar);
        Lapiz.contorno(
          c,
          copa,
          semilla: semilla + 11,
          ancho: _mina,
          presion: 0.65,
        );
        for (final (k, g) in grupos.indexed) {
          Lapiz.contorno(
            c,
            g,
            semilla: semilla + 20 + k,
            ancho: _mina * 0.8,
            presion: 0.35,
            desde: 0.1,
            hasta: 0.55,
            pasadas: 1,
          );
        }
      }),
      CapaLapiz(PaletaDulce.verdes[2], (c) {
        Lapiz.rayado(
          c,
          copa,
          semilla: semilla + 30,
          separacion: _rayas,
          ancho: _mina * 1.1,
          presion: (p) => 0.55 + 0.25 * lado(p),
        );
      }),
      CapaLapiz(PaletaDulce.verdes[1], (c) {
        Lapiz.rayado(
          c,
          copa,
          semilla: semilla + 40,
          separacion: _rayas * 1.2,
          ancho: _mina * 1.1,
          angulo: Lapiz.anguloMano + 0.4,
          presion: (p) => (lado(p) - 0.25) * 1.2,
        );
        for (final (k, g) in grupos.indexed) {
          Lapiz.rayado(
            c,
            g,
            semilla: semilla + 50 + k,
            separacion: _rayas * 1.4,
            ancho: _mina,
            presion: (p) => 0.25 + 0.4 * lado(p),
          );
        }
      }),
    ]);
  }

  /// Una copa de árbol vista desde arriba: un círculo con bultos.
  static Path _copa(Offset c, double r, int semilla, {int bultos = 11}) {
    final fase = azarMundo(semilla, 0, 5) * 6;
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final a = i / 120 * 2 * math.pi;
      final b = math.sin(bultos / 2 * a + fase).abs();
      final rr = r * (0.88 + 0.12 * math.pow(b, 0.6));
      final p = c + Offset.fromDirection(a, rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // ── Un parterre ────────────────────────────────────────────────────────

  static DibujoJardin parterre(
    Parterre p,
    int semilla, {
    required bool completo,
  }) {
    final s = semilla * 13 + p.numero * 101;
    final caja = p.forma.getBounds();
    return DibujoJardin(caja.inflate(70), [
      CapaLapiz(PaletaDulce.grafito, (c) {
        Lapiz.contorno(c, p.forma, semilla: s, ancho: _mina, presion: 0.6);
        _nombre(c, p.nombre, Offset(caja.center.dx, caja.bottom + 18), s);
      }),
      CapaLapiz(PaletaDulce.tierra, (c) {
        Lapiz.puntos(
          c,
          p.forma,
          semilla: s + 1,
          cuantos: 160,
          tamano: _mina * 1.1,
          presion: 0.55,
        );
      }),
      if (completo)
        CapaLapiz(PaletaDulce.verdes[0], (c) => _seto(c, p.forma, s + 2)),
    ]);
  }

  /// Un seto bajo alrededor del parterre: un garabato de lazos, como se
  /// dibuja el boj desde arriba.
  static void _seto(Canvas c, Path forma, int semilla) {
    for (final m in forma.computeMetrics()) {
      final puntos = <Offset>[];
      for (var s = 0.0; s < m.length; s += 0.8) {
        final t = m.getTangentForOffset(s)!;
        final dentro = Offset(-t.vector.dy, t.vector.dx);
        final a = s / 2.2;
        puntos.add(
          t.position +
              dentro * 4 +
              Offset(math.cos(a), math.sin(a)) *
                  (3.2 + azarMundo(semilla, s.floor(), 7)),
        );
      }
      Lapiz.trazo(
        c,
        puntos,
        semilla: semilla,
        ancho: _mina,
        presion: 0.6,
        puntas: 0.01,
      );
    }
  }

  static void _nombre(Canvas c, String nombre, Offset centro, int semilla) {
    final texto = TextPainter(
      text: TextSpan(
        text: nombre,
        style: GoogleFonts.caveat(
          textStyle: const TextStyle(
            color: Color(0xD9FFFFFF),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    c.save();
    c.translate(centro.dx, centro.dy);
    // Escrito a mano: un pelín torcido.
    c.rotate((azarMundo(semilla, 0, 9) - 0.5) * 0.08);
    texto.paint(c, Offset(-texto.width / 2, -texto.height / 2));
    c.restore();
    texto.dispose();
  }

  // ── Un camino de grava ─────────────────────────────────────────────────

  static DibujoJardin camino(Offset a, Offset b, int semilla) {
    final d = b - a;
    final largo = d.distance;
    final u = d / largo;
    final n = Offset(-u.dy, u.dx);
    final ra = a == Offset.zero
        ? ColocadorJardin.radioArbol * 0.92
        : ColocadorJardin.radioParterre * 0.95;
    const rb = ColocadorJardin.radioParterre * 0.95;
    final ini = a + u * ra;
    final fin = b - u * rb;
    const ancho = 15.0;
    final franja = Path()
      ..addPolygon([
        ini + n * ancho,
        fin + n * ancho,
        fin - n * ancho,
        ini - n * ancho,
      ], true);
    final s = semilla * 7 + (a.dx + b.dy).round();
    return DibujoJardin(Rect.fromPoints(ini, fin).inflate(ancho + 6), [
      CapaLapiz(PaletaDulce.grafito, (c) {
        for (final lado in [1.0, -1.0]) {
          Lapiz.trazo(
            c,
            [
              for (var k = 0; k <= 8; k++)
                Offset.lerp(ini, fin, k / 8)! + n * (ancho * lado),
            ],
            semilla: s + lado.round(),
            ancho: _mina,
            presion: 0.5,
            temblor: 0.8,
          );
        }
      }),
      CapaLapiz(PaletaDulce.grava, (c) {
        Lapiz.puntos(
          c,
          franja,
          semilla: s + 5,
          cuantos: (largo * ancho * 2 / 26).round(),
          tamano: _mina * 1.6,
          presion: 0.6,
        );
      }),
    ]);
  }

  // ── Los hitos ──────────────────────────────────────────────────────────

  static DibujoJardin hito(HitoJardin h, int semilla) {
    final s = semilla * 17 + h.numero * 131;
    final c0 = h.centro;
    return switch (h.tipo) {
      TipoHitoJardin.fuente => _fuente(c0, s),
      TipoHitoJardin.pergola => _pergola(c0, h.giro, s),
      TipoHitoJardin.banco => _banco(c0, h.giro, s),
      TipoHitoJardin.estanque => _estanque(c0, h.giro, s),
    };
  }

  /// Lo que queda a la sombra (abajo a la derecha) en una copa de radio
  /// [r] con centro [c0]: de 0 a 1.
  static double _sombra(Offset q, Offset c0, double r) =>
      (0.5 + ((q - c0).dx + (q - c0).dy) / (r * 2.6)).clamp(0.0, 1.0);

  static Path _circulo(Offset c, double r) =>
      Path()..addOval(Rect.fromCircle(center: c, radius: r));

  static DibujoJardin _fuente(Offset c0, int s) {
    final pilon = _circulo(c0, 74);
    final agua = _circulo(c0, 64);
    final pie = _circulo(c0, 13);
    return DibujoJardin(Rect.fromCircle(center: c0, radius: 110), [
      CapaLapiz(PaletaDulce.grafito, (c) {
        Lapiz.contorno(c, pilon, semilla: s, ancho: _mina, presion: 0.65);
        Lapiz.contorno(c, agua, semilla: s + 1, ancho: _mina, presion: 0.6);
        Lapiz.contorno(c, pie, semilla: s + 2, ancho: _mina, presion: 0.7);
        Lapiz.puntos(
          c,
          Path.combine(PathOperation.difference, pilon, agua),
          semilla: s + 3,
          cuantos: 90,
          tamano: _mina,
          presion: 0.5,
        );
        // Las ondas que salen del chorro.
        for (final (k, r) in [24.0, 36.0, 49.0].indexed) {
          Lapiz.contorno(
            c,
            _circulo(c0, r),
            semilla: s + 10 + k,
            ancho: _mina * 0.8,
            presion: 0.35,
            desde: 0.05 * k,
            hasta: 0.45 + 0.1 * k,
            pasadas: 1,
          );
        }
      }),
      CapaLapiz(PaletaDulce.agua, (c) {
        Lapiz.rayado(
          c,
          agua,
          semilla: s + 20,
          separacion: _rayas,
          ancho: _mina * 1.1,
          presion: (p) => 0.35 + 0.45 * ((p - c0).distance / 64),
        );
        c.drawPath(pie, _borrar);
      }),
    ]);
  }

  static DibujoJardin _pergola(Offset c0, double giro, int s) {
    final u = Offset.fromDirection(giro);
    final n = Offset(-u.dy, u.dx);
    const l = 66.0;
    Offset p(double x, double y) => c0 + u * x + n * y;
    final listones = [
      for (var k = 0; k < 7; k++)
        Path()..addPolygon([
          p(-l - 8, -l + k * 22 - 3),
          p(l + 8, -l + k * 22 - 3),
          p(l + 8, -l + k * 22 + 3),
          p(-l - 8, -l + k * 22 + 3),
        ], true),
    ];
    final vigas = [
      for (final y in [-l, l])
        Path()..addPolygon([
          p(y - 4, -l - 10),
          p(y + 4, -l - 10),
          p(y + 4, l + 10),
          p(y - 4, l + 10),
        ], true),
    ];
    final postes = [
      for (final x in [-l, l])
        for (final y in [-l, l]) _circulo(p(x, y), 6),
    ];
    final rosas = [
      for (var k = 0; k < 9; k++)
        _circulo(
          p(
            -l + azarMundo(s, k, 1) * l * 2,
            (azarMundo(s, k, 2) < 0.5 ? -l : l) +
                (azarMundo(s, k, 3) - 0.5) * 18,
          ),
          5 + azarMundo(s, k, 4) * 3,
        ),
    ];
    final hojas = [
      for (var k = 0; k < 22; k++)
        _circulo(
          p(
            -l + azarMundo(s, k, 5) * l * 2,
            (azarMundo(s, k, 6) < 0.5 ? -l : l) +
                (azarMundo(s, k, 7) - 0.5) * 28,
          ),
          4 + azarMundo(s, k, 8) * 4,
        ),
    ];
    return DibujoJardin(Rect.fromCircle(center: c0, radius: 120), [
      CapaLapiz(PaletaDulce.grafito, (c) {
        for (final (k, v) in [...vigas, ...listones, ...postes].indexed) {
          Lapiz.contorno(
            c,
            v,
            semilla: s + k,
            ancho: _mina * 0.9,
            presion: 0.55,
            pasadas: 1,
          );
        }
      }),
      CapaLapiz(PaletaDulce.madera, (c) {
        for (final (k, v) in [...vigas, ...listones].indexed) {
          Lapiz.rayado(
            c,
            v,
            semilla: s + 40 + k,
            separacion: _rayas,
            ancho: _mina,
            presion: (_) => 0.6,
          );
        }
      }),
      CapaLapiz(PaletaDulce.verdes[1], (c) {
        for (final (k, h) in hojas.indexed) {
          Lapiz.rayado(
            c,
            h,
            semilla: s + 80 + k,
            separacion: _rayas,
            ancho: _mina,
            presion: (_) => 0.7,
          );
        }
      }),
      CapaLapiz(PaletaDulce.lapices[0], (c) {
        for (final (k, r) in rosas.indexed) {
          Lapiz.rayado(
            c,
            r,
            semilla: s + 120 + k,
            separacion: _rayas * 0.8,
            ancho: _mina,
            presion: (_) => 0.85,
          );
        }
      }),
    ]);
  }

  static DibujoJardin _banco(Offset c0, double giro, int s) {
    final u = Offset.fromDirection(giro);
    final n = Offset(-u.dy, u.dx);
    Offset p(double x, double y) => c0 + u * x + n * y;
    final arbol = _copa(p(-14, -18), 58, s, bultos: 9);
    final sombra = _copa(p(-14 + 13, -18 + 16), 57, s, bultos: 9);
    final banco = Path()
      ..addPolygon([p(-34, 50), p(34, 50), p(34, 64), p(-34, 64)], true);
    final tablas = [
      for (final y in [53.5, 57.0, 60.5]) [p(-32, y), p(32, y)],
    ];
    final suelo = _circulo(p(0, 57), 44);
    return DibujoJardin(Rect.fromCircle(center: c0, radius: 120), [
      CapaLapiz(PaletaDulce.grafito, (c) {
        Lapiz.rayado(
          c,
          sombra,
          semilla: s,
          separacion: _rayas * 1.2,
          ancho: _mina,
          presion: (_) => 0.45,
        );
        c.drawPath(arbol, _borrar);
        Lapiz.contorno(c, arbol, semilla: s + 1, ancho: _mina, presion: 0.6);
        Lapiz.contorno(c, banco, semilla: s + 2, ancho: _mina, presion: 0.65);
        for (final (k, t) in tablas.indexed) {
          Lapiz.trazo(
            c,
            t,
            semilla: s + 3 + k,
            ancho: _mina * 0.7,
            presion: 0.35,
          );
        }
      }),
      CapaLapiz(PaletaDulce.grava, (c) {
        Lapiz.puntos(
          c,
          suelo,
          semilla: s + 10,
          cuantos: 70,
          tamano: _mina * 1.5,
          presion: 0.55,
        );
        c.drawPath(banco, _borrar);
        c.drawPath(arbol, _borrar);
      }),
      CapaLapiz(PaletaDulce.verdes[2], (c) {
        Lapiz.rayado(
          c,
          arbol,
          semilla: s + 20,
          separacion: _rayas,
          ancho: _mina * 1.1,
          presion: (q) => 0.55 + 0.25 * _sombra(q, c0, 60),
        );
      }),
      CapaLapiz(PaletaDulce.verdes[1], (c) {
        Lapiz.rayado(
          c,
          arbol,
          semilla: s + 25,
          separacion: _rayas * 1.2,
          ancho: _mina * 1.1,
          angulo: Lapiz.anguloMano + 0.4,
          presion: (q) => (_sombra(q, c0, 60) - 0.3) * 1.3,
        );
      }),
      CapaLapiz(PaletaDulce.madera, (c) {
        Lapiz.rayado(
          c,
          banco,
          semilla: s + 30,
          separacion: _rayas * 0.9,
          ancho: _mina,
          presion: (_) => 0.65,
        );
      }),
    ]);
  }

  static DibujoJardin _estanque(Offset c0, double giro, int s) {
    final fase = azarMundo(s, 0, 1) * 6;
    final agua = Path();
    for (var i = 0; i <= 90; i++) {
      final a = i / 90 * 2 * math.pi;
      final r =
          80 *
          (1 +
              0.12 * math.sin(2 * a + fase) +
              0.07 * math.sin(3 * a + fase * 2));
      final q = c0 + Offset.fromDirection(a, r);
      i == 0 ? agua.moveTo(q.dx, q.dy) : agua.lineTo(q.dx, q.dy);
    }
    agua.close();
    final u = Offset.fromDirection(giro);
    final n = Offset(-u.dy, u.dx);
    Offset p(double x, double y) => c0 + u * x + n * y;
    final puente = Path()
      ..addPolygon([p(-104, -13), p(104, -13), p(104, 13), p(-104, 13)], true);
    final nenufares = [
      for (var k = 0; k < 5; k++)
        _circulo(
          c0 +
              Offset.fromDirection(
                azarMundo(s, k, 2) * 6.28,
                30 + azarMundo(s, k, 3) * 30,
              ),
          7 + azarMundo(s, k, 4) * 4,
        ),
    ];
    return DibujoJardin(Rect.fromCircle(center: c0, radius: 125), [
      CapaLapiz(PaletaDulce.grafito, (c) {
        Lapiz.contorno(c, agua, semilla: s, ancho: _mina, presion: 0.6);
        for (final (k, h) in nenufares.indexed) {
          Lapiz.contorno(
            c,
            h,
            semilla: s + 5 + k,
            ancho: _mina * 0.8,
            presion: 0.45,
            pasadas: 1,
          );
        }
        c.drawPath(puente, _borrar);
        Lapiz.contorno(c, puente, semilla: s + 20, ancho: _mina, presion: 0.65);
        for (var k = 1; k < 16; k++) {
          final x = -104 + k * 13.0;
          Lapiz.trazo(
            c,
            [p(x, -12), p(x, 12)],
            semilla: s + 30 + k,
            ancho: _mina * 0.7,
            presion: 0.35,
          );
        }
      }),
      CapaLapiz(PaletaDulce.agua, (c) {
        Lapiz.rayado(
          c,
          agua,
          semilla: s + 40,
          separacion: _rayas,
          ancho: _mina * 1.1,
          presion: (q) => 0.3 + 0.5 * ((q - c0).distance / 90).clamp(0.0, 1.0),
        );
        for (final h in nenufares) {
          c.drawPath(h, _borrar);
        }
        c.drawPath(puente, _borrar);
      }),
      CapaLapiz(PaletaDulce.verdes[0], (c) {
        for (final (k, h) in nenufares.indexed) {
          Lapiz.rayado(
            c,
            h,
            semilla: s + 60 + k,
            separacion: _rayas * 0.9,
            ancho: _mina,
            presion: (_) => 0.7,
          );
        }
        c.drawPath(puente, _borrar);
      }),
      CapaLapiz(PaletaDulce.madera, (c) {
        Lapiz.rayado(
          c,
          puente,
          semilla: s + 80,
          separacion: _rayas,
          ancho: _mina,
          presion: (_) => 0.55,
          angulo: giro + 1.4,
        );
      }),
    ]);
  }
}
