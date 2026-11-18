import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../azar.dart';
import 'lapiz_realista.dart';

/// Las flores del jardín, vistas desde arriba. Como las estrellas de la
/// galaxia, son redondas (pétalos alrededor de un centro), y eso es lo que
/// deja hacerlas bonitas por código.
enum EspecieFlor { margarita, cosmos, amapola, rosa, hortensia }

/// Una flor ya dibujada, en capas de pigmento (blanco con alfa) que se
/// colorean al pintarlas:
/// - [grafito]: el boceto (contornos y algo de sombra);
/// - [hojas], [petalos] y [centro]: el color, que se pone encima del boceto.
class FlorHorneada {
  FlorHorneada({
    required this.especie,
    required this.grafito,
    required this.hojas,
    required this.petalos,
    required this.centro,
  });

  final EspecieFlor especie;
  final ui.Image grafito;
  final ui.Image hojas;
  final ui.Image petalos;
  final ui.Image centro;

  void liberar() {
    for (final i in [grafito, hojas, petalos, centro]) {
      i.dispose();
    }
  }
}

/// Dibuja las flores (`hornear`) a [lado] píxeles, con la flor en el centro y
/// los pétalos hasta [radio] (las hojas asoman algo más).
abstract final class Flores {
  static const int lado = 256;
  static const double radio = 88;
  static const Offset _c = Offset(lado / 2, lado / 2);

  static FlorHorneada hornear(Pigmento pigmento, EspecieFlor e, int variante) {
    final sem = e.index * 1000 + variante * 37 + 11;
    final forma = _forma(e, sem);
    // Quien dibuja no colorea ni perfila lo que queda debajo de un pétalo:
    // cada pétalo, antes de dibujarse, borra lo que tiene debajo.
    final borrar = Paint()..blendMode = BlendMode.clear;
    void tapar(Canvas c, Path p) => c.drawPath(p, borrar);
    ui.Image capa(void Function(Canvas c) d, int s) =>
        pigmento.hornear(lado, lado, d, semilla: s);

    final hojas = capa((c) {
      for (final (k, h) in forma.hojas.indexed) {
        Lapiz.rayado(
          c,
          h,
          semilla: sem + 50 + k,
          separacion: 2.4,
          presion: (p) {
            final d = (p - _c).distance / (radio * 1.3);
            return (0.95 - 0.55 * d).clamp(0.25, 1.0);
          },
        );
      }
      for (final p in forma.petalos) {
        tapar(c, p);
      }
      tapar(c, forma.centro);
    }, sem + 1);

    final petalos = capa((c) {
      for (final (k, p) in forma.petalos.indexed) {
        tapar(c, p);
        double presion(Offset q) {
          final d = ((q - _c).distance / radio).clamp(0.0, 1.0);
          // Más oscuro en la base, donde le da la sombra de los demás.
          return forma.presionBase - forma.caida * math.pow(d, 0.8);
        }

        Lapiz.rayado(
          c,
          p,
          semilla: sem + 100 + k,
          separacion: forma.separacion,
          presion: presion,
        );
        // Una segunda capa, algo girada, como se va cargando el color.
        Lapiz.rayado(
          c,
          p,
          semilla: sem + 150 + k,
          separacion: forma.separacion * 1.3,
          angulo: Lapiz.anguloMano + 0.35,
          presion: (q) => presion(q) * 0.7,
        );
      }
      // Un segundo pase cruzado en la base, solo en las flores densas.
      if (forma.cruzado) {
        for (final (k, p) in forma.petalos.indexed) {
          Lapiz.rayado(
            c,
            p,
            semilla: sem + 300 + k,
            separacion: 3.2,
            angulo: Lapiz.anguloMano + 1.1,
            presion: (q) {
              final d = ((q - _c).distance / radio).clamp(0.0, 1.0);
              return (0.55 - 0.9 * d).clamp(0.0, 1.0);
            },
          );
        }
      }
    }, sem + 2);

    final centro = capa((c) {
      Lapiz.rayado(
        c,
        forma.centro,
        semilla: sem + 200,
        separacion: 2.0,
        presion: (_) => 0.75,
      );
      Lapiz.puntos(
        c,
        forma.centro,
        semilla: sem + 201,
        cuantos: forma.motas,
        tamano: 2.2,
        presion: 1,
      );
    }, sem + 3);

    final grafito = capa((c) {
      for (final (k, h) in forma.hojas.indexed) {
        Lapiz.contorno(c, h, semilla: sem + 400 + k, presion: 0.55, ancho: 1.6);
        final nervio = forma.nervios[k];
        Lapiz.trazo(
          c,
          nervio,
          semilla: sem + 450 + k,
          presion: 0.45,
          ancho: 1.4,
        );
      }
      for (final (k, p) in forma.petalos.indexed) {
        tapar(c, p);
        Lapiz.contorno(
          c,
          p,
          semilla: sem + 500 + k,
          presion: forma.presionContorno,
          ancho: 1.7,
          desde: forma.contornoDesde,
          hasta: forma.contornoHasta,
        );
        // Una sombra suave de grafito en la base de cada pétalo.
        Lapiz.rayado(
          c,
          p,
          semilla: sem + 600 + k,
          separacion: 3.4,
          ancho: 2.2,
          presion: (q) {
            final d = ((q - _c).distance / radio).clamp(0.0, 1.0);
            return (0.42 - 0.75 * d).clamp(0.0, 1.0);
          },
        );
      }
      for (final (k, l) in forma.lineas.indexed) {
        Lapiz.trazo(c, l, semilla: sem + 800 + k, presion: 0.4, ancho: 1.2);
      }
      Lapiz.contorno(
        c,
        forma.centro,
        semilla: sem + 700,
        presion: 0.7,
        ancho: 1.6,
      );
    }, sem + 4);

    return FlorHorneada(
      especie: e,
      grafito: grafito,
      hojas: hojas,
      petalos: petalos,
      centro: centro,
    );
  }

