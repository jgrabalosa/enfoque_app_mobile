import 'package:enfoque_app_mobile/models/enfoque.dart';
import 'package:enfoque_app_mobile/services/api_service_enfoque.dart';
import 'package:enfoque_app_mobile/services/cola_envios.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'falsos.dart';

const _fallo = EnvioFallido(
  ApiException(TipoErrorApi.servidor, codigoEstado: 503),
);
const _sinRed = EnvioFallido(ApiException(TipoErrorApi.sinConexion));
const _aceptada = EnvioAceptado(RespuestaSesion(), nueva: true);

/// La cola de sesiones sin conexión y el contrato de reintento del backend:
/// 5xx o sin respuesta = reintentar con la misma clave; 400 y 409 =
/// definitivos.
void main() {
  late ApiFalsa api;
  late ProgramadorFalso programador;
  late DateTime ahora;
  int? usuario;

  ColaEnvios nuevaCola() => ColaEnvios(
    api: api,
    usuarioActual: () async => usuario,
    ahora: () => ahora,
    programar: programador.call,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = ApiFalsa();
    programador = ProgramadorFalso();
    ahora = DateTime.utc(2026, 11, 16, 9);
    usuario = 7;
  });

  test('aceptada: sale de la cola', () async {
    final cola = nuevaCola();
    await cola.encolar(peticionDePrueba(), usuarioId: 7, destino: destinoLeer);
    expect(cola.pendientes.value, hasLength(1));
    await cola.procesar();
    expect(api.enviadas, hasLength(1));
    expect(cola.pendientes.value, isEmpty);
    expect(cola.resultadoDe(peticionDePrueba().clave), isA<EnvioAceptado>());
  });

  test('503: se queda, con espera creciente, y reintenta con la MISMA clave '
      'y el mismo cuerpo', () async {
    api.envios.addAll([_fallo, _fallo, _sinRed, _aceptada]);
    final cola = nuevaCola();
    await cola.encolar(peticionDePrueba(), usuarioId: 7);

    await cola.procesar();
    var e = cola.pendientes.value.single;
    expect(e.intentos, 1);
    expect(e.proximoIntentoUtc, ahora.add(const Duration(seconds: 30)));
    expect(programador.esperas.last, const Duration(seconds: 30));

    // Antes de su turno, sin forzar, no se envía.
    ahora = ahora.add(const Duration(seconds: 10));
    await cola.procesar();
    expect(api.enviadas, hasLength(1));

    // Llega su turno (lo dispara el temporizador programado).
    ahora = ahora.add(const Duration(seconds: 20));
    programador.acciones.last();
    await cola.procesar();
    e = cola.pendientes.value.single;
    expect(e.intentos, 2);
    expect(e.proximoIntentoUtc, ahora.add(const Duration(seconds: 60)));

    // Forzar (al volver a primer plano) no espera.
    await cola.procesar(forzar: true);
    expect(cola.pendientes.value.single.intentos, 3);
    expect(
      cola.pendientes.value.single.proximoIntentoUtc,
      ahora.add(const Duration(seconds: 120)),
    );

    await cola.procesar(forzar: true);
    expect(cola.pendientes.value, isEmpty);
    expect(api.enviadas, hasLength(4));
    expect(api.enviadas.map((p) => p.clave).toSet(), {
      peticionDePrueba().clave,
    });
    for (final cuerpo in api.cuerposEnviados) {
      expect(cuerpo, api.cuerposEnviados.first);
    }
  });

  test('la espera no pasa del máximo', () {
    final cola = nuevaCola();
    expect(cola.esperaTras(0), Duration.zero);
    expect(cola.esperaTras(1), const Duration(seconds: 30));
    expect(cola.esperaTras(4), const Duration(minutes: 4));
    expect(cola.esperaTras(7), const Duration(minutes: 30));
    expect(cola.esperaTras(500), const Duration(minutes: 30));
  });

  test('409: definitivo, sale de la cola y queda como no aceptada', () async {
    api.envios.add(const EnvioRechazado(409, 'Se solapa con otra sesión'));
    final cola = nuevaCola();
    await cola.encolar(peticionDePrueba(), usuarioId: 7, destino: destinoLeer);
    await cola.procesar();
    expect(cola.pendientes.value, isEmpty);
    final n = cola.noAceptados.value.single;
    expect(n.codigoHttp, 409);
    expect(n.mensaje, 'Se solapa con otra sesión');
    expect(n.destino!.nombre, 'Leer');
    // No se reintenta nunca.
    await cola.procesar(forzar: true);
    expect(api.enviadas, hasLength(1));
  });

  test('400: igual de definitivo', () async {
    api.envios.add(const EnvioRechazado(400, null));
    final cola = nuevaCola();
    await cola.encolar(peticionDePrueba(), usuarioId: 7);
    await cola.procesar();
    expect(cola.pendientes.value, isEmpty);
    expect(cola.noAceptados.value.single.codigoHttp, 400);
  });

  test('la misma clave no se encola dos veces', () async {
    final cola = nuevaCola();
    await cola.encolar(peticionDePrueba(), usuarioId: 7);
    await cola.encolar(peticionDePrueba(), usuarioId: 7);
    expect(cola.pendientes.value, hasLength(1));
  });

  test('sobrevive a reiniciar la app, con sus intentos', () async {
    api.envios.add(_fallo);
    final cola = nuevaCola();
    await cola.encolar(peticionDePrueba(), usuarioId: 7, destino: destinoLeer);
    await cola.procesar();

    final otra = nuevaCola();
    await otra.cargar();
    final e = otra.pendientes.value.single;
    expect(e.intentos, 1);
    expect(e.destino!.nombre, 'Leer');
    expect(e.peticion.toJson(), peticionDePrueba().toJson());
    await otra.procesar(forzar: true);
    expect(otra.pendientes.value, isEmpty);
    expect(api.cuerposEnviados.last, api.cuerposEnviados.first);
  });

  test('solo se envía lo del usuario con la sesión abierta', () async {
    final cola = nuevaCola();
    await cola.encolar(peticionDePrueba(clave: 'de-7'), usuarioId: 7);
    await cola.encolar(peticionDePrueba(clave: 'de-8'), usuarioId: 8);
    await cola.procesar(forzar: true);
    expect(api.enviadas.map((p) => p.clave), ['de-7']);
    expect(cola.pendientes.value.single.clave, 'de-8');

    usuario = null;
    await cola.procesar(forzar: true);
    expect(api.enviadas, hasLength(1));

    usuario = 8;
    await cola.procesar(forzar: true);
    expect(cola.pendientes.value, isEmpty);
  });

  test('por orden de llegada; un fallo no para a las demás', () async {
    api.envios.addAll([_fallo, _aceptada]);
    final cola = nuevaCola();
    await cola.encolar(peticionDePrueba(clave: 'a'), usuarioId: 7);
    await cola.encolar(peticionDePrueba(clave: 'b'), usuarioId: 7);
    await cola.procesar();
    expect(api.enviadas.map((p) => p.clave), ['a', 'b']);
    expect(cola.pendientes.value.single.clave, 'a');
  });

  test('dos procesar a la vez: ninguna se envía dos veces y la que llega '
      'durante el envío no se pierde', () async {
    final cola = nuevaCola();
    await cola.encolar(peticionDePrueba(clave: 'a'), usuarioId: 7);
    final primero = cola.procesar(forzar: true);
    await cola.encolar(peticionDePrueba(clave: 'b'), usuarioId: 7);
    final segundo = cola.procesar(forzar: true);
    await Future.wait([primero, segundo]);
    expect(api.enviadas.map((p) => p.clave), ['a', 'b']);
    expect(cola.pendientes.value, isEmpty);
  });

  test('un JSON guardado roto no tumba la cola', () async {
    SharedPreferences.setMockInitialValues({
      'enfoque_cola_envios': '[{"peticion":{"clave":3}}, "x", ',
    });
    final cola = nuevaCola();
    await cola.cargar();
    expect(cola.pendientes.value, isEmpty);
  });

  test(
    'la cuenta cambia a mitad de pasada: lo que queda ya no se envía',
    () async {
      final cola = nuevaCola();
      await cola.encolar(peticionDePrueba(clave: 'a'), usuarioId: 7);
      await cola.encolar(peticionDePrueba(clave: 'b'), usuarioId: 7);
      api.envioPorDefecto = (p) {
        usuario = 8;
        return _aceptada;
      };
      await cola.procesar(forzar: true);
      expect(api.enviadas.map((p) => p.clave), ['a']);
      expect(cola.pendientes.value.single.clave, 'b');
    },
  );

  group('persistencia', () {
    late AlmacenFalso almacen;
    ColaEnvios conAlmacen() => ColaEnvios(
      api: api,
      usuarioActual: () async => usuario,
      ahora: () => ahora,
      programar: programador.call,
      almacen: almacen,
    );
    setUp(() => almacen = AlmacenFalso());

    test('encolar devuelve true cuando queda guardada', () async {
      final cola = conAlmacen();
      expect(await cola.encolar(peticionDePrueba(), usuarioId: 7), isTrue);
      expect(almacen.datos['enfoque_cola_envios'], contains('3f2a8c1e'));
      // La misma clave otra vez: ya está guardada, true sin escribir.
      final escrituras = almacen.escrituras;
      expect(await cola.encolar(peticionDePrueba(), usuarioId: 7), isTrue);
      expect(almacen.escrituras, escrituras);
    });

    test('setString devuelve false: encolar false y nada en memoria', () async {
      almacen.escrituraDevuelve = false;
      final cola = conAlmacen();
      expect(await cola.encolar(peticionDePrueba(), usuarioId: 7), isFalse);
      expect(cola.pendientes.value, isEmpty);
    });

    test('escribir lanza: encolar relanza y nada en memoria', () async {
      almacen.escrituraLanza = true;
      final cola = conAlmacen();
      await expectLater(
        cola.encolar(peticionDePrueba(), usuarioId: 7),
        throwsStateError,
      );
      expect(cola.pendientes.value, isEmpty);
    });

    test('si no se pudo leer, no se escribe encima de lo guardado', () async {
      final previa = conAlmacen();
      await previa.encolar(peticionDePrueba(clave: 'vieja'), usuarioId: 7);

      // Falla el cargar de arriba y el que hace encolar por dentro.
      almacen.lecturasQueFallan = 2;
      final cola = conAlmacen();
      expect(await cola.cargar(), isFalse);
      expect(
        await cola.encolar(peticionDePrueba(clave: 'nueva'), usuarioId: 7),
        isFalse,
      );
      expect(almacen.datos['enfoque_cola_envios'], contains('vieja'));
      expect(almacen.datos['enfoque_cola_envios'], isNot(contains('nueva')));

      // La siguiente vez se lee bien y no se ha perdido nada.
      expect(
        await cola.encolar(peticionDePrueba(clave: 'nueva'), usuarioId: 7),
        isTrue,
      );
      expect(cola.pendientes.value.map((e) => e.clave), ['vieja', 'nueva']);
    });
  });
}
