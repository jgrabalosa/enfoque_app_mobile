import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/enfoque.dart';
import 'api_service_enfoque.dart';

/// Una sesión acabada que aún no ha llegado al backend.
@immutable
class EnvioPendiente {
  final PeticionSesion peticion;

  /// De quién es: solo se envía con la sesión de ese usuario abierta. Si en
  /// el mismo móvil entra otra cuenta, sus sesiones esperan a su dueño.
  final int usuarioId;

  /// El destino tal como se veía al empezar, para pintarlo (el nombre no
  /// viaja en la petición).
  final DestinoDisponible? destino;

  /// Intentos fallidos (5xx, sin red…).
  final int intentos;

  /// No antes de esto, salvo que se fuerce (al arrancar, al volver a primer
  /// plano). `null`: ya.
  final DateTime? proximoIntentoUtc;

  const EnvioPendiente({
    required this.peticion,
    required this.usuarioId,
    this.destino,
    this.intentos = 0,
    this.proximoIntentoUtc,
  });

  String get clave => peticion.clave;

  EnvioPendiente conFallo(DateTime proximo) => EnvioPendiente(
    peticion: peticion,
    usuarioId: usuarioId,
    destino: destino,
    intentos: intentos + 1,
    proximoIntentoUtc: proximo.toUtc(),
  );

  Map<String, Object?> toJson() => {
    'peticion': peticion.toJson(),
    'usuarioId': usuarioId,
    'destino': destino?.toJson(),
    'intentos': intentos,
    'proximoIntentoUtc': proximoIntentoUtc?.toIso8601String(),
  };

  static EnvioPendiente? fromJson(Object? json) {
    final m = mapaDe(json);
    final peticion = PeticionSesion.fromJson(m?['peticion']);
    final usuarioId = enteroDe(m?['usuarioId']);
    if (m == null || peticion == null || usuarioId == null) return null;
    return EnvioPendiente(
      peticion: peticion,
      usuarioId: usuarioId,
      destino: DestinoDisponible.fromJson(m['destino']),
      intentos: enteroDe(m['intentos']) ?? 0,
      proximoIntentoUtc: DateTime.tryParse(
        textoDe(m['proximoIntentoUtc']) ?? '',
      )?.toUtc(),
    );
  }
}

/// Una sesión que el backend no aceptó (400 o 409) y que ya no se reintenta.
/// Queda en el historial local con su motivo.
@immutable
class EnvioNoAceptado {
  final PeticionSesion peticion;
  final int usuarioId;
  final DestinoDisponible? destino;
  final int codigoHttp;

  /// El `mensaje` del backend, ya traducido, o `null`.
  final String? mensaje;
  final DateTime fechaUtc;

  const EnvioNoAceptado({
    required this.peticion,
    required this.usuarioId,
    required this.codigoHttp,
    required this.fechaUtc,
    this.destino,
    this.mensaje,
  });

  String get clave => peticion.clave;

  Map<String, Object?> toJson() => {
    'peticion': peticion.toJson(),
    'usuarioId': usuarioId,
    'destino': destino?.toJson(),
    'codigoHttp': codigoHttp,
    'mensaje': mensaje,
    'fechaUtc': fechaUtc.toUtc().toIso8601String(),
  };

  static EnvioNoAceptado? fromJson(Object? json) {
    final m = mapaDe(json);
    final peticion = PeticionSesion.fromJson(m?['peticion']);
    final usuarioId = enteroDe(m?['usuarioId']);
    final codigo = enteroDe(m?['codigoHttp']);
    final fecha = DateTime.tryParse(textoDe(m?['fechaUtc']) ?? '');
    if (m == null ||
        peticion == null ||
        usuarioId == null ||
        codigo == null ||
        fecha == null) {
      return null;
    }
    return EnvioNoAceptado(
      peticion: peticion,
      usuarioId: usuarioId,
      destino: DestinoDisponible.fromJson(m['destino']),
      codigoHttp: codigo,
      mensaje: textoDe(m['mensaje']),
      fechaUtc: fecha.toUtc(),
    );
  }
}

/// Programa una llamada. En la app, un [Timer]; en los tests, un falso.
typedef Programador = Timer Function(Duration espera, void Function() accion);

