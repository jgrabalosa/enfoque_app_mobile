import 'dart:ui';

import 'package:enfoque_app_mobile/mundos/laboratorio/medidor_fotogramas.dart';
import 'package:enfoque_app_mobile/mundos/vista_mundo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tamano = Size(400, 800);

  group('VistaMundo', () {
    const vista = VistaMundo(centro: Offset(100, -50), escala: 2);

    test('el centro del mundo cae en el centro de la pantalla', () {
      expect(
        vista.aPantalla(const Offset(100, -50), tamano),
        const Offset(200, 400),
      );
    });

    test('ir y volver de la pantalla deja el mismo punto', () {
      const p = Offset(37, 512);
      final ida = vista.aMundo(p, tamano);
      final vuelta = vista.aPantalla(ida, tamano);
      expect((vuelta - p).distance, lessThan(1e-9));
    });

    test('el zoom no mueve el punto que hay debajo de los dedos', () {
      const foco = Offset(80, 120);
      final antes = vista.aMundo(foco, tamano);
      final despues = vista.conEscala(5, foco, tamano);
      expect(despues.escala, 5);
      expect((despues.aMundo(foco, tamano) - antes).distance, lessThan(1e-9));
    });

    test('arrastrar mueve el mundo con el dedo', () {
      final movida = vista.movida(const Offset(20, 0));
      final p = vista.aPantalla(const Offset(0, 0), tamano);
      expect(
        movida.aPantalla(const Offset(0, 0), tamano),
        p + const Offset(20, 0),
      );
    });

    test('el viaje empieza y acaba donde toca, y el zoom va en logaritmo', () {
      const otra = VistaMundo(centro: Offset(0, 0), escala: 8);
      expect(vista.hacia(otra, 0).escala, closeTo(2, 1e-9));
      expect(vista.hacia(otra, 1).escala, closeTo(8, 1e-9));
      expect(vista.hacia(otra, 0.5).escala, closeTo(4, 1e-9));
      expect(vista.hacia(otra, 1).centro, Offset.zero);
    });

    test('lo visible se ensancha al alejarse', () {
      final cerca = vista.visible(tamano);
      expect(cerca.width, 200);
      expect(cerca.height, 400);
      expect(vista.visible(tamano, margen: 10).width, 220);
    });
  });

  group('MedidorFotogramas', () {
    test('sin datos, midiendo', () {
      expect(MedidorFotogramas().resumen, 'midiendo…');
    });

    test('la media y el peor 10 %', () {
      final m = MedidorFotogramas(capacidad: 10)
        ..anotar([for (var i = 1; i <= 10; i++) i.toDouble()]);
      expect(m.media, 5.5);
      expect(m.peor10, 9);
      expect(m.resumen, '5,5 ms · peor 10 % 9,0 ms');
    });

    test('solo guarda los últimos', () {
      final m = MedidorFotogramas(capacidad: 3)..anotar([100, 1, 1, 1]);
      expect(m.media, 1);
    });
  });
}
