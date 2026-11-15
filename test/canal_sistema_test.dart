import 'dart:async';

import 'package:enfoque_app_mobile/services/canal_sistema.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// El contrato del canal com.norday.enfoque/sistema con MainActivity.kt:
/// nombres de método, argumentos y tipos de vuelta en los dos sentidos.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mensajero =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> llamadas;

  void simular(Future<Object?>? Function(MethodCall) contestar) {
    llamadas = [];
    mensajero.setMockMethodCallHandler(canalSistema, (llamada) {
      llamadas.add(llamada);
      return contestar(llamada);
    });
  }

  tearDown(() => mensajero.setMockMethodCallHandler(canalSistema, null));

  test('el canal se llama com.norday.enfoque/sistema', () {
    expect(canalSistema.name, 'com.norday.enfoque/sistema');
  });

  group('RelojSistema', () {
    test('monotonicoMs pide el reloj y devuelve el entero', () async {
      simular((_) async => 123456789);
      expect(await const RelojSistema().monotonicoMs(), 123456789);
      expect(llamadas.single.method, 'monotonicoMs');
      expect(llamadas.single.arguments, isNull);
    });

    test('sin respuesta lanza: un reloj inventado perdería sesiones', () async {
      simular((_) async => null);
      await expectLater(
        const RelojSistema().monotonicoMs(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('ahoraUtc va en UTC', () {
      expect(const RelojSistema().ahoraUtc().isUtc, isTrue);
    });
  });

  group('PantallaSistema', () {
    test('devuelve lo que diga Android', () async {
      simular((_) async => true);
      expect(await const PantallaSistema().encendidaYDesbloqueada(), isTrue);
      expect(llamadas.single.method, 'encendidaYDesbloqueada');
      simular((_) async => false);
      expect(await const PantallaSistema().encendidaYDesbloqueada(), isFalse);
    });

    test('un fallo del canal cuenta como no salir', () async {
      simular((_) async => throw PlatformException(code: 'x'));
      expect(await const PantallaSistema().encendidaYDesbloqueada(), isFalse);
      mensajero.setMockMethodCallHandler(canalSistema, null);
      expect(await const PantallaSistema().encendidaYDesbloqueada(), isFalse);
    });
  });

  group('LanzadorSistema', () {
    test('abrir con enlace y paquete', () async {
      simular((_) async => true);
      final abierto = await const LanzadorSistema().abrir(
        enlace: Uri.parse('market://details?id=com.norday.habitos'),
        paquete: 'com.norday.habitos',
      );
      expect(abierto, isTrue);
      expect(llamadas.single.method, 'abrir');
      expect(llamadas.single.arguments, {
        'enlace': 'market://details?id=com.norday.habitos',
        'paquete': 'com.norday.habitos',
      });
    });

    test('abrir una app: solo el paquete, sin la clave enlace', () async {
      simular((_) async => false);
      final abierto = await const LanzadorSistema().abrir(
        paquete: 'com.norday.habitos',
      );
      expect(abierto, isFalse);
      expect(llamadas.single.arguments, {'paquete': 'com.norday.habitos'});
    });

    test('sin la parte nativa, false', () async {
      mensajero.setMockMethodCallHandler(canalSistema, null);
      expect(await const LanzadorSistema().abrir(paquete: 'x'), isFalse);
    });
  });

  group('EventosSistema', () {
    test('enlaceInicial lo pide una vez a Android', () async {
      simular((_) async => 'norday-enfoque://sesion?destino=habito&id=3');
      final eventos = EventosSistema();
      expect(
        await eventos.enlaceInicial(),
        'norday-enfoque://sesion?destino=habito&id=3',
      );
      expect(llamadas.single.method, 'enlaceInicial');
    });

    test('desbloqueo y enlace llegan desde Android', () async {
      final eventos = EventosSistema()..escuchar();
      final desbloqueos = <void>[];
      final enlaces = <String>[];
      final s1 = eventos.desbloqueos.listen(desbloqueos.add);
      final s2 = eventos.enlaces.listen(enlaces.add);

      Future<void> desdeAndroid(String metodo, [Object? args]) async {
        final datos = const StandardMethodCodec().encodeMethodCall(
          MethodCall(metodo, args),
        );
        final hecho = Completer<void>();
        await mensajero.handlePlatformMessage(
          canalSistema.name,
          datos,
          (_) => hecho.complete(),
        );
        await hecho.future;
      }

      await desdeAndroid('desbloqueo');
      await desdeAndroid(
        'enlace',
        'norday-enfoque://sesion?destino=habito&id=9',
      );
      await desdeAndroid('enlace', 42); // Lo que no es texto se ignora.
      await Future<void>.delayed(Duration.zero);

      expect(desbloqueos, hasLength(1));
      expect(enlaces, ['norday-enfoque://sesion?destino=habito&id=9']);
      await s1.cancel();
      await s2.cancel();
      eventos.dispose();
    });

    test('un método desconocido no se traga', () async {
      final eventos = EventosSistema();
      await expectLater(
        eventos.alLlamar(const MethodCall('otro')),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });
}
