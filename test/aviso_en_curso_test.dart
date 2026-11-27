import 'dart:ui' show AppLifecycleState;

import 'package:flutter_test/flutter_test.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montaje.dart';

/// La notificación fija mientras hay sesión: se arranca al empezar y se para
/// en cuanto la sesión deja de estar activa. Con el motor real y relojes
/// falsos; el plugin, un falso.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// El fin de una sesión de 25 min empezada a la hora del [RelojFalso].
  const fin25 = '2026-11-16T09:25:00.000Z';

  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
  }

  Future<void> ciclo(WidgetTester tester, List<AppLifecycleState> pasos) async {
    for (final p in pasos) {
      tester.binding.handleAppLifecycleStateChanged(p);
      await tester.pump();
    }
  }

  testWidgets('arrancar la app sin sesión activa la para, una sola vez', (
    tester,
  ) async {
    final m = Montaje(tester);
    await m.motor.iniciar();
    m.controlador.vigilarEnCurso();
    await asentar(tester);
    expect(m.enCurso.llamadas, ['parar']);

    // HomeShell vuelve a iniciar: no la para otra vez.
    await m.controlador.iniciar();
    m.controlador.vigilarEnCurso();
    await asentar(tester);
    expect(m.enCurso.llamadas, ['parar']);
  });

  testWidgets('empezar una sesión la arranca con su fin, sin ronda; el '
      'tictac no la vuelve a arrancar', (tester) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.controlador.empezar(
      duracion: const Duration(minutes: 25),
      destino: destinoLeer,
    );
    await asentar(tester);
    m.reloj.avanzar(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await asentar(tester);
    expect(m.enCurso.llamadas, ['parar', 'arrancar $fin25 -']);
    await m.motor.rendirse();
    await asentar(tester);
  });

  testWidgets('cada ronda de una tanda la arranca con su ronda', (
    tester,
  ) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.tanda.empezar(rondas: 2, minutos: 25, descanso: 5);
    await asentar(tester);
    expect(m.enCurso.llamadas.last, 'arrancar $fin25 1/2');
    await m.motor.rendirse();
    await asentar(tester);
  });

  testWidgets('llegar a la meta la para', (tester) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.controlador.empezar(duracion: const Duration(minutes: 25));
    await asentar(tester);
    m.reloj.avanzar(const Duration(minutes: 25));
    await tester.pump(const Duration(seconds: 1));
    await asentar(tester);
    expect(
      m.controlador.resultado.value!.sesion.estado,
      EstadoSesion.completada,
    );
    expect(m.enCurso.llamadas, ['parar', 'arrancar $fin25 -', 'parar']);
  });

  testWidgets('terminar antes la para', (tester) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.controlador.empezar(duracion: const Duration(minutes: 25));
    await asentar(tester);
    m.reloj.avanzar(const Duration(minutes: 12));
    await m.motor.terminar();
    await asentar(tester);
    expect(
      m.controlador.resultado.value!.sesion.estado,
      EstadoSesion.terminada,
    );
    expect(m.enCurso.llamadas.last, 'parar');
  });

  testWidgets('rendirse la para', (tester) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.controlador.empezar(duracion: const Duration(minutes: 25));
    await asentar(tester);
    await m.motor.rendirse();
    await asentar(tester);
    expect(m.enCurso.llamadas, ['parar', 'arrancar $fin25 -', 'parar']);
  });

  testWidgets('en la gracia sigue; perderla por salir la para', (tester) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.controlador.empezar(duracion: const Duration(minutes: 25));
    await ciclo(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump(const Duration(milliseconds: 400));
    await asentar(tester);
    expect(m.motor.sesion.value!.estado, EstadoSesion.enGracia);
    expect(m.enCurso.llamadas, ['parar', 'arrancar $fin25 -']);

    m.reloj.avanzar(const Duration(seconds: 11));
    await tester.pump(const Duration(seconds: 11));
    await asentar(tester);
    expect(m.controlador.resultado.value!.sesion.estado, EstadoSesion.perdida);
    expect(m.enCurso.llamadas, ['parar', 'arrancar $fin25 -', 'parar']);
    await ciclo(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await asentar(tester);
  });

  testWidgets('en el descanso está parada, y la ronda siguiente la arranca', (
    tester,
  ) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.tanda.empezar(rondas: 2, minutos: 25, descanso: 5);
    await asentar(tester);
    m.reloj.avanzar(const Duration(minutes: 25));
    await tester.pump(const Duration(seconds: 1));
    await asentar(tester);
    expect(m.tanda.alAcabar(m.controlador.resultado.value!), isTrue);
    await asentar(tester);
    expect(m.tanda.restanteDescanso(), isNotNull);
    expect(m.enCurso.llamadas, ['parar', 'arrancar $fin25 1/2', 'parar']);

    m.controlador.soltarResultado();
    await m.tanda.siguienteRonda();
    await asentar(tester);
    expect(m.enCurso.llamadas.last, 'arrancar 2026-11-16T09:50:00.000Z 2/2');
    await m.motor.rendirse();
    await asentar(tester);
  });

  testWidgets('si el plugin falla (sin permiso de avisos), la sesión sigue '
      'igual', (tester) async {
    final m = Montaje(tester);
    m.enCurso.error = StateError('sin permiso');
    await m.controlador.iniciar();
    final s = await m.controlador.empezar(
      duracion: const Duration(minutes: 25),
    );
    await asentar(tester);
    expect(m.motor.sesion.value!.clave, s.clave);
    expect(m.motor.sesion.value!.estado, EstadoSesion.corriendo);
    await m.motor.rendirse();
    await asentar(tester);
    expect(m.enCurso.llamadas, ['parar', 'arrancar $fin25 -', 'parar']);
    expect(m.controlador.resultado.value!.sesion.estado, EstadoSesion.perdida);
  });
}
