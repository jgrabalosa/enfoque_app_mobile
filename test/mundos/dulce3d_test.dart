import 'dart:ui' as ui;

import 'package:enfoque_app_mobile/mundos/escena_mundo.dart';
import 'package:enfoque_app_mobile/mundos/jardin/colocador_jardin.dart';
import 'package:enfoque_app_mobile/mundos/jardin/jardin_isometrico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kit de Dulce', () {
    test('trae cada planta en color y en boceto, y lo demás', () async {
      final kit = await KitJardin.cargar();
      for (final e in JardinIso.alturas.keys) {
        for (var v = 0; v < JardinIso.variantes; v++) {
          final color = kit.pieza('planta_${e}_$v');
          final boceto = kit.pieza('planta_${e}_$v', boceto: true);
          expect(color.boceto, isFalse);
          expect(boceto.boceto, isTrue, reason: '$e $v');
        }
      }
      for (final nombre in [
        'parterre_0',
        'cesped_0',
        'losa_0',
        'arbol_0',
        for (final t in TipoHitoJardin.values) 'hito_${t.name}',
      ]) {
        expect(kit.tiene(nombre), isTrue, reason: nombre);
      }
      kit.liberar();
    });
  });

  group('PlantasJardin', () {
    test('siempre las mismas, y las altas detrás', () {
      final a = PlantasJardin(ColocadorJardin(2026));
      final b = PlantasJardin(ColocadorJardin(2026));
      for (var m = 0; m < 30; m++) {
        final pa = a.de(m);
        final pb = b.de(m);
        for (var k = 0; k < 10; k++) {
          expect(pa[k].especie, pb[k].especie);
          expect(pa[k].suelo, pb[k].suelo);
        }
        // De atrás adelante (menor x − y primero), cada vez más bajas.
        final orden = [...pa]
          ..sort(
            (x, y) =>
                (x.suelo.dx - x.suelo.dy).compareTo(y.suelo.dx - y.suelo.dy),
          );
        for (var i = 1; i < orden.length; i++) {
          expect(
            JardinIso.alturas[orden[i].especie]!,
            lessThanOrEqualTo(JardinIso.alturas[orden[i - 1].especie]! + 0.06),
          );
        }
        // Un solo girasol por parterre.
        expect(pa.where((p) => p.especie == 'girasol'), hasLength(1));
      }
    });
  });

  group('Pintor Dulce 3D', () {
    test('pinta 1.000 plantas en los tres niveles', () async {
      final pintor = PintorJardin3D();
      await pintor.preparar();
      expect(pintor.aviso, isNull);
      const tamano = ui.Size(200, 400);
      final escena = EscenaJardinIso(ColocadorJardin(2026), 1000);
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
}
