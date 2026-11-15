import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:enfoque_app_mobile/services/api_service_enfoque.dart';
import 'package:enfoque_app_mobile/services/desfase_servidor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'datos_prueba.dart';

/// Cómo se clasifica cada respuesta del backend al enviar una sesión, y qué
/// se pide en cada endpoint.
void main() {
  late List<http.Request> pedidas;

  ApiServiceEnfoque api(int codigo, String cuerpo) {
    pedidas = [];
    return ApiServiceEnfoque(
      baseUrl: 'https://ejemplo.test/api',
      cabeceras: () async => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer t',
      },
      cliente: MockClient((r) async {
        pedidas.add(r);
        return http.Response.bytes(utf8.encode(cuerpo), codigo);
      }),
    );
  }

  const cuerpo201 =
      '{"sesion":{"clave":"3f2a8c1e-5b7d-4e9a-8c6f-1a2b3c4d5e6f",'
      '"estado":"COMPLETADA"},"aporte":{"estado":"ACEPTADO","minutos":25,'
      '"monedas":10,"minutosDia":45,"minutosObjetivo":30,"logros":[]}}';

  test('201: aceptada y nueva, con el cuerpo de la petición', () async {
    final r = await api(201, cuerpo201).enviarSesion(peticionDePrueba());
    expect(r, isA<EnvioAceptado>());
    final a = r as EnvioAceptado;
    expect(a.nueva, isTrue);
    expect(a.respuesta.aporte.monedas, 10);
    expect(pedidas.single.method, 'POST');
    expect(
      pedidas.single.url.toString(),
      'https://ejemplo.test/api/enfoque/sesiones',
    );
    expect(jsonDecode(pedidas.single.body), peticionDePrueba().toJson());
  });

  test('200 (la misma clave y cuerpo): aceptada, no nueva', () async {
    final r = await api(200, cuerpo201).enviarSesion(peticionDePrueba());
    expect((r as EnvioAceptado).nueva, isFalse);
  });

  test('2xx con un cuerpo que no se entiende: enviada igual', () async {
    final r = await api(201, 'no es json').enviarSesion(peticionDePrueba());
    expect(r, isA<EnvioAceptado>());
  });

  test('409: rechazada, definitiva, con el mensaje del backend', () async {
    final r = await api(
      409,
      '{"mensaje":"Ya hay otra sesión en ese tiempo"}',
    ).enviarSesion(peticionDePrueba());
    expect(r, isA<EnvioRechazado>());
    expect((r as EnvioRechazado).codigoHttp, 409);
    expect(r.mensaje, 'Ya hay otra sesión en ese tiempo');
  });

  test('400: rechazada; sin mensaje legible, null', () async {
    final r = await api(400, '<html>').enviarSesion(peticionDePrueba());
    expect((r as EnvioRechazado).codigoHttp, 400);
    expect(r.mensaje, isNull);
  });

  test('503: fallida (se reintenta)', () async {
    final r = await api(
      503,
      '{"mensaje":"Prueba en un rato"}',
    ).enviarSesion(peticionDePrueba());
    expect(r, isA<EnvioFallido>());
    expect((r as EnvioFallido).error.tipo, TipoErrorApi.servidor);
  });

  test('sin red: fallida', () async {
    final api = ApiServiceEnfoque(
      baseUrl: 'https://ejemplo.test/api',
      cabeceras: () async => const {},
      cliente: MockClient((_) async => throw http.ClientException('sin red')),
    );
    final r = await api.enviarSesion(peticionDePrueba());
    expect((r as EnvioFallido).error.tipo, TipoErrorApi.sinConexion);
  });

  test('404 u otro 4xx que no es 400 ni 409: no es definitivo', () async {
    final r = await api(404, '').enviarSesion(peticionDePrueba());
    expect(r, isA<EnvioFallido>());
  });

  test('resumen: pide desde y hasta como días', () async {
    final r = await api(
      200,
      '{"dias":[],"totalMinutos":5,"totalSesiones":1,"rachaActual":2}',
    ).resumen(DateTime(2026, 11, 2), DateTime(2026, 11, 16));
    expect(r.rachaActual, 2);
    expect(pedidas.single.url.path, '/api/enfoque/resumen');
    expect(pedidas.single.url.queryParameters, {
      'desde': '2026-11-02',
      'hasta': '2026-11-16',
    });
  });

  test('historial: pide la página y el tamaño', () async {
    await api(200, '{"sesiones":[]}').historial(pagina: 2, tamano: 20);
    expect(pedidas.single.url.queryParameters, {'pagina': '2', 'tamano': '20'});
  });

  test('destinos: un 500 lanza ApiException', () async {
    await expectLater(api(500, '').destinos(), throwsA(isA<ApiException>()));
  });

  test('mensajeDe', () {
    expect(mensajeDe('{"mensaje":" Hola "}'), 'Hola');
    expect(mensajeDe('{"mensaje":""}'), isNull);
    expect(mensajeDe('[]'), isNull);
    expect(mensajeDe(''), isNull);
  });

  test('cada respuesta apunta la hora del servidor (cabecera Date)', () async {
    SharedPreferences.setMockInitialValues({});
    final movil = DateTime.utc(2026, 11, 16, 9);
    final desfase = DesfaseServidor();
    final api = ApiServiceEnfoque(
      baseUrl: 'https://ejemplo.test/api',
      cabeceras: () async => const {},
      desfase: desfase,
      ahoraUtc: () => movil,
      cliente: MockClient(
        (_) async => http.Response(
          '{"destinos":[]}',
          200,
          headers: {
            'content-type': 'application/json',
            'date': HttpDate.format(movil.add(const Duration(minutes: 4))),
          },
        ),
      ),
    );
    await api.destinos();
    expect(desfase.desfase, const Duration(minutes: 4));
    // También en el envío de una sesión, aunque sea un error.
    await api.enviarSesion(peticionDePrueba());
    expect(desfase.desfase, const Duration(minutes: 4));
  });
}