  // ── Las formas ─────────────────────────────────────────────────────────

  static _Forma _forma(EspecieFlor e, int sem) {
    double az(int k) => azarMundo(sem, k, 911);
    final giro = az(1) * math.pi * 2;
    final hojas = <Path>[];
    final nervios = <List<Offset>>[];
    final nHojas = 2 + (az(2) * 2).floor();
    for (var k = 0; k < nHojas; k++) {
      final a = giro + k * math.pi * 2 / nHojas + (az(10 + k) - 0.5) * 0.8;
      final largo = radio * (0.95 + az(20 + k) * 0.3);
      hojas.add(_hoja(a, radio * 0.35, largo, largo * 0.42));
      nervios.add([
        _c + _dir(a) * radio * 0.4,
        _c + _dir(a + 0.03) * (radio * 0.35 + largo * 0.6),
        _c + _dir(a) * (radio * 0.35 + largo * 0.9),
      ]);
    }

    switch (e) {
      case EspecieFlor.margarita:
        final n = 14 + (az(3) * 6).floor();
        return _Forma(
          hojas: hojas,
          nervios: nervios,
          petalos: [
            for (var k = 0; k < n; k++)
              _petalo(
                giro + k * math.pi * 2 / n + (az(30 + k) - 0.5) * 0.12,
                14,
                radio * (0.82 + az(60 + k) * 0.18) - 14,
                2 * math.pi * 30 / n * 0.95,
                redondez: 0.55,
              ),
          ],
          centro: _circulo(19),
          motas: 70,
          presionBase: 0.6,
          caida: 0.4,
          separacion: 3.4,
        );
      case EspecieFlor.cosmos:
        const n = 8;
        return _Forma(
          hojas: hojas,
          nervios: nervios,
          petalos: [
            for (var k = 0; k < n; k++)
              _petalo(
                giro + k * math.pi * 2 / n + (az(30 + k) - 0.5) * 0.15,
                10,
                radio * (0.85 + az(60 + k) * 0.15) - 10,
                38,
                redondez: 0.7,
                muescas: 3,
              ),
          ],
          lineas: [
            for (var k = 0; k < n; k++)
              for (final d in [-0.08, 0.0, 0.08])
                [
                  _c + _dir(giro + k * math.pi * 2 / n + d) * 16,
                  _c +
                      _dir(giro + k * math.pi * 2 / n + d * 1.4) * radio * 0.55,
                ],
          ],
          centro: _circulo(12),
          motas: 30,
          presionBase: 0.9,
          caida: 0.45,
        );
      case EspecieFlor.amapola:
        const n = 4;
        return _Forma(
          hojas: hojas,
          nervios: nervios,
          petalos: [
            for (var k = 0; k < n; k++)
              _petalo(
                giro + k * math.pi / 2 + (az(30 + k) - 0.5) * 0.2,
                6,
                radio * (0.9 + az(60 + k) * 0.1) - 6,
                radio * 1.05,
                redondez: 0.45,
                ondas: 0.06,
                fase: az(70 + k) * 10,
              ),
          ],
          lineas: [
            for (var k = 0; k < 14; k++)
              [
                _c + _dir(giro + k * 0.45) * 18,
                _c +
                    _dir(giro + k * 0.45 + 0.05) *
                        radio *
                        (0.5 + az(80 + k) * 0.3),
              ],
          ],
          centro: _circulo(15),
          motas: 40,
          presionBase: 1.0,
          caida: 0.4,
          cruzado: true,
        );
      case EspecieFlor.rosa:
        final petalos = <Path>[];
        for (final (anillo, (n, largo, ancho, desfase)) in [
          (5, 1.0, 1.15, 0.0),
          (5, 0.72, 0.95, 0.63),
          (4, 0.46, 0.75, 0.3),
          (3, 0.26, 0.55, 1.1),
        ].indexed) {
          for (var k = 0; k < n; k++) {
            petalos.add(
              _petalo(
                giro +
                    desfase +
                    k * math.pi * 2 / n +
                    (az(100 + anillo * 10 + k) - 0.5) * 0.2,
                4,
                radio * largo - 4,
                radio * ancho * largo,
                redondez: 0.42,
                ondas: 0.03,
                fase: az(140 + k) * 10,
              ),
            );
          }
        }
        return _Forma(
          hojas: hojas,
          nervios: nervios,
          petalos: petalos,
          centro: _espiral(giro),
          motas: 0,
          presionBase: 1.05,
          caida: 0.55,
          cruzado: true,
          contornoDesde: 0.28,
          contornoHasta: 0.72,
        );
      case EspecieFlor.hortensia:
        final petalos = <Path>[];
        for (var k = 0; k < 15; k++) {
          // Florecillas de cuatro pétalos, apiñadas en una bola.
          final r = radio * 0.68 * math.sqrt(k / 15);
          final a = k * 2.39996 + giro;
          final p = _c + _dir(a) * r;
          final g = az(200 + k) * math.pi;
          for (var j = 0; j < 4; j++) {
            petalos.add(
              _petalo(
                g + j * math.pi / 2,
                2,
                15 + az(220 + k) * 4,
                15,
                redondez: 0.5,
                centro: p,
              ),
            );
          }
        }
        return _Forma(
          hojas: hojas,
          nervios: nervios,
          petalos: petalos,
          centro: _circulo(4),
          motas: 0,
          presionBase: 0.85,
          caida: 0.3,
          separacion: 2.4,
          presionContorno: 0.38,
        );
    }
  }

