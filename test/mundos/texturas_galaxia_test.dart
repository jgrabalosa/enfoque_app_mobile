import 'dart:ui';

import 'package:enfoque_app_mobile/mundos/galaxia/texturas_galaxia.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que vio Quim en el móvil (16-nov): al alejarse, cada nebulosa y cada
/// cúmulo se veía dentro de un recuadro. Pasa si la luz llega al borde de su
/// imagen, o si las estrellas del atlas están pegadas. Aquí se vigila que el
/// borde de todo quede a oscuras.
void main() {
  Future<void> comprobar({required bool conShader}) async {
    final programa = conShader
        ? await FragmentProgram.fromAsset('shaders/nebulosa.frag')
        : null;
    final t = TexturasGalaxia.crear(nebulosa: programa);
    for (var i = 0; i < TexturasGalaxia.estrellasEnAtlas; i++) {
      final celda = t.rectEstrella(i);
      expect(
        await TexturasGalaxia.luzEnElBorde(t.estrellas, zona: celda),
        0,
        reason: 'estrella $i',
      );
      // Y el hueco alrededor del dibujo, también vacío.
      expect(
        await TexturasGalaxia.luzEnElBorde(
          t.estrellas,
          zona: celda.deflate(TexturasGalaxia.margenEstrella - 2),
        ),
        0,
        reason: 'hueco de la estrella $i',
      );
    }
    for (var i = 0; i < t.hitos.length; i++) {
      expect(
        await TexturasGalaxia.luzEnElBorde(t.hitos[i]),
        lessThanOrEqualTo(1 / 255),
        reason: 'hito $i',
      );
    }
    t.liberar();
  }

  testWidgets('con el shader de nebulosas, nada toca el borde', (tester) async {
    await tester.runAsync(() => comprobar(conShader: true));
  });

  testWidgets('sin él, tampoco', (tester) async {
    await tester.runAsync(() => comprobar(conShader: false));
  });
}
