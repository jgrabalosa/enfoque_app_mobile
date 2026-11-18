import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/enfoque.dart';
import 'controlador_enfoque.dart';

/// El aviso de que se acaba el descanso. En la app, `AvisosDescansoLocales`;
/// en los tests, un falso.
abstract interface class AvisosDescanso {
  Future<void> programarFin(DateTime finUtc);
  Future<void> cancelar();
}

/// Una tanda de rondas en marcha (diseño de Focus, 17-nov-2026): [rondas]
/// sesiones de [minutos] con [descanso] minutos entre una y otra.
///
/// Cada ronda es una sesión normal del motor, con su premio. La tanda solo
/// recuerda por cuál va y, entre rondas, cuándo acaba el descanso.
@immutable
class Tanda {
  const Tanda({
    required this.rondas,
    required this.ronda,
    required this.minutos,
    required this.descanso,
    this.destino,
    this.finDescansoUtc,
    this.claveRonda,
  });

  final int rondas;

  /// La ronda en curso o, en el descanso, la que se acaba de hacer.
  final int ronda;
  final int minutos;
  final int descanso;
  final DestinoDisponible? destino;

  /// Cuándo acaba el descanso, o `null` si no se está descansando.
  final DateTime? finDescansoUtc;

  /// La sesión de la ronda que dio paso al descanso.
  final String? claveRonda;

  bool get enDescanso => finDescansoUtc != null;
  bool get esLaUltima => ronda >= rondas;

  Tanda copiar({int? ronda, DateTime? finDescansoUtc, String? claveRonda}) =>
      Tanda(
        rondas: rondas,
        ronda: ronda ?? this.ronda,
        minutos: minutos,
        descanso: descanso,
        destino: destino,
        finDescansoUtc: finDescansoUtc,
        claveRonda: claveRonda,
      );

  Map<String, Object?> toJson() => {
    'rondas': rondas,
    'ronda': ronda,
    'minutos': minutos,
    'descanso': descanso,
    'destino': ?destino?.toJson(),
    'finDescansoUtc': ?finDescansoUtc?.toUtc().toIso8601String(),
    'claveRonda': ?claveRonda,
  };

  /// La tanda guardada, o `null` si no se entiende.
  static Tanda? fromJson(Object? json) {
    if (json is! Map) return null;
    final rondas = json['rondas'];
    final ronda = json['ronda'];
    final minutos = json['minutos'];
    final descanso = json['descanso'];
    if (rondas is! int || ronda is! int || minutos is! int) return null;
    if (descanso is! int) return null;
    final fin = json['finDescansoUtc'];
    final clave = json['claveRonda'];
    return Tanda(
      rondas: rondas,
      ronda: ronda,
      minutos: minutos,
      descanso: descanso,
      destino: DestinoDisponible.fromJson(json['destino']),
      finDescansoUtc: fin is String ? DateTime.tryParse(fin)?.toUtc() : null,
      claveRonda: clave is String ? clave : null,
    );
  }
}

/// Lleva las tandas de rondas: empieza cada ronda con [controlador], decide
/// al acabar una si toca descanso y guarda la tanda para que sobreviva a que
/// maten la app en el descanso.
///
/// Al acabar el descanso **no empieza sola la ronda siguiente**: en el
/// descanso se puede salir de la app, y una sesión que empieza con la app
/// fuera se perdería en el acto. Avisa, y la ronda la empieza el usuario.
class ControladorTanda {
  ControladorTanda({
    required this.controlador,
    required this.avisos,
    DateTime Function()? ahoraUtc,
    this.clave = 'enfoque_tanda',
  }) : _ahoraUtc = ahoraUtc ?? (() => DateTime.now().toUtc());

  final ControladorEnfoque controlador;
  final AvisosDescanso avisos;
  final DateTime Function() _ahoraUtc;

  /// Dónde se guarda la tanda en `SharedPreferences`.
  final String clave;

  final ValueNotifier<Tanda?> _tanda = ValueNotifier(null);

  /// La tanda en marcha, o `null`.
  ValueListenable<Tanda?> get tanda => _tanda;