  static Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

  /// Un pétalo que sale de [centro] en el ángulo [a]: de [r0] a [r0]+[largo],
  /// con su anchura máxima [ancho]. [redondez] cerca de 1 es puntiagudo; más
  /// bajo, redondo. [muescas], dientes en la punta (el cosmos); [ondas],
  /// borde ondulado (la amapola).
  static Path _petalo(
    double a,
    double r0,
    double largo,
    double ancho, {
    double redondez = 0.6,
    int muescas = 0,
    double ondas = 0,
    double fase = 0,
    Offset centro = _c,
  }) {
    final d = _dir(a);
    final n = Offset(-d.dy, d.dx);
    Offset punto(double x, double y) => centro + d * x + n * y;
    double hw(double t) {
      final base = math.pow(math.sin(math.pi * math.pow(t, 0.75)), redondez);
      final onda = 1 + ondas * math.sin(t * 14 + fase);
      return ancho / 2 * base * onda;
    }

    final lado1 = <Offset>[];
    final lado2 = <Offset>[];
    final fin = muescas > 0 ? 0.88 : 1.0;
    for (var i = 0; i <= 40; i++) {
      final t = fin * i / 40;
      lado1.add(punto(r0 + t * largo, hw(t)));
      lado2.add(punto(r0 + t * largo, -hw(t)));
    }
    final path = Path()..moveTo(lado1.first.dx, lado1.first.dy);
    for (final p in lado1.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (muescas > 0) {
      // La punta dentada: de un lado al otro, con [muescas] picos.
      final w = hw(fin);
      final x0 = r0 + fin * largo;
      for (var i = 0; i <= 24; i++) {
        final y = w - 2 * w * i / 24;
        final pico = (math.sin(muescas * math.pi * i / 24)).abs();
        path.lineTo(
          punto(x0 + largo * 0.1 * pico, y).dx,
          punto(x0 + largo * 0.1 * pico, y).dy,
        );
      }
    }
    for (final p in lado2.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static Path _hoja(double a, double r0, double largo, double ancho) {
    final d = _dir(a);
    final n = Offset(-d.dy, d.dx);
    final path = Path();
    final pts = <Offset>[];
    for (var i = 0; i <= 30; i++) {
      final t = i / 30;
      pts.add(
        _c +
            d * (r0 + t * largo) +
            n * (ancho / 2 * math.pow(math.sin(math.pi * t), 0.85)),
      );
    }
    for (var i = 30; i >= 0; i--) {
      final t = i / 30;
      pts.add(
        _c +
            d * (r0 + t * largo) -
            n * (ancho / 2 * math.pow(math.sin(math.pi * t), 0.85)),
      );
    }
    path.addPolygon(pts, true);
    return path;
  }

  static Path _circulo(double r) =>
      Path()..addOval(Rect.fromCircle(center: _c, radius: r));

  /// El corazón de la rosa: una espiral cerrada.
  static Path _espiral(double giro) {
    final path = Path();
    for (var i = 0; i <= 60; i++) {
      final t = i / 60;
      final a = giro + t * math.pi * 4;
      final r = 2 + t * 12;
      final p = _c + _dir(a) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }
}

class _Forma {
  _Forma({
    required this.hojas,
    required this.nervios,
    required this.petalos,
    required this.centro,
    required this.motas,
    required this.presionBase,
    required this.caida,
    this.lineas = const [],
    this.separacion = 2.6,
    this.cruzado = false,
    this.contornoDesde = 0,
    this.contornoHasta = 1,
    this.presionContorno = 0.6,
  });

  final List<Path> hojas;
  final List<List<Offset>> nervios;
  final List<Path> petalos;
  final Path centro;
  final int motas;
  final double presionBase;
  final double caida;
  final List<List<Offset>> lineas;
  final double separacion;
  final bool cruzado;
  final double contornoDesde;
  final double contornoHasta;
  final double presionContorno;
}
