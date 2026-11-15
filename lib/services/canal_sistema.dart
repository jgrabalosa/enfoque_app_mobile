import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

/// El canal con `MainActivity.kt`. Uno solo, en los dos sentidos.
///
/// De Dart a Android: `monotonicoMs`, `encendidaYDesbloqueada`, `abrir` y
/// `enlaceInicial`. De Android a Dart: `desbloqueo` (ACTION_USER_PRESENT) y
/// `enlace` (un enlace con la app ya abierta).
const MethodChannel canalSistema = MethodChannel('com.norday.enfoque/sistema');

/// El reloj de la sesión: `SystemClock.elapsedRealtime()` por el canal, y la
/// hora de pared de Dart.
///
/// Sin la parte nativa (otra plataforma, un test sin el canal simulado)
/// lanza: un reloj inventado podría dar por perdida por reinicio una sesión
/// buena, y es mejor que el fallo se vea.
class RelojSistema implements FuenteReloj {
  const RelojSistema({this.canal = canalSistema});

  final MethodChannel canal;

  @override
  Future<int> monotonicoMs() async {
    final ms = await canal.invokeMethod<int>('monotonicoMs');
    if (ms == null) {
      throw PlatformException(
        code: 'sin_reloj',
        message: 'monotonicoMs devolvió null',
      );
    }
    return ms;
  }

  @override
  DateTime ahoraUtc() => DateTime.now().toUtc();
}

/// Pantalla encendida y desbloqueada, por el canal. Si la consulta falla,
/// `false`: un canal roto no hace perder sesiones (el motor hace lo mismo).
class PantallaSistema implements FuentePantalla {
  const PantallaSistema({this.canal = canalSistema});

  final MethodChannel canal;

  @override
  Future<bool> encendidaYDesbloqueada() async {
    try {
      return await canal.invokeMethod<bool>('encendidaYDesbloqueada') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Lo que de verdad abre enlaces y apps. En la app es [LanzadorSistema]; en
/// los tests, un falso.
abstract interface class Lanzador {
  /// Abre [enlace] (con [paquete], solo con esa app) o, sin enlace, la app
  /// [paquete]. True si se abrió algo.
  Future<bool> abrir({Uri? enlace, String? paquete});
}

class LanzadorSistema implements Lanzador {
  const LanzadorSistema({this.canal = canalSistema});

  final MethodChannel canal;

  @override
  Future<bool> abrir({Uri? enlace, String? paquete}) async {
    try {
      final abierto = await canal.invokeMethod<bool>('abrir', {
        'enlace': ?enlace?.toString(),
        'paquete': ?paquete,
      });
      return abierto ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Lo que llega de Android sin que Dart lo pida: los desbloqueos y los
/// enlaces con la app abierta. Se engancha una vez, en `main()`.
class EventosSistema {
  EventosSistema({this.canal = canalSistema});

  final MethodChannel canal;

  final StreamController<void> _desbloqueos = StreamController.broadcast();
  final StreamController<String> _enlaces = StreamController.broadcast();

  /// Cada desbloqueo del móvil.
  Stream<void> get desbloqueos => _desbloqueos.stream;

  /// Cada enlace `norday-enfoque://` que llega con la app abierta.
  Stream<String> get enlaces => _enlaces.stream;

  /// Empieza a escuchar el canal.
  void escuchar() {
    canal.setMethodCallHandler(alLlamar);
  }

  /// Lo que hace con cada llamada de Android. Público solo para probarlo.
  @visibleForTesting
  Future<Object?> alLlamar(MethodCall llamada) async {
    switch (llamada.method) {
      case 'desbloqueo':
        _desbloqueos.add(null);
      case 'enlace':
        final enlace = llamada.arguments;
        if (enlace is String) _enlaces.add(enlace);
      default:
        throw MissingPluginException(llamada.method);
    }
    return null;
  }

  /// El enlace con que se abrió la app, o `null`. Android lo entrega una
  /// sola vez.
  Future<String?> enlaceInicial() async {
    try {
      return await canal.invokeMethod<String>('enlaceInicial');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  void dispose() {
    canal.setMethodCallHandler(null);
    _desbloqueos.close();
    _enlaces.close();
  }
}