  DateTime ahoraUtc() => _ahoraUtc();

  /// Lee la tanda guardada.
  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(clave);
      _tanda.value = texto == null ? null : Tanda.fromJson(jsonDecode(texto));
    } catch (e) {
      debugPrint('ControladorTanda: no se pudo leer la tanda: $e');
    }
  }

  Future<void> _poner(Tanda? t) async {
    _tanda.value = t;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (t == null) {
        await prefs.remove(clave);
      } else {
        await prefs.setString(clave, jsonEncode(t.toJson()));
      }
    } catch (e) {
      debugPrint('ControladorTanda: no se pudo guardar la tanda: $e');
    }
  }

  /// Empieza una tanda de [rondas] (con una sola, una sesión normal y sin
  /// tanda) y su primera ronda.
  Future<void> empezar({
    required int rondas,
    required int minutos,
    required int descanso,
    DestinoDisponible? destino,
  }) async {
    if (rondas <= 1) {
      await terminar();
      await controlador.empezar(
        duracion: Duration(minutes: minutos),
        destino: destino,
      );
      return;
    }
    final t = Tanda(
      rondas: rondas,
      ronda: 1,
      minutos: minutos,
      descanso: descanso,
      destino: destino,
    );
    await _poner(t);
    await _empezarRonda(t);
  }

  Future<void> _empezarRonda(Tanda t) => controlador.empezar(
    duracion: Duration(minutes: t.minutos),
    destino: t.destino,
    ronda: (n: t.ronda, de: t.rondas),
  );

  /// Una ronda ha acabado con [r]. Devuelve si toca descanso: solo si se
  /// completó y no era la última. Si no, la tanda se acaba. Se puede llamar
  /// más de una vez con el mismo resultado.
  bool alAcabar(ResultadoSesion r) {
    final t = _tanda.value;
    if (t == null) return false;
    if (t.claveRonda == r.clave) return t.enDescanso;
    final ronda = rondaDeDatos(r.sesion.datosApp);
    final esDeLaTanda = ronda != null && ronda.n == t.ronda;
    if (esDeLaTanda &&
        r.sesion.estado == EstadoSesion.completada &&
        !t.esLaUltima) {
      final fin = _ahoraUtc().add(Duration(minutes: t.descanso));
      unawaited(_poner(t.copiar(finDescansoUtc: fin, claveRonda: r.clave)));
      unawaited(avisos.programarFin(fin).catchError((Object _) {}));
      return true;
    }
    unawaited(_poner(null));
    return false;
  }

  /// Lo que falta de descanso (cero si ya acabó), o `null` si no se está
  /// descansando.
  Duration? restanteDescanso() {
    final fin = _tanda.value?.finDescansoUtc;
    if (fin == null) return null;
    final quedan = fin.difference(_ahoraUtc());
    return quedan.isNegative ? Duration.zero : quedan;
  }

  /// Corta el descanso (o lo da por acabado) y empieza la ronda siguiente.
  Future<void> siguienteRonda() async {
    final t = _tanda.value;
    if (t == null || !t.enDescanso) return;
    final siguiente = Tanda(
      rondas: t.rondas,
      ronda: t.ronda + 1,
      minutos: t.minutos,
      descanso: t.descanso,
      destino: t.destino,
    );
    await _poner(siguiente);
    unawaited(avisos.cancelar().catchError((Object _) {}));
    await _empezarRonda(siguiente);
  }

  /// Deja la tanda. Lo hecho hasta aquí ya está guardado, ronda a ronda.
  Future<void> terminar() async {
    if (_tanda.value == null) return;
    await _poner(null);
    unawaited(avisos.cancelar().catchError((Object _) {}));
  }

  /// Al arrancar sin sesión activa: una tanda que no está en descanso ya no
  /// tiene ronda en marcha (se mató la app justo al empezarla) y se deja.
  Future<void> limpiarSiHuerfana() async {
    final t = _tanda.value;
    final activa = controlador.motor.sesion.value?.estado.activa ?? false;
    if (t != null && !t.enDescanso && !activa) await terminar();
  }

  void dispose() => _tanda.dispose();
}