/// La cola de sesiones acabadas, persistente en `SharedPreferences`.
///
/// El contrato con el backend (EnfoqueController):
///
/// - **5xx o sin respuesta**: reintentar más tarde con la misma clave y el
///   mismo cuerpo. Aquí: se queda en la cola y se reintenta con una espera
///   que crece ([esperaTras]), y además en cuanto se fuerza (al arrancar y al
///   volver a primer plano).
/// - **400 y 409**: definitivos. Salen de la cola y quedan en
///   [noAceptados] con su motivo, sin reintentar.
/// - **200/201**: enviada. Sale de la cola.
///
/// El cuerpo se guarda al encolar y se reenvía tal cual: la misma clave con
/// el mismo cuerpo da en el backend el resultado original, sin sumar ni
/// pagar dos veces.
class ColaEnvios {
  ColaEnvios({
    required this.api,
    required this.usuarioActual,
    DateTime Function()? ahora,
    Programador? programar,
    this.esperaBase = const Duration(seconds: 30),
    this.esperaMaxima = const Duration(minutes: 30),
    this.maximoNoAceptados = 50,
    this.clavePendientes = 'enfoque_cola_envios',
    this.claveNoAceptados = 'enfoque_envios_no_aceptados',
  }) : _ahora = ahora ?? DateTime.now,
       _programar = programar ?? Timer.new;

  final ApiEnfoque api;

  /// El usuario con la sesión abierta, o `null`.
  final Future<int?> Function() usuarioActual;
  final DateTime Function() _ahora;
  final Programador _programar;

  /// Espera tras el primer fallo; se dobla en cada fallo siguiente.
  final Duration esperaBase;

  /// La espera no pasa de aquí.
  final Duration esperaMaxima;

  /// Cuántos no aceptados se guardan (los más recientes).
  final int maximoNoAceptados;

  final String clavePendientes;
  final String claveNoAceptados;

  final ValueNotifier<List<EnvioPendiente>> _pendientes = ValueNotifier(
    const [],
  );
  final ValueNotifier<List<EnvioNoAceptado>> _noAceptados = ValueNotifier(
    const [],
  );
  final Map<String, ResultadoEnvio> _ultimos = {};

  /// Lo que falta por enviar, de todos los usuarios del móvil, por orden de
  /// llegada.
  ValueListenable<List<EnvioPendiente>> get pendientes => _pendientes;

  /// Lo que el backend no aceptó, del más reciente al más antiguo.
  ValueListenable<List<EnvioNoAceptado>> get noAceptados => _noAceptados;

  Timer? _temporizador;
  Future<void>? _enCurso;
  bool _repetir = false;
  bool _repetirForzado = false;
  bool _cargada = false;

  /// La espera tras [intentos] fallos: [esperaBase] × 2^(intentos − 1), sin
  /// pasar de [esperaMaxima].
  Duration esperaTras(int intentos) {
    if (intentos <= 0) return Duration.zero;
    final factor = math.pow(2, math.min(intentos - 1, 20)).toInt();
    final ms = esperaBase.inMilliseconds * factor;
    return Duration(milliseconds: math.min(ms, esperaMaxima.inMilliseconds));
  }

  /// El último resultado de enviar [clave] en esta ejecución, o `null`.
  ResultadoEnvio? resultadoDe(String clave) => _ultimos[clave];

