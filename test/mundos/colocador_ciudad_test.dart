import 'package:enfoque_app_mobile/mundos/ciudad/colocador_ciudad.dart';
import 'package:enfoque_app_mobile/mundos/ciudad/escena_ciudad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const semillas = [1, 7, 2026, 1234, 99999, 31337, 424242, 123456789];

  group('ColocadorCiudad', () {
    test('la misma semilla da siempre la misma ciudad', () {
      final a = ColocadorCiudad(2026);
      final b = ColocadorCiudad(2026);
      for (var n = 0; n < 1000; n++) {
        expect(b.edificio(n).rect, a.edificio(n).rect);
        expect(b.edificio(n).altura, a.edificio(n).altura);
      }
    });

    test('manzanas de 10, y el décimo la cierra con cartel', () {
      final c = ColocadorCiudad(2026);
      for (var n = 0; n < 1000; n++) {
        final e = c.edificio(n);
        expect(e.manzana, n ~/ 10);
        expect(e.indice, n % 10);
        expect(e.cierra, n % 10 == 9);
        if (e.cierra) expect(e.tejado, TejadoCiudad.cartel);
      }
    });

    test('cada celda, una sola cosa; ni el centro ni el río', () {
      for (final semilla in semillas) {
        final c = ColocadorCiudad(semilla);
        final usadas = <(int, int)>{};
        for (var m = 0; m < 100; m++) {
          final celda = c.manzana(m).celda;
          expect(celda, isNot((0, 0)));
          expect(usadas.add(celda), isTrue, reason: 'semilla $semilla: $m');
        }
        for (final h in c.hitosCon(100)) {
          expect(usadas.add(h.celda), isTrue, reason: 'semilla $semilla');
        }
        for (final (i, j) in usadas) {
          final r = ColocadorCiudad.rectCelda(i, j);
          for (final p in [
            r.topLeft,
            r.topRight,
            r.bottomLeft,
            r.bottomRight,
            r.center,
          ]) {
            expect(c.enElRio(p), isFalse, reason: 'semilla $semilla: ($i, $j)');
          }
        }
      }
    });

    test('los edificios, dentro de su manzana y sin pisarse', () {
      for (final semilla in semillas) {
        final c = ColocadorCiudad(semilla);
        for (var m = 0; m < 100; m++) {
          final manzana = c.manzana(m);
          final es = manzana.edificios;
          expect(es, hasLength(10));
          for (var a = 0; a < es.length; a++) {
            expect(manzana.rect.contains(es[a].rect.topLeft), isTrue);
            expect(manzana.rect.contains(es[a].rect.bottomRight), isTrue);
            expect(es[a].rect.shortestSide, greaterThan(14));
            expect(es[a].altura, greaterThan(20));
            for (var b = a + 1; b < es.length; b++) {
              final cruce = es[a].rect.intersect(es[b].rect);
              expect(
                cruce.width <= 0 || cruce.height <= 0,
                isTrue,
                reason: 'semilla $semilla, manzana $m: $a y $b',
              );
            }
          }
        }
      }
    });

    test('un hito cada 4 manzanas completas, justo después de la cuarta', () {
      final c = ColocadorCiudad(2026);
      expect(c.hitosCon(3), isEmpty);
      expect(c.hitosCon(4), hasLength(1));
      expect(c.hitosCon(100), hasLength(25));
      expect(ColocadorCiudad.celdaDeManzana(3), 3);
      expect(ColocadorCiudad.celdaDeHito(0), 4);
      expect(ColocadorCiudad.celdaDeManzana(4), 5);
    });

    test('crece hacia fuera', () {
      final c = ColocadorCiudad(2026);
      expect(c.radioCon(100), greaterThan(c.radioCon(10)));
      expect(c.radioCon(10), greaterThan(c.radioCon(1)));
    });
  });

  group('EscenaCiudad', () {
    test('cuenta manzanas, hitos y calles', () {
      final c = ColocadorCiudad(2026);
      final vacia = EscenaCiudad(c, 0);
      expect(vacia.ocupadas, {(0, 0)});
      expect(vacia.calles, hasLength(4));

      final e = EscenaCiudad(c, 45);
      expect(e.completas, 4);
      expect(e.deLaUltima, 4);
      expect(e.enLaUltima, 5);
      expect(e.hitos, hasLength(1));
      // El centro, 5 manzanas y 1 hito.
      expect(e.ocupadas, hasLength(7));
      expect(e.calles.length, greaterThan(10));
      expect(e.nombreRegion(4), isNotEmpty);
    });
  });
}
