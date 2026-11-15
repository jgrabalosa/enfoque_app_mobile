import 'package:enfoque_app_mobile/models/enfoque.dart';
import 'package:enfoque_app_mobile/models/enlace_entrada.dart';
import 'package:enfoque_app_mobile/screens/estadisticas_logica.dart';
import 'package:enfoque_app_mobile/screens/inicio_logica.dart';
import 'package:flutter_test/flutter_test.dart';

import 'datos_prueba.dart';

/// Las decisiones de Inicio y Estadísticas, sin widgets.
void main() {
  group('Duraciones', () {
    test('de 10 a 120, de 5 en 5, 25 por defecto', () {
      expect(Duraciones.porDefecto, 25);
      expect(Duraciones.rapidas, [15, 25, 45, 60]);
      expect(Duraciones.subir(25), 30);
      expect(Duraciones.bajar(25), 20);
      expect(Duraciones.bajar(10), 10);
      expect(Duraciones.subir(120), 120);
      expect(Duraciones.ajustar(7), 10);
      expect(Duraciones.ajustar(33), 30);
      expect(Duraciones.ajustar(500), 120);
    });

    test('todos los chips cumplen las reglas del backend', () {
      for (final m in Duraciones.rapidas) {
        expect(Duraciones.ajustar(m), m);
      }
    });
  });

  group('destino pedido por enlace', () {
    final otro = destinoLeer.conProgreso(0, 30);
    const meditar = DestinoDisponible(
      tipo: 'habito',
      id: 21,
      nombre: 'Meditar',
      minutosDia: 0,
      minutosObjetivo: 10,
    );

    test('está en la lista: ese', () {
      expect(
        destinoPedidoEn([
          meditar,
          destinoLeer,
        ], const DestinoPedido('habito', 16)),
        destinoLeer,
      );
    });

    test('no está (o es de otro tipo): null', () {
      expect(
        destinoPedidoEn([meditar], const DestinoPedido('habito', 16)),
        isNull,
      );
      expect(
        destinoPedidoEn([destinoLeer], const DestinoPedido('otro', 16)),
        isNull,
      );
    });

    test('al recargar se queda el mismo con su progreso nuevo', () {
      expect(elegidoTrasRecargar(otro, [meditar, destinoLeer]), destinoLeer);
      expect(elegidoTrasRecargar(destinoLeer, [meditar]), isNull);
      expect(elegidoTrasRecargar(null, [meditar]), isNull);
    });
  });

  group('FechasEstadisticas', () {
    test('la semana empieza el lunes', () {
      // Miércoles 18-nov-2026.
      final hoy = DateTime(2026, 11, 18, 22, 15);
      expect(FechasEstadisticas.lunes(hoy), DateTime(2026, 11, 16));
      expect(FechasEstadisticas.semana(hoy).first, DateTime(2026, 11, 16));
      expect(FechasEstadisticas.semana(hoy).last, DateTime(2026, 11, 22));
      expect(
        FechasEstadisticas.lunes(DateTime(2026, 11, 16)),
        DateTime(2026, 11, 16),
      );
      expect(
        FechasEstadisticas.lunes(DateTime(2026, 11, 22)),
        DateTime(2026, 11, 16),
      );
    });

    test('desde: lo que llegue antes, el lunes o el día 1', () {
      expect(
        FechasEstadisticas.desde(DateTime(2026, 11, 18)),
        DateTime(2026, 11, 1),
      );
      // Martes 1-dic: el lunes es del mes anterior.
      expect(
        FechasEstadisticas.desde(DateTime(2026, 12, 1)),
        DateTime(2026, 11, 30),
      );
    });

    test('nunca pasa de 62 días (tope del backend)', () {
      for (
        var d = DateTime(2026, 1, 1);
        d.year == 2026;
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        final dias = d.difference(FechasEstadisticas.desde(d)).inDays + 1;
        expect(dias, lessThanOrEqualTo(62), reason: '$d');
      }
    });

    test('siete días distintos aunque cambie la hora (29-mar-2026)', () {
      final semana = FechasEstadisticas.semana(DateTime(2026, 3, 25));
      expect(semana.map((d) => d.day), [23, 24, 25, 26, 27, 28, 29]);
    });
  });
}
