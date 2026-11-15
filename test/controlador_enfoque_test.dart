import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppLifecycleState;

import 'package:enfoque_app_mobile/models/enfoque.dart';
import 'package:enfoque_app_mobile/services/api_service_enfoque.dart';
import 'package:enfoque_app_mobile/services/cola_envios.dart';
import 'package:enfoque_app_mobile/services/controlador_enfoque.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'falsos.dart';

/// El paso de una sesión acabada en el motor del core a la cola de envíos,
/// con el motor real y relojes falsos.
void main() {
  late RelojFalso reloj;
  late PantallaFalsa pantalla;
  late ApiFalsa api;
  int? usuario;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reloj = RelojFalso();
    pantalla = PantallaFalsa();
    api = ApiFalsa();
    usuario = 7;
  });

  ({MotorSesion motor, ColaEnvios cola, ControladorEnfoque c}) montar(
    WidgetTester tester, {
    AlmacenCola almacen = const AlmacenPreferencias(),
  }) {
    final motor = MotorSesion(
      reloj: reloj,
      pantalla: pantalla,
      binding: tester.binding,
    );
    addTearDown(motor.dispose);
    final cola = ColaEnvios(
      api: api,
      usuarioActual: () async => usuario,
      programar: ProgramadorFalso().call,
      almacen: almacen,
    );
    final c = ControladorEnfoque(
      motor: motor,
      cola: cola,
      usuarioActual: () async => usuario,
    );
    return (motor: motor, cola: cola, c: c);
  }

  /// Deja correr las colas de futuros sin mover el reloj del motor.
  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
  }

  group('peticionDeSesion', () {
    SesionConcentracion empezada({DestinoDisponible? destino}) =>
        SesionConcentracion.preparar(
          duracionObjetivo: const Duration(minutes: 25),
          datosApp: datosAppDe(destino),
          clave: '3f2a8c1e-5b7d-4e9a-8c6f-1a2b3c4d5e6f',
        ).empezar(monoMs: 1000, ahoraUtc: DateTime.utc(2026, 11, 16, 8, 30));

    test('completada con destino', () {
      final s = empezada(destino: destinoLeer).actualizar(1000 + 25 * 60000);
      final p = peticionDeSesion(s)!;
      expect(p.toJson(), {
        'clave': '3f2a8c1e-5b7d-4e9a-8c6f-1a2b3c4d5e6f',
        'inicioUtc': '2026-11-16T08:30:00.000Z',
        'duracionSeg': 1500,
        'duracionObjetivoMin': 25,
        'estado': 'COMPLETADA',
        'destino': {'tipo': 'habito', 'id': 16},
      });
    });

    test('terminada: segundos hacia abajo', () {
      final s = empezada().terminar(1000 + 12 * 60000 + 59999);
      final p = peticionDeSesion(s)!;
      expect(p.estado, EstadoEnvio.terminada);
      expect(p.duracionSeg, 12 * 60 + 59);
      expect(p.minutos, 12);
      expect(p.conDestino, isFalse);
    });

    test('perdida: se envía con su destino y no suma', () {
      final s = empezada(destino: destinoLeer).rendirse(1000 + 3 * 60000);
      final p = peticionDeSesion(s)!;
      expect(p.estado, EstadoEnvio.perdida);
      expect(p.destinoId, 16);
      expect(p.minutos, 0);
    });

    test('descartada o activa: no se envía', () {
      expect(peticionDeSesion(empezada().terminar(1000 + 60000)), isNull);
      expect(peticionDeSesion(empezada()), isNull);
    });

    test('el destino va y vuelve por datosApp', () {
      expect(destinoDeDatos(datosAppDe(destinoLeer))!.nombre, 'Leer');
      expect(destinoDeDatos(datosAppDe(null)), isNull);
      expect(destinoDeDatos({'destino': 'roto'}), isNull);
    });
  });

  testWidgets('terminar con 10 min o más: se envía y se cierra en el motor', (
    tester,
  ) async {
    final m = montar(tester);
    await m.c.iniciar();
    await m.c.empezar(
      duracion: const Duration(minutes: 25),
      destino: destinoLeer,
    );
    reloj.avanzar(const Duration(minutes: 12));
    await m.motor.terminar();
    await asentar(tester);

    expect(api.enviadas.single.estado, EstadoEnvio.terminada);
    expect(api.enviadas.single.duracionSeg, 720);
    expect(api.enviadas.single.destinoId, 16);
    expect(m.c.resultado.value!.envio, EnvioResultado.enviada);
    expect(m.c.resultado.value!.destino!.nombre, 'Leer');
    expect(m.motor.sesion.value, isNull);
    expect(m.cola.pendientes.value, isEmpty);
    expect(m.c.refrescos.value, 1);
  });

  testWidgets('menos de 10 min: descartada, no se envía', (tester) async {
    final m = montar(tester);
    await m.c.iniciar();
    await m.c.empezar(duracion: const Duration(minutes: 25));
    reloj.avanzar(const Duration(minutes: 9, seconds: 59));
    await m.motor.terminar();
    await asentar(tester);

    expect(api.enviadas, isEmpty);
    expect(m.c.resultado.value!.envio, EnvioResultado.noSeEnvia);
    expect(m.c.resultado.value!.sesion.estado, EstadoSesion.descartada);
    expect(m.motor.sesion.value, isNull);
  });

  testWidgets('sin red: pendiente en la cola, y el motor queda libre para '
      'otra sesión', (tester) async {
    api.envioPorDefecto = (_) =>
        const EnvioFallido(ApiException(TipoErrorApi.sinConexion));
    final m = montar(tester);
    await m.c.iniciar();
    await m.c.empezar(duracion: const Duration(minutes: 10));
    reloj.avanzar(const Duration(minutes: 10));
    // La meta llega sola con el tic del motor.
    await tester.pump(const Duration(seconds: 1));
    await asentar(tester);

    expect(m.c.resultado.value!.envio, EnvioResultado.pendiente);
    expect(
      m.cola.pendientes.value.single.peticion.estado,
      EstadoEnvio.completada,
    );
    expect(m.motor.sesion.value, isNull);
    await m.c.empezar(duracion: const Duration(minutes: 15));
    expect(m.motor.sesion.value!.estado, EstadoSesion.corriendo);
    await m.motor.rendirse();
    await asentar(tester);
  });

  testWidgets('409: no aceptada, con el mensaje', (tester) async {
    api.envios.add(const EnvioRechazado(409, 'Se solapa'));
    final m = montar(tester);
    await m.c.iniciar();
    await m.c.empezar(duracion: const Duration(minutes: 25));
    reloj.avanzar(const Duration(minutes: 1));
    await m.motor.rendirse();
    await asentar(tester);

    expect(api.enviadas.single.estado, EstadoEnvio.perdida);
    expect(m.c.resultado.value!.envio, EnvioResultado.noAceptada);
    expect(m.c.resultado.value!.mensaje, 'Se solapa');
    expect(m.cola.noAceptados.value, hasLength(1));
  });

  testWidgets('salir de la app y no volver: perdida por salida, se envía', (
    tester,
  ) async {
    final m = montar(tester);
    await m.c.iniciar();
    await m.c.empezar(duracion: const Duration(minutes: 25));
    for (final p in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(p);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
    await asentar(tester);
    expect(m.motor.sesion.value!.estado, EstadoSesion.enGracia);
    reloj.avanzar(const Duration(seconds: 11));
    await tester.pump(const Duration(seconds: 11));
    await asentar(tester);

    expect(m.c.resultado.value!.sesion.motivoPerdida, MotivoPerdida.salida);
    expect(api.enviadas.single.estado, EstadoEnvio.perdida);
    for (final p in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(p);
      await tester.pump();
    }
    await asentar(tester);
  });

  testWidgets('sesión acabada que sigue en el motor al arrancar (el proceso '
      'murió antes de cerrarla): se recoge y se envía una sola vez', (
    tester,
  ) async {
    // Una primera ejecución que acaba la sesión pero muere sin enviarla.
    final s = SesionConcentracion.preparar(
      duracionObjetivo: const Duration(minutes: 10),
      clave: '11111111-2222-4333-8444-555555555555',
    ).empezar(monoMs: reloj.mono, ahoraUtc: reloj.utc);
    reloj.avanzar(const Duration(minutes: 11));
    final acabada = s.actualizar(reloj.mono);
    SharedPreferences.setMockInitialValues({
      'sesion_concentracion_actual': jsonEncode(acabada.toJson()),
    });

    final m = montar(tester);
    await m.c.iniciar();
    await asentar(tester);
    // Un segundo iniciar (otro login) no la manda otra vez.
    await m.c.iniciar();
    await asentar(tester);

    expect(api.enviadas.single.clave, '11111111-2222-4333-8444-555555555555');
    expect(api.enviadas.single.estado, EstadoEnvio.completada);
    expect(m.motor.sesion.value, isNull);
  });

  testWidgets('sin usuario: se queda en el motor hasta que lo haya', (
    tester,
  ) async {
    usuario = null;
    final m = montar(tester);
    await m.c.iniciar();
    await m.c.empezar(duracion: const Duration(minutes: 25));
    reloj.avanzar(const Duration(minutes: 15));
    await m.motor.terminar();
    await asentar(tester);
    expect(api.enviadas, isEmpty);
    expect(m.c.resultado.value!.envio, EnvioResultado.pendiente);
    expect(m.motor.sesion.value!.estado, EstadoSesion.terminada);

    usuario = 7;
    m.c.soltarResultado();
    await m.c.iniciar();
    await asentar(tester);
    expect(api.enviadas.single.estado, EstadoEnvio.terminada);
    expect(m.motor.sesion.value, isNull);
  });

  testWidgets('sin red: justo al acabar se puede empezar otra, sin esperar '
      'al envío', (tester) async {
    final puerta = Completer<void>();
    api.puertaEnvio = puerta;
    api.envioPorDefecto = (_) =>
        const EnvioFallido(ApiException(TipoErrorApi.sinConexion));
    final m = montar(tester);
    await m.c.iniciar();
    await m.c.empezar(duracion: const Duration(minutes: 10));
    reloj.avanzar(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    await asentar(tester);

    // El envío sigue colgado y la sesión ya no está en el motor.
    expect(api.enviadas, isEmpty);
    expect(m.motor.sesion.value, isNull);
    expect(m.cola.pendientes.value, hasLength(1));
    await m.c.empezar(duracion: const Duration(minutes: 15));
    expect(m.motor.sesion.value!.estado, EstadoSesion.corriendo);

    puerta.complete();
    await asentar(tester);
    expect(api.enviadas, hasLength(1));
    expect(m.c.resultado.value!.envio, EnvioResultado.pendiente);
    await m.motor.rendirse();
    await asentar(tester);
  });

  testWidgets('la cuenta cambia con la sesión en marcha: se encola con su '
      'dueño y no se envía con el token de otro', (tester) async {
    final m = montar(tester);
    await m.c.iniciar();
    await m.c.empezar(duracion: const Duration(minutes: 25));
    usuario = 8;
    reloj.avanzar(const Duration(minutes: 12));
    await m.motor.terminar();
    await asentar(tester);

    expect(api.enviadas, isEmpty);
    expect(m.cola.pendientes.value.single.usuarioId, 7);
    expect(m.motor.sesion.value, isNull);
    expect(m.c.resultado.value!.envio, EnvioResultado.pendiente);

    usuario = 7;
    await m.c.enviarPendientes();
    await asentar(tester);
    expect(api.enviadas.single.estado, EstadoEnvio.terminada);
  });

  testWidgets('si no se puede encolar, la sesión se queda en el motor y la '
      'recogida se reintenta', (tester) async {
    final almacen = AlmacenFalso()..escrituraDevuelve = false;
    final m = montar(tester, almacen: almacen);
    await m.c.iniciar();
    await m.c.empezar(duracion: const Duration(minutes: 25));
    reloj.avanzar(const Duration(minutes: 12));
    await m.motor.terminar();
    await asentar(tester);

    expect(m.motor.sesion.value!.estado, EstadoSesion.terminada);
    expect(m.cola.pendientes.value, isEmpty);
    expect(api.enviadas, isEmpty);
    expect(m.c.resultado.value!.envio, EnvioResultado.pendiente);

    almacen.escrituraDevuelve = true;
    await m.c.enviarPendientes();
    await asentar(tester);
    expect(m.motor.sesion.value, isNull);
    expect(api.enviadas.single.estado, EstadoEnvio.terminada);
    expect(m.c.resultado.value!.envio, EnvioResultado.enviada);
  });

  testWidgets('proceso muerto con la sesión ya enviada: al volver no se '
      'reenvía ni hay resultado que celebrar', (tester) async {
    final m = montar(tester);
    await m.c.iniciar();
    await m.c.empezar(
      duracion: const Duration(minutes: 25),
      destino: destinoLeer,
    );
    reloj.avanzar(const Duration(minutes: 25));
    await tester.pump(const Duration(seconds: 1));
    await asentar(tester);
    expect(api.enviadas, hasLength(1));
    m.motor.dispose();

    // Otra ejecución con lo que quedó guardado.
    final otra = montar(tester);
    await otra.c.iniciar();
    await asentar(tester);
    expect(api.enviadas, hasLength(1));
    expect(otra.c.resultado.value, isNull);
    expect(otra.cola.pendientes.value, isEmpty);
  });

  test('el dueño va y vuelve por datosApp', () {
    expect(usuarioDeDatos(datosAppDe(null, usuarioId: 7)), 7);
    expect(usuarioDeDatos(datosAppDe(destinoLeer)), isNull);
    expect(datosAppDe(null), isNull);
    expect(usuarioDeDatos({'usuarioId': 'x'}), isNull);
  });
}
