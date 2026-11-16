import 'dart:convert';

import 'package:enfoque_app_mobile/models/enfoque.dart';
import 'package:flutter_test/flutter_test.dart';

/// El parseo de las respuestas del contrato de /api/enfoque, con cuerpos
/// como los que monta EnfoqueController (habitos-app, rama wip-enfoque).
void main() {
  group('destinos', () {
    test('la respuesta del contrato', () {
      final d = destinosDe(
        jsonDecode(
          '{"destinos":[{"tipo":"habito","id":16,"nombre":"Leer",'
          '"minutosDia":25,"minutosObjetivo":30}]}',
        ),
      );
      expect(d, hasLength(1));
      expect(d.single.tipo, 'habito');
      expect(d.single.id, 16);
      expect(d.single.nombre, 'Leer');
      expect(d.single.minutosDia, 25);
      expect(d.single.minutosObjetivo, 30);
    });

    test('se salta lo que no tiene tipo o id, y tolera tipos raros', () {
      final d = destinosDe(
        jsonDecode(
          '{"destinos":[{"tipo":"habito"},{"id":3},'
          '{"tipo":"habito","id":"4","nombre":null,"minutosDia":2.0},'
          '"basura",null]}',
        ),
      );
      expect(d, hasLength(1));
      expect(d.single.id, 4);
      expect(d.single.nombre, '');
      expect(d.single.minutosDia, 2);
      expect(d.single.minutosObjetivo, 0);
    });

    test('sin lista, vacía', () {
      expect(destinosDe(jsonDecode('{}')), isEmpty);
      expect(destinosDe(null), isEmpty);
    });
  });

  group('POST /sesiones', () {
    const cuerpo201 = '''
{"sesion":{"id":41,"clave":"3f2a8c1e-5b7d-4e9a-8c6f-1a2b3c4d5e6f",
"inicioUtc":"2026-11-16T08:30:00Z","duracionSeg":1500,"duracionObjetivoMin":25,
"estado":"COMPLETADA","dia":"2026-11-16","minutos":25,
"destino":{"tipo":"habito","id":16},"creadoEn":"2026-11-16T08:55:03.120Z"},
"aporte":{"estado":"ACEPTADO","motivo":null,"motivoTexto":null,"minutos":25,
"monedas":10,"xp":5,"minutosDia":45,"minutosObjetivo":30,"diaHecho":true,
"logros":["RACHA_3","MASCOTA_CRIA"]}}''';

    test('la respuesta 201 del contrato', () {
      final r = RespuestaSesion.fromJson(jsonDecode(cuerpo201));
      expect(r.sesion!.clave, '3f2a8c1e-5b7d-4e9a-8c6f-1a2b3c4d5e6f');
      expect(r.sesion!.inicioUtc, DateTime.utc(2026, 11, 16, 8, 30));
      expect(r.sesion!.estado, EstadoEnvio.completada);
      expect(r.sesion!.dia, DateTime(2026, 11, 16));
      expect(r.sesion!.minutos, 25);
      expect(r.sesion!.destinoTipo, 'habito');
      expect(r.sesion!.destinoId, 16);
      expect(r.aporte.estado, EstadoAporte.aceptado);
      expect(r.aporte.minutos, 25);
      expect(r.aporte.monedas, 10);
      expect(r.aporte.xp, 5);
      expect(r.aporte.minutosDia, 45);
      expect(r.aporte.minutosObjetivo, 30);
      expect(r.aporte.diaHecho, isTrue);
      expect(r.aporte.logros, ['RACHA_3', 'MASCOTA_CRIA']);
    });

    test('rechazado con su motivo traducido', () {
      final r = RespuestaSesion.fromJson(
        jsonDecode(
          '{"sesion":{"clave":"a","estado":"PERDIDA","destino":null},'
          '"aporte":{"estado":"RECHAZADO",'
          '"motivo":"enfoque.aporte.sesion.perdida",'
          '"motivoTexto":"La sesión se perdió","minutos":0,"monedas":0,'
          '"xp":0,"minutosDia":null,"minutosObjetivo":null,'
          '"diaHecho":null,"logros":[]}}',
        ),
      );
      expect(r.sesion!.estado, EstadoEnvio.perdida);
      expect(r.sesion!.destinoId, isNull);
      expect(r.aporte.estado, EstadoAporte.rechazado);
      expect(r.aporte.motivo, 'enfoque.aporte.sesion.perdida');
      expect(r.aporte.motivoTexto, 'La sesión se perdió');
      expect(r.aporte.minutosDia, isNull);
      expect(r.aporte.diaHecho, isNull);
    });

    test('el premio de la sesión (V27), aparte del aporte', () {
      final r = RespuestaSesion.fromJson(
        jsonDecode(
          '{"sesion":{"clave":"a","estado":"COMPLETADA","destino":null},'
          '"aporte":{"estado":"SIN_DESTINO","minutos":0,"monedas":0,"xp":0,'
          '"logros":[]},'
          '"premio":{"monedas":30,"xp":5,'
          '"logros":["ENFOQUE_PRIMERA_SESION","MASCOTA_CRIA"],'
          '"topeAlcanzado":true}}',
        ),
      );
      expect(r.aporte.estado, EstadoAporte.sinDestino);
      expect(r.aporte.monedas, 0);
      expect(r.premio.monedas, 30);
      expect(r.premio.xp, 5);
      expect(r.premio.logros, ['ENFOQUE_PRIMERA_SESION', 'MASCOTA_CRIA']);
      expect(r.premio.topeAlcanzado, isTrue);
    });

    test('sin premio (un backend anterior a V27), vacío', () {
      final r = RespuestaSesion.fromJson(jsonDecode(cuerpo201));
      expect(r.premio.monedas, 0);
      expect(r.premio.xp, 0);
      expect(r.premio.logros, isEmpty);
      expect(r.premio.topeAlcanzado, isFalse);
    });

    test('un premio raro no rompe', () {
      final p = Premio.fromJson({
        'monedas': '12',
        'xp': null,
        'logros': ['A', 3, '', null],
        'topeAlcanzado': 'sí',
      });
      expect(p.monedas, 12);
      expect(p.xp, 0);
      expect(p.logros, ['A']);
      expect(p.topeAlcanzado, isFalse);
      expect(Premio.fromJson(null).monedas, 0);
    });

    test('un estado de aporte desconocido no rompe', () {
      final a = Aporte.fromJson({'estado': 'NUEVO_ESTADO', 'logros': 3});
      expect(a.estado, EstadoAporte.desconocido);
      expect(a.logros, isEmpty);
      expect(Aporte.fromJson(null).estado, EstadoAporte.desconocido);
    });

    test('el cuerpo de la petición es el del contrato', () {
      final p = PeticionSesion(
        clave: '3f2a8c1e-5b7d-4e9a-8c6f-1a2b3c4d5e6f',
        inicioUtc: DateTime.utc(2026, 11, 16, 8, 30, 0, 123),
        duracionSeg: 1500,
        duracionObjetivoMin: 25,
        estado: EstadoEnvio.terminada,
        destinoTipo: 'habito',
        destinoId: 16,
      );
      expect(p.toJson(), {
        'clave': '3f2a8c1e-5b7d-4e9a-8c6f-1a2b3c4d5e6f',
        'inicioUtc': '2026-11-16T08:30:00.123Z',
        'duracionSeg': 1500,
        'duracionObjetivoMin': 25,
        'estado': 'TERMINADA',
        'destino': {'tipo': 'habito', 'id': 16},
      });
    });

    test('sin destino, destino null', () {
      final p = PeticionSesion(
        clave: 'c',
        inicioUtc: DateTime.utc(2026, 11, 16),
        duracionSeg: 30,
        duracionObjetivoMin: 10,
        estado: EstadoEnvio.perdida,
      );
      expect(p.toJson()['destino'], isNull);
      expect(p.toJson().containsKey('destino'), isTrue);
      expect(p.minutos, 0);
    });

    test('la petición vuelve igual de su JSON (la cola la guarda así)', () {
      final p = PeticionSesion(
        clave: 'k',
        inicioUtc: DateTime.utc(2026, 11, 16, 8, 30, 1, 5),
        duracionSeg: 659,
        duracionObjetivoMin: 15,
        estado: EstadoEnvio.terminada,
        destinoTipo: 'habito',
        destinoId: 9,
      );
      final otra = PeticionSesion.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(otra!.toJson(), p.toJson());
      expect(otra.minutos, 10);
    });
  });

  group('resumen', () {
    test('la respuesta del contrato', () {
      final r = ResumenEnfoque.fromJson(
        jsonDecode(
          '{"dias":[{"dia":"2026-11-16","minutos":50,"sesiones":2},'
          '{"dia":"2026-11-17","minutos":0,"sesiones":0}],'
          '"totalMinutos":50,"totalSesiones":2,"rachaActual":3}',
        ),
      );
      expect(r.dias, hasLength(2));
      expect(r.totalMinutos, 50);
      expect(r.totalSesiones, 2);
      expect(r.rachaActual, 3);
      expect(r.delDia(DateTime(2026, 11, 16)).minutos, 50);
      expect(r.delDia(DateTime(2026, 11, 16)).sesiones, 2);
      expect(r.delDia(DateTime(2026, 11, 20)).minutos, 0);
      expect(
        r.minutosEntre(DateTime(2026, 11, 16), DateTime(2026, 11, 17)),
        50,
      );
      expect(r.minutosEntre(DateTime(2026, 11, 17), DateTime(2026, 11, 17)), 0);
    });

    test('días rotos se saltan', () {
      final r = ResumenEnfoque.fromJson({
        'dias': [
          {'dia': 'no-es-fecha', 'minutos': 3},
          {'minutos': 3},
        ],
      });
      expect(r.dias, isEmpty);
      expect(r.rachaActual, 0);
    });
  });

  test('historial: la respuesta del contrato', () {
    final p = PaginaHistorial.fromJson(
      jsonDecode(
        '{"sesiones":[{"id":1,"clave":"a","inicioUtc":"2026-11-16T08:30:00Z",'
        '"duracionSeg":600,"duracionObjetivoMin":25,"estado":"TERMINADA",'
        '"dia":"2026-11-16","minutos":10,"destino":{"tipo":"habito","id":16},'
        '"creadoEn":"2026-11-16T08:41:00Z","aporte":{"estado":"ACEPTADO",'
        '"motivo":null,"motivoTexto":null,"minutos":10}},'
        '{"sinClave":true}],'
        '"pagina":0,"tamano":20,"total":1,"hayMas":false}',
      ),
    );
    expect(p.sesiones, hasLength(1));
    final s = p.sesiones.single;
    expect(s.estado, EstadoEnvio.terminada);
    expect(s.minutos, 10);
    expect(s.aporte.estado, EstadoAporte.aceptado);
    expect(s.aporte.minutos, 10);
    expect(p.total, 1);
    expect(p.hayMas, isFalse);
  });

  test('textoDia', () {
    expect(textoDia(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
