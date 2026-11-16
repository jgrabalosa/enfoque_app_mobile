import 'package:enfoque_app_mobile/mundos/galaxia/colocador_galaxia.dart';
import 'package:enfoque_app_mobile/mundos/galaxia/escena_galaxia.dart';
import 'package:enfoque_app_mobile/mundos/galaxia/nombres_constelaciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const semillas = [1, 7, 2026, 1234, 99999, 31337, 424242, 123456789];

  group('ColocadorGalaxia', () {
    test('la misma semilla da siempre el mismo sitio', () {
      final a = ColocadorGalaxia(2026);
      final b = ColocadorGalaxia(2026);
      for (var n = 0; n < 1000; n++) {
        expect(b.estrella(n).posicion, a.estrella(n).posicion);
        expect(b.estrella(n).variante, a.estrella(n).variante);
      }
    });

    test('otra semilla, otra galaxia', () {
      final a = ColocadorGalaxia(2026);
      final b = ColocadorGalaxia(2027);
      var iguales = 0;
      for (var n = 0; n < 1000; n++) {
        if ((a.estrella(n).posicion - b.estrella(n).posicion).distance < 1) {
          iguales++;
        }
      }
      expect(iguales, lessThan(10));
    });

    test('constelaciones de 10, y la décima la cierra', () {
      final c = ColocadorGalaxia(2026);
      for (var n = 0; n < 1000; n++) {
        final e = c.estrella(n);
        expect(e.constelacion, n ~/ 10);
        expect(e.indice, n % 10);
        expect(e.cierra, n % 10 == 9);
      }
    });

    test('cada estrella se une a una anterior de su constelación', () {
      final c = ColocadorGalaxia(2026);
      for (var n = 0; n < 1000; n++) {
        final e = c.estrella(n);
        final union = e.unidaA;
        if (e.indice == 0) {
          expect(union, isNull);
          continue;
        }
        expect(union, isNotNull);
        expect(union! < n, isTrue);
        expect(union ~/ 10, e.constelacion);
      }
      // La rama (estrellas 7 a 9) sale de la 2, la 3 o la 4.
      for (var k = 0; k < 100; k++) {
        expect(c.constelacion(k).unionDe(7), inInclusiveRange(2, 4));
      }
    });

    test('lo nuevo sale hacia fuera, brazo a brazo', () {
      final c = ColocadorGalaxia(2026);
      for (var k = 0; k + ColocadorGalaxia.brazos < 100; k++) {
        final ahora = c.constelacion(k);
        final siguiente = c.constelacion(k + ColocadorGalaxia.brazos);
        expect(siguiente.brazo, ahora.brazo);
        expect(siguiente.centro.distance, greaterThan(ahora.centro.distance));
      }
      expect(c.constelacion(0).brazo, 0);
      expect(c.constelacion(1).brazo, 1);
      expect(c.constelacion(2).brazo, 2);
    });

    test('las figuras, centradas y sin pasar de su radio', () {
      final c = ColocadorGalaxia(2026);
      for (var k = 0; k < 100; k++) {
        final f = c.constelacion(k).figura;
        expect(f, hasLength(10));
        final centro = f.fold(Offset.zero, (a, b) => a + b) / 10;
        expect(centro.distance, lessThan(0.001));
        for (final p in f) {
          expect(
            p.distance,
            lessThanOrEqualTo(ColocadorGalaxia.radioFigura + 1e-9),
          );
        }
      }
    });

    test('con 1.000 piezas, ninguna estrella pisa a otra', () {
      for (final semilla in semillas) {
        final c = ColocadorGalaxia(semilla);
        final es = [for (var n = 0; n < 1000; n++) c.estrella(n)];
        for (var i = 0; i < es.length; i++) {
          for (var j = i + 1; j < es.length; j++) {
            final d = (es[i].posicion - es[j].posicion).distance;
            final misma = es[i].constelacion == es[j].constelacion;
            expect(
              d,
              greaterThan(misma ? 11 : 20),
              reason:
                  'semilla $semilla: ${es[i].numero} y ${es[j].numero} '
                  'a ${d.toStringAsFixed(1)}',
            );
          }
        }
      }
    });

    test('un hito cada 4 constelaciones completas', () {
      final c = ColocadorGalaxia(2026);
      expect(c.hitosCon(0), isEmpty);
      expect(c.hitosCon(3), isEmpty);
      expect(c.hitosCon(4).map((h) => h.constelacion), [3]);
      expect(c.hitosCon(25).map((h) => h.constelacion), [3, 7, 11, 15, 19, 23]);
      for (final h in c.hitosCon(100)) {
        expect(h.variante, inInclusiveRange(0, Hito.variantes - 1));
      }
    });
  });

  group('EscenaGalaxia', () {
    test('cuenta constelaciones y estrellas de la de hoy', () {
      final c = ColocadorGalaxia(2026);
      final casos = {
        0: (completas: 0, deLaUltima: 0, enLaUltima: 0),
        1: (completas: 0, deLaUltima: 0, enLaUltima: 1),
        10: (completas: 1, deLaUltima: 0, enLaUltima: 10),
        11: (completas: 1, deLaUltima: 1, enLaUltima: 1),
        1000: (completas: 100, deLaUltima: 99, enLaUltima: 10),
      };
      casos.forEach((cantidad, esperado) {
        final e = EscenaGalaxia(c, cantidad);
        expect(e.estrellas, hasLength(cantidad));
        expect(e.completas, esperado.completas, reason: '$cantidad');
        expect(e.deLaUltima, esperado.deLaUltima, reason: '$cantidad');
        expect(e.enLaUltima, esperado.enLaUltima, reason: '$cantidad');
      });
      expect(EscenaGalaxia(c, 0).ultima, isNull);
      expect(EscenaGalaxia(c, 37).ultima!.numero, 36);
    });

    test('la galaxia crece con las constelaciones', () {
      final c = ColocadorGalaxia(2026);
      expect(
        EscenaGalaxia(c, 1000).radio,
        greaterThan(EscenaGalaxia(c, 100).radio),
      );
      expect(
        EscenaGalaxia(c, 100).radio,
        greaterThan(EscenaGalaxia(c, 1).radio),
      );
    });
  });

  group('NombresConstelaciones', () {
    test('el mismo nombre con la misma semilla, y concordado', () {
      for (var k = 0; k < 100; k++) {
        final nombre = NombresConstelaciones.de(2026, k);
        expect(NombresConstelaciones.de(2026, k), nombre);
        expect(nombre, matches(RegExp(r'^(El|La) ')));
        expect(nombre, isNot(contains('La Farol')));
      }
      // Se repiten poco: más de 60 nombres distintos en 100 constelaciones.
      final distintos = {
        for (var k = 0; k < 100; k++) NombresConstelaciones.de(2026, k),
      };
      expect(distintos.length, greaterThan(60));
    });
  });
}