  /// Lee la cola guardada. Lo que no se entiende se descarta.
  Future<void> cargar() async {
    if (_cargada) return;
    _cargada = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _pendientes.value = List.unmodifiable([
        for (final e in _leerLista(prefs, clavePendientes))
          ?EnvioPendiente.fromJson(e),
      ]);
      _noAceptados.value = List.unmodifiable([
        for (final e in _leerLista(prefs, claveNoAceptados))
          ?EnvioNoAceptado.fromJson(e),
      ]);
    } catch (e) {
      debugPrint('ColaEnvios: no se pudo leer la cola: $e');
    }
  }

  List<Object?> _leerLista(SharedPreferences prefs, String clave) {
    final crudo = prefs.getString(clave);
    if (crudo == null) return const [];
    try {
      return listaDe(jsonDecode(crudo));
    } catch (_) {
      return const [];
    }
  }

  /// Mete [peticion] en la cola y la guarda. Si ya estaba (misma clave), no
  /// hace nada: el motor puede entregar la misma sesión acabada dos veces si
  /// el proceso murió antes de cerrarla.
  Future<void> encolar(
    PeticionSesion peticion, {
    required int usuarioId,
    DestinoDisponible? destino,
  }) async {
    await cargar();
    if (_pendientes.value.any((e) => e.clave == peticion.clave)) return;
    _pendientes.value = List.unmodifiable([
      ..._pendientes.value,
      EnvioPendiente(
        peticion: peticion,
        usuarioId: usuarioId,
        destino: destino,
      ),
    ]);
    await _guardar();
  }

  /// Envía lo que toca: lo del usuario actual cuyo [EnvioPendiente.proximoIntentoUtc]
  /// ya ha pasado, o todo lo suyo con [forzar]. Uno detrás de otro, por orden
  /// de llegada. Si ya hay un envío en curso, espera a que acabe y vuelve a
  /// pasar.
  Future<void> procesar({bool forzar = false}) {
    final enCurso = _enCurso;
    if (enCurso != null) {
      _repetir = true;
      _repetirForzado = _repetirForzado || forzar;
      return enCurso;
    }
    final hecho = Completer<void>();
    _enCurso = hecho.future;
    unawaited(_bucle(forzar, hecho));
    return hecho.future;
  }

  /// Pasa una y otra vez mientras alguien lo pida durante la pasada. Entre
  /// comprobar [_repetir] y soltar [_enCurso] no hay ningún `await`: nadie
  /// puede colarse y quedarse sin su pasada.
  Future<void> _bucle(bool forzar, Completer<void> hecho) async {
    var f = forzar;
    try {
      while (true) {
        _repetir = false;
        try {
          await _pasada(f);
        } catch (e) {
          debugPrint('ColaEnvios: pasada fallida: $e');
        }
        if (!_repetir) break;
        f = _repetirForzado;
        _repetirForzado = false;
      }
      _programarSiguiente();
    } finally {
      _enCurso = null;
      hecho.complete();
    }
  }

  Future<void> _pasada(bool forzar) async {
    await cargar();
    final usuario = await usuarioActual();
    if (usuario == null) return;
    final ahora = _ahora().toUtc();
    final candidatos = _pendientes.value
        .where(
          (e) =>
              e.usuarioId == usuario &&
              (forzar ||
                  e.proximoIntentoUtc == null ||
                  !e.proximoIntentoUtc!.isAfter(ahora)),
        )
        .toList();
    for (final envio in candidatos) {
      final resultado = await api.enviarSesion(envio.peticion);
      _ultimos[envio.clave] = resultado;
      switch (resultado) {
        case EnvioAceptado():
          _quitar(envio.clave);
        case EnvioRechazado(:final codigoHttp, :final mensaje):
          _quitar(envio.clave);
          _noAceptados.value = List.unmodifiable(
            [
              EnvioNoAceptado(
                peticion: envio.peticion,
                usuarioId: envio.usuarioId,
                destino: envio.destino,
                codigoHttp: codigoHttp,
                mensaje: mensaje,
                fechaUtc: _ahora().toUtc(),
              ),
              ..._noAceptados.value.where((e) => e.clave != envio.clave),
            ].take(maximoNoAceptados),
          );
        case EnvioFallido():
          _sustituir(
            envio.conFallo(
              _ahora().toUtc().add(esperaTras(envio.intentos + 1)),
            ),
          );
      }
      await _guardar();
    }
  }

  void _quitar(String clave) {
    _pendientes.value = List.unmodifiable(
      _pendientes.value.where((e) => e.clave != clave),
    );
  }

  void _sustituir(EnvioPendiente nuevo) {
    _pendientes.value = List.unmodifiable([
      for (final e in _pendientes.value) e.clave == nuevo.clave ? nuevo : e,
    ]);
  }

  /// Un solo temporizador, al próximo reintento que antes toque.
  void _programarSiguiente() {
    _temporizador?.cancel();
    _temporizador = null;
    DateTime? siguiente;
    for (final e in _pendientes.value) {
      final p = e.proximoIntentoUtc;
      if (p == null) continue;
      if (siguiente == null || p.isBefore(siguiente)) siguiente = p;
    }
    if (siguiente == null) return;
    final espera = siguiente.difference(_ahora().toUtc());
    _temporizador = _programar(
      espera.isNegative ? Duration.zero : espera,
      () => unawaited(procesar()),
    );
  }

  Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        clavePendientes,
        jsonEncode([for (final e in _pendientes.value) e.toJson()]),
      );
      await prefs.setString(
        claveNoAceptados,
        jsonEncode([for (final e in _noAceptados.value) e.toJson()]),
      );
    } catch (e) {
      debugPrint('ColaEnvios: no se pudo guardar la cola: $e');
    }
  }

  void dispose() {
    _temporizador?.cancel();
    _pendientes.dispose();
    _noAceptados.dispose();
  }
}
