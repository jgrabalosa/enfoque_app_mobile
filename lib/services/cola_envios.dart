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

  /// No llegó a enviarse: llevaba más de [ColaEnvios.antiguedadMaxima] en la
  /// cola y el backend la habría rechazado. [codigoHttp] es 0.
  final bool antigua;

  const EnvioNoAceptado({
    required this.peticion,
    required this.usuarioId,
    required this.codigoHttp,
    required this.fechaUtc,
    this.destino,
    this.mensaje,
    this.antigua = false,
  });

  String get clave => peticion.clave;

  Map<String, Object?> toJson() => {
    'peticion': peticion.toJson(),
    'usuarioId': usuarioId,
    'destino': destino?.toJson(),
    'codigoHttp': codigoHttp,
    'mensaje': mensaje,
    'fechaUtc': fechaUtc.toUtc().toIso8601String(),
    'antigua': antigua,
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
      antigua: boolDe(m['antigua']) ?? false,
    );
  }
}

/// Programa una llamada. En la app, un [Timer]; en los tests, un falso.
typedef Programador = Timer Function(Duration espera, void Function() accion);

/// Dónde se guarda la cola. En la app, [AlmacenPreferencias]; en los tests,
/// uno que puede fallar.
abstract interface class AlmacenCola {
  /// El texto guardado en [clave], o `null`. Lanza si no se puede leer.
  Future<String?> leer(String clave);

  /// Guarda [valor] en [clave]. `false` (o una excepción) si no quedó
  /// guardado.
  Future<bool> escribir(String clave, String valor);
}

/// [AlmacenCola] sobre `SharedPreferences`.
class AlmacenPreferencias implements AlmacenCola {
  const AlmacenPreferencias();

  @override
  Future<String?> leer(String clave) async =>
      (await SharedPreferences.getInstance()).getString(clave);

