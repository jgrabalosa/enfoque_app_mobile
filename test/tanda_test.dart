import 'package:enfoque_app_mobile/models/enfoque.dart';
import 'package:enfoque_app_mobile/services/api_service_enfoque.dart';
import 'package:enfoque_app_mobile/services/controlador_enfoque.dart';
import 'package:enfoque_app_mobile/services/tanda.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montaje.dart';

/// Las tandas de rondas, sin pantallas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('la tanda se guarda y se lee igual', () {
    final t = Tanda(
      rondas: 3,
      ronda: 2,
      minutos: 50,
      descanso: 10,
      destino: destinoLeer,
      finDescansoUtc: DateTime.utc(2026, 11, 18, 9, 30),
      claveRonda: 'abc',
    );
    final leida = Tanda.fromJson(t.toJson())!;
    expect(leida.rondas, 3);
    expect(leida.ronda, 2);
    expect(leida.minutos, 50);
    expect(leida.descanso, 10);
    expect(leida.destino!.id, destinoLeer.id);
    expect(leida.finDescansoUtc, DateTime.utc(2026, 11, 18, 9, 30));
    expect(leida.claveRonda, 'abc');
    expect(Tanda.fromJson({'rondas': 'dos'}), isNull);
    expect(Tanda.fromJson(null), isNull);
  });

  test('la ronda va en los datos de la sesión, y solo si tiene sentido', () {
    final datos = datosAppDe(null, usuarioId: 7, ronda: (n: 1, de: 2));
    expect(rondaDeDatos(datos), (n: 1, de: 2));
    expect(rondaDeDatos(datosAppDe(null, usuarioId: 7)), isNull);
    expect(
      rondaDeDatos({
        'ronda': {'n': 3, 'de': 2},
      }),
      isNull,
    );
  });

  testWidgets('con una sola ronda no hay tanda: una sesión normal', (
    tester,
  ) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.tanda.empezar(rondas: 1, minutos: 25, descanso: 5);
    expect(m.tanda.tanda.value, isNull);
    expect(rondaDeDatos(m.motor.sesion.value!.datosApp), isNull);
    await m.motor.rendirse();
  });

  testWidgets('la tanda empieza por la ronda 1 y se guarda', (tester) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.tanda.empezar(
      rondas: 2,
      minutos: 25,
      descanso: 5,
      destino: destinoLeer,
    );
    expect(m.tanda.tanda.value!.ronda, 1);
    final s = m.motor.sesion.value!;
    expect(rondaDeDatos(s.datosApp), (n: 1, de: 2));
    expect(destinoDeDatos(s.datosApp)!.id, destinoLeer.id);

    final otra = ControladorTanda(
      controlador: m.controlador,
      avisos: AvisosDescansoFalsos(),
    );
    addTearDown(otra.dispose);
    await otra.cargar();
    expect(otra.tanda.value!.rondas, 2);
    await m.motor.rendirse();
  });

  testWidgets('la cuenta de las rondas se guarda con la tanda y sobrevive a '
      'cargar()', (tester) async {
    final m = Montaje(tester);
    m.api.envioPorDefecto = (_) => const EnvioAceptado(
      RespuestaSesion(
        aporte: Aporte(estado: EstadoAporte.sinDestino),
        premio: Premio(monedas: 30, xp: 5),
      ),
      nueva: true,
    );
    await m.controlador.iniciar();
    await m.tanda.empezar(rondas: 3, minutos: 25, descanso: 5);
    m.reloj.avanzar(const Duration(minutes: 25));
    await m.motor.terminar();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final r = m.controlador.resultado.value!;
    expect(r.envio, EnvioResultado.enviada);
    expect(m.tanda.alAcabar(r), isTrue);
    await tester.pump(const Duration(milliseconds: 50));

    // Se mata la app en el descanso: otra tanda lee lo guardado.
    final otra = ControladorTanda(
      controlador: m.controlador,
      avisos: AvisosDescansoFalsos(),
    );
    addTearDown(otra.dispose);
    await otra.cargar();
    final hecha = otra.tanda.value!.hechas.single;
    expect(hecha.clave, r.clave);
    expect(hecha.n, 1);
    expect(hecha.minutos, 25);
    expect(hecha.cuenta, isTrue);
    expect(hecha.envio, EnvioResultado.enviada);
    expect(hecha.monedas, 30);
    expect(hecha.xp, 5);
  });

  testWidgets('sin sesión activa ni descanso, la tanda huérfana se deja', (
    tester,
  ) async {
    final m = Montaje(tester);
    await m.controlador.iniciar();
    await m.tanda.empezar(rondas: 3, minutos: 25, descanso: 5);
    await m.motor.rendirse();
    await m.motor.cerrar();
    await m.tanda.limpiarSiHuerfana();
    expect(m.tanda.tanda.value, isNull);
  });
}
