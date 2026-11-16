import 'dart:ui' as ui;

import 'package:enfoque_app_mobile/mundos/ciudad/ciudad_isometrica.dart';
import 'package:enfoque_app_mobile/mundos/ciudad/colocador_ciudad.dart';
import 'package:enfoque_app_mobile/mundos/escena_mundo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Iso', () {
    test('del suelo a la pantalla y vuelta, sin perder nada', () {
      for (final p in const [
        ui.Offset(0, 0),
        ui.Offset(236, -472),
        ui.Offset(-1000, 37.5),
      ]) {
        final vuelta = Iso.alSuelo(Iso.de(p));
        expect((vuelta - p).distance, lessThan(1e-9));
      }
    });

    test('la diagonal x = y queda en horizontal; la otra, en vertical', () {
      expect(Iso.de(const ui.Offset(100, 100)).dy, closeTo(0, 1e-9));
      expect(Iso.de(const ui.Offset(100, -100)).dx, closeTo(0, 1e-9));
    });
  });

  group('Kit de Neotokyo+', () {
    test('carga los 48 edificios y la torre', () async {
      final kit = await KitNeotokyo.cargar();
      expect(kit.normales, hasLength(48));
      expect(kit.torre.torre, isTrue);
      for (final p in kit.piezas) {
        expect(p.fuente.right, lessThanOrEqualTo(kit.imagen.width));
        expect(p.fuente.bottom, lessThanOrEqualTo(kit.imagen.height));
      }
      kit.liberar();
    });

    test(
      'a cada edificio, siempre la misma pieza, y cabe en su parcela',
      () async {
        final kit = await KitNeotokyo.cargar();
        final colocador = ColocadorCiudad(2026);
        final vistas = <int>{};
        for (var n = 0; n < 200; n++) {
          final e = colocador.edificio(n);
          final (pieza, escala) = kit.elegir(e, colocador.semilla);
          final (otra, _) = kit.elegir(e, colocador.semilla);
          expect(identical(pieza, otra), isTrue);
          expect(
            pieza.ancho * escala * Iso.unidad,
            lessThanOrEqualTo(e.rect.width + 1e-6),
          );
          expect(
            pieza.fondo * escala * Iso.unidad,
            lessThanOrEqualTo(e.rect.height + 1e-6),
          );
          vistas.add(kit.piezas.indexOf(pieza));
        }
        // Que no salgan siempre las mismas.
        expect(vistas.length, greaterThan(15));
        kit.liberar();
      },
    );
  });

  group('Pintor de Blender', () {
    testWidgets('pinta 1.000 edificios en los tres niveles', (tester) async {
      await tester.runAsync(() async {
        final pintor = PintorCiudadBlender();
        await pintor.preparar();
        expect(pintor.aviso, isNull);
        const tamano = ui.Size(200, 400);
        final escena = EscenaCiudadIso(ColocadorCiudad(2026), 1000);
        for (final nivel in NivelZoom.values) {
          final grabadora = ui.PictureRecorder();
          pintor.pintar(
            ui.Canvas(grabadora),
            tamano,
            VistasMundo.de(nivel, escena, tamano),
            escena,
            segundos: 2,
            nueva: 999,
            aparicion: 0.5,
          );
          final imagen = await grabadora.endRecording().toImage(200, 400);
          final bytes = (await imagen.toByteData())!.buffer.asUint8List();
          var claros = 0;
          for (var i = 0; i < bytes.length; i += 4) {
            if (bytes[i] + bytes[i + 1] + bytes[i + 2] > 300) claros++;
          }
          expect(claros, greaterThan(20), reason: nivel.name);
        }
        pintor.liberar();
      });
    });
  });
}