  @override
  Future<bool> escribir(String clave, String valor) async =>
      (await SharedPreferences.getInstance()).setString(clave, valor);
}

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
    this.almacen = const AlmacenPreferencias(),
    this.esperaBase = const Duration(seconds: 30),
    this.esperaMaxima = const Duration(minutes: 30),
    this.maximoNoAceptados = 50,
    this.antiguedadMaxima = const Duration(days: 7),
    this.clavePendientes = 'enfoque_cola_envios',
    this.claveNoAceptados = 'enfoque_envios_no_aceptados',
  }) : _ahora = ahora ?? DateTime.now,
       _programar = programar ?? Timer.new;

  final ApiEnfoque api;
  final AlmacenCola almacen;

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

  /// Una sesión que empezó hace más de esto ya no se envía: el backend
  /// rechaza las que empezaron hace más de 7 días.
  final Duration antiguedadMaxima;

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

  /// Lee la cola guardada. Lo que no se entiende se descarta. Devuelve si
  /// está leída: si la lectura falla no se da por cargada, y nada se escribe
  /// hasta leerla (si no, el siguiente guardado pisaría lo que hubiera).
  Future<bool> cargar() async {
    if (_cargada) return true;
    try {
      final pendientes = await almacen.leer(clavePendientes);
      final noAceptados = await almacen.leer(claveNoAceptados);
      _pendientes.value = List.unmodifiable([
        for (final e in _decodificar(pendientes)) ?EnvioPendiente.fromJson(e),
      ]);
      _noAceptados.value = List.unmodifiable([
        for (final e in _decodificar(noAceptados)) ?EnvioNoAceptado.fromJson(e),
      ]);
      _cargada = true;
    } catch (e) {
      debugPrint('ColaEnvios: no se pudo leer la cola: $e');
    }
    return _cargada;
  }

  List<Object?> _decodificar(String? crudo) {
    if (crudo == null) return const [];
    try {
      return listaDe(jsonDecode(crudo));
    } catch (_) {
      return const [];
    }
  }

  /// Mete [peticion] en la cola y la guarda. Devuelve si quedó guardada:
  /// solo entonces se puede soltar la sesión del motor. Si no se pudo leer la
  /// cola, `false` sin escribir nada. Si escribir falla, la entrada sale
  /// otra vez de la memoria y se relanza el error (o `false` si el almacén
  /// dice que no guardó).
  ///
  /// Si ya estaba (misma clave), `true` sin tocar nada: el motor puede
  /// entregar la misma sesión acabada dos veces si el proceso murió antes de
  /// cerrarla, y el cuerpo encolado no cambia nunca (la misma clave con otro
  /// cuerpo daría 409).
  Future<bool> encolar(
    PeticionSesion peticion, {
    required int usuarioId,
    DestinoDisponible? destino,
  }) async {
    if (!await cargar()) return false;
    if (_pendientes.value.any((e) => e.clave == peticion.clave)) return true;
    final antes = _pendientes.value;
    _pendientes.value = List.unmodifiable([
      ...antes,
      EnvioPendiente(
        peticion: peticion,
        usuarioId: usuarioId,
        destino: destino,
      ),
    ]);
    try {
      if (await _guardar()) return true;
    } catch (_) {
      _pendientes.value = antes;
      rethrow;
    }
    _pendientes.value = antes;
    return false;
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
    if (!await cargar()) return;
    await _descartarAntiguas();
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
      // Antes de cada envío: si ha entrado otra cuenta a mitad de pasada, el
      // token ya es el suyo y esta sesión no se manda con él.
      if (await usuarioActual() != envio.usuarioId) return;
      final resultado = await api.enviarSesion(envio.peticion);
      _ultimos[envio.clave] = resultado;
      switch (resultado) {
        case EnvioAceptado():
          _quitar(envio.clave);
        case EnvioRechazado(:final codigoHttp, :final mensaje):
          _quitar(envio.clave);
          _apuntarNoAceptado(
            EnvioNoAceptado(
              peticion: envio.peticion,
              usuarioId: envio.usuarioId,
              destino: envio.destino,
              codigoHttp: codigoHttp,
              mensaje: mensaje,
              fechaUtc: _ahora().toUtc(),
            ),
          );
        case EnvioFallido():
          _sustituir(
            envio.conFallo(
              _ahora().toUtc().add(esperaTras(envio.intentos + 1)),
            ),
          );
      }
      await _guardarSinLanzar();
    }
  }

  /// Saca de la cola, de todos los usuarios, las que empezaron hace más de
  /// [antiguedadMaxima] y las apunta como no enviadas por antigüedad.
  Future<void> _descartarAntiguas() async {
    final limite = _ahora().toUtc().subtract(antiguedadMaxima);
    final antiguas = _pendientes.value
        .where((e) => e.peticion.inicioUtc.isBefore(limite))
        .toList();
    if (antiguas.isEmpty) return;
    for (final e in antiguas) {
      _quitar(e.clave);
      _apuntarNoAceptado(
        EnvioNoAceptado(
          peticion: e.peticion,
          usuarioId: e.usuarioId,
          destino: e.destino,
          codigoHttp: 0,
          fechaUtc: _ahora().toUtc(),
          antigua: true,
        ),
      );
    }
    await _guardarSinLanzar();
  }

  void _apuntarNoAceptado(EnvioNoAceptado n) {
    _noAceptados.value = List.unmodifiable(
      [
        n,
        ..._noAceptados.value.where((e) => e.clave != n.clave),
      ].take(maximoNoAceptados),
    );
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

  /// Guarda las dos listas. `false` si el almacén dice que no guardó; las
  /// excepciones salen. Nunca escribe sin haber leído antes.
  Future<bool> _guardar() async {
    if (!_cargada) return false;
    final a = await almacen.escribir(
      clavePendientes,
      jsonEncode([for (final e in _pendientes.value) e.toJson()]),
    );
    final b = await almacen.escribir(
      claveNoAceptados,
      jsonEncode([for (final e in _noAceptados.value) e.toJson()]),
    );
    return a && b;
  }

  /// Tras un envío: si no se guarda, lo peor es reenviar con la misma clave,
  /// que el backend contesta con el resultado original.
  Future<void> _guardarSinLanzar() async {
    try {
      if (!await _guardar()) {
        debugPrint('ColaEnvios: la cola no quedó guardada');
      }
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
