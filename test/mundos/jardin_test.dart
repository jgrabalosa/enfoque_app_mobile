import 'dart:ui' as ui;

import 'package:enfoque_app_mobile/mundos/escena_mundo.dart';
import 'package:enfoque_app_mobile/mundos/jardin/colocador_jardin.dart';
import 'package:enfoque_app_mobile/mundos/jardin/escena_jardin.dart';
import 'package:enfoque_app_mobile/mundos/jardin/flores.dart';
import 'package:enfoque_app_mobile/mundos/jardin/lapiz_realista.dart';
import 'package:enfoque_app_mobile/mundos/jardin/pintor_jardin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ColocadorJardin', () {
    test('la misma semilla da siempre el mismo jardín', () {
      final a = ColocadorJardin(7);
      final b = ColocadorJardin(7);
      for (final n in [0, 9, 10, 555, 999]) {
        expect(a.flor(n).centro, b.flor(n).centro);
        expect(a.flor(n).especie, b.flor(n).especie);
        expect(a.flor(n).color, b.flor(n).color);
      }
    });

    test('parterres e hitos no se pisan, ni pisan el árbol', () {
      for (final semilla in [1, 2, 3, 2026]) {
        final c = ColocadorJardin(semilla);
        // 100 parterres y sus 25 hitos.
        final huecos = [for (var k = 0; k < 125; k++) c.centroHueco(k)];
        for (var i = 0; i < huecos.length; i++) {
          expect(
            huecos[i].distance,
            greaterThan(
              ColocadorJardin.radioArbol + ColocadorJardin.radioParterre * 1.2,
            ),
          );
          for (var j = 0; j < i; j++) {
            expect(
              (huecos[i] - huecos[j]).distance,
              greaterThan(ColocadorJardin.radioParterre * 2.5),
              reason: 'huecos $i y $j',
            );
          }
        }
      }
    });

    test(
      'cada flor, dentro de su parterre y sin montarse del todo en otra',
      () {
        final c = ColocadorJardin(2026);
        for (var m = 0; m < 100; m++) {
          final p = c.parterre(m);
          for (final f in p.flores) {
            expect((f.centro - p.centro).distance, lessThan(p.radio));
            for (final g in p.flores) {
              if (identical(f, g)) continue;
              expect(
                (f.centro - g.centro).distance,
                greaterThan(ColocadorJardin.radioFlor * 1.2),
              );
            }
          }
        }
      },
    );

    test('un hito cada 4 parterres completos', () {
      final c = ColocadorJardin(2026);
      expect(c.hitosCon(3), isEmpty);
      expect(c.hitosCon(4), hasLength(1));
      expect(c.hitosCon(100), hasLength(25));
    });
  });

  group('EscenaJardin', () {
    test('cuenta parterres, completos e hitos, y un camino por cada uno', () {
      final e = EscenaJardin(ColocadorJardin(2026), 47);
      expect(e.completas, 4);
      expect(e.deLaUltima, 4);
      expect(e.enLaUltima, 7);
      expect(e.completo(3), isTrue);
      expect(e.completo(4), isFalse);
      expect(e.hitos, hasLength(1));
      expect(e.caminos, hasLength(5 + 1));
    });
  });

  group('Lápiz', () {
    test('las flores dejan pigmento en todas sus capas', () async {
      final pigmento = await Pigmento.cargar();
      for (final especie in EspecieFlor.values) {
        final f = Flores.hornear(pigmento, especie, 0);
        for (final capa in [f.grafito, f.hojas, f.petalos, f.centro]) {
          final bytes = (await capa.toByteData())!.buffer.asUint8List();
          var conPigmento = 0;
          for (var i = 3; i < bytes.length; i += 4) {
            if (bytes[i] > 40) conPigmento++;
          }
          // El centro de la hortensia es diminuto.
          expect(conPigmento, greaterThan(10), reason: especie.name);
        }
        f.liberar();
      }
    });
  });

  group('Pintor a lápiz', () {
    testWidgets('pinta 1.000 flores en los tres niveles', (tester) async {
      await tester.runAsync(() async {
        final pintor = PintorJardinLapiz(densidad: 1);
        await pintor.preparar();
        expect(pintor.aviso, isNull);
        const tamano = ui.Size(200, 400);
        final escena = EscenaJardin(ColocadorJardin(2026), 1000);
        for (final nivel in NivelZoom.values) {
          final vista = VistasMundo.de(nivel, escena, tamano);
          late ui.Image imagen;
          // Lo que no son flores se dibuja poco a poco: unos fotogramas.
          for (var k = 0; k < 12; k++) {
            final grabadora = ui.PictureRecorder();
            pintor.pintar(
              ui.Canvas(grabadora),
              tamano,
              vista,
              escena,
              segundos: 2,
              nueva: 999,
              aparicion: 0.5,
            );
            final dibujo = grabadora.endRecording();
            if (k == 11) imagen = await dibujo.toImage(200, 400);
          }
          final bytes = (await imagen.toByteData())!.buffer.asUint8List();
          var conColor = 0;
          for (var i = 0; i < bytes.length; i += 4) {
            final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2];
            if ((r - g).abs() > 25 || (g - b).abs() > 25) conColor++;
          }
          expect(conColor, greaterThan(30), reason: nivel.name);
        }
        pintor.liberar();
      });
    });
  });
}
