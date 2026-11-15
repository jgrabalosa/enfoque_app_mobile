import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../models/enfoque.dart';
import 'api_service_enfoque.dart';
import 'cola_envios.dart';

/// La clave de `datosApp` con el destino elegido al empezar.
const String claveDatosDestino = 'destino';

/// La clave de `datosApp` con el usuario que empezó la sesión: su dueño.
const String claveDatosUsuario = 'usuarioId';

/// Lo que se guarda con la sesión: el destino y el dueño, o nada.
Map<String, Object?>? datosAppDe(DestinoDisponible? destino, {int? usuarioId}) {
  if (destino == null && usuarioId == null) return null;
  return {claveDatosDestino: ?destino?.toJson(), claveDatosUsuario: ?usuarioId};
}

/// El destino guardado con la sesión, o `null`.
DestinoDisponible? destinoDeDatos(Map<String, Object?>? datosApp) =>
    DestinoDisponible.fromJson(datosApp?[claveDatosDestino]);

/// El usuario que empezó la sesión, o `null` (sesiones de antes de guardarlo).
int? usuarioDeDatos(Map<String, Object?>? datosApp) {
  final id = enteroDe(datosApp?[claveDatosUsuario]);
  return id != null && id > 0 ? id : null;
}

/// La petición que se envía por una sesión acabada, o `null` si no se envía
/// (descartada, o aún activa).
///
/// - `duracionSeg`: lo que duró, en segundos enteros hacia abajo. El motor ya
///   no deja pasar de la meta, así que cumple `duracionSeg ≤ objetivo × 60 +
///   60` del backend.
/// - Una perdida lleva su destino igual: el backend la guarda con el aporte
///   `RECHAZADO` (`enfoque.aporte.sesion.perdida`) y no suma nada.
PeticionSesion? peticionDeSesion(SesionConcentracion s) {
  final estado = switch (s.estado) {
    EstadoSesion.completada => EstadoEnvio.completada,
    EstadoSesion.terminada => EstadoEnvio.terminada,
    EstadoSesion.perdida => EstadoEnvio.perdida,
    _ => null,
  };
  final inicio = s.inicioUtc;
  if (estado == null || inicio == null) return null;
  final destino = destinoDeDatos(s.datosApp);
  return PeticionSesion(
    clave: s.clave,
    inicioUtc: inicio,
    duracionSeg: s.duracion.inSeconds,
    duracionObjetivoMin: s.duracionObjetivo.inMinutes,
    estado: estado,
    destinoTipo: destino?.tipo,
    destinoId: destino?.id,
  );
}

/// En qué punto está el envío de la última sesión acabada.
enum EnvioResultado {
  /// No se envía: descartada (menos del mínimo).
  noSeEnvia,

  /// Enviándose ahora mismo.
  enviando,

  /// Guardada en el backend.
  enviada,

  /// En la cola, esperando a que haya conexión.
  pendiente,

  /// El backend no la aceptó (400 o 409). No se reintenta.
  noAceptada,
}

/// La última sesión acabada y lo que se sabe de su envío. Es lo que pinta la
/// pantalla de resultado.
@immutable
class ResultadoSesion {
  final SesionConcentracion sesion;
  final DestinoDisponible? destino;
  final EnvioResultado envio;

  /// Solo en [EnvioResultado.enviada].
  final RespuestaSesion? respuesta;

  /// Solo en [EnvioResultado.noAceptada]: el `mensaje` del backend.
  final String? mensaje;

  const ResultadoSesion({
    required this.sesion,
    required this.envio,
    this.destino,
    this.respuesta,
    this.mensaje,
  });

  String get clave => sesion.clave;

  ResultadoSesion con({
    required EnvioResultado envio,
    RespuestaSesion? respuesta,
    String? mensaje,
  }) => ResultadoSesion(
    sesion: sesion,
    destino: destino,
    envio: envio,
    respuesta: respuesta,
    mensaje: mensaje,
  );
}

/// Junta el motor de sesión del core y la cola de envíos: empieza sesiones
/// con su destino y su dueño, recoge cada sesión acabada, la mete en la cola,
/// la cierra en el motor y la envía.
///
/// **Cuándo se cierra en el motor**: justo después de que `encolar` diga que
/// quedó guardada, sin esperar al envío. La cola guarda el cuerpo exacto y se
/// encarga de los reintentos; si el motor esperase al envío, sin red no se
/// podría empezar otra sesión (lleva una sola a la vez). Si encolar falla, la
/// sesión se queda en el motor (que la tiene guardada) y la recogida se
/// reintenta en el siguiente [iniciar] o [enviarPendientes]. Si el proceso
/// muere entre encolar y cerrar, el motor la entrega otra vez y la cola la
/// reconoce por la clave.
///
/// **De quién es**: el usuario que la empezó va en `datosApp` y se encola con
/// él aunque al acabar haya otra cuenta (o ninguna). La cola solo la envía
/// con ese usuario conectado.
class ControladorEnfoque {
  ControladorEnfoque({
    required this.motor,
    required this.cola,
    required this.usuarioActual,
  });

  final MotorSesion motor;
  final ColaEnvios cola;
  final Future<int?> Function() usuarioActual;

  final ValueNotifier<ResultadoSesion?> _resultado = ValueNotifier(null);
  final ValueNotifier<int> _refrescos = ValueNotifier(0);
  final Set<String> _recogiendo = {};
  bool _iniciado = false;

  /// La última sesión acabada, hasta que la pantalla de resultado la suelta
  /// con [soltarResultado].
  ValueListenable<ResultadoSesion?> get resultado => _resultado;

  /// Sube cada vez que el backend guarda una sesión: Inicio y Estadísticas
  /// recargan.
  ValueListenable<int> get refrescos => _refrescos;

  /// Lee la cola, recompone la sesión guardada en el motor (solo la primera
  /// vez), recoge una sesión acabada que siga en el motor y envía lo
  /// pendiente. Cada vez que se entra con sesión: tras un login, una sesión
  /// que acabó sin usuario se recoge ahora.
  Future<void> iniciar() async {
    await (_inicio ??= _iniciarUnaVez());
    _alCambiarSesion();
    unawaited(enviarPendientes());
  }

  Future<void>? _inicio;

  Future<void> _iniciarUnaVez() async {
    await cola.cargar();
    await motor.iniciar();
    motor.sesion.addListener(_alCambiarSesion);
    _iniciado = true;
  }

  /// Empieza una sesión de [duracion] con [destino] (o sin él), a nombre
  /// del usuario conectado.
  Future<SesionConcentracion> empezar({
    required Duration duracion,
    DestinoDisponible? destino,
  }) async => motor.empezar(
    duracionObjetivo: duracion,
    datosApp: datosAppDe(destino, usuarioId: await usuarioActual()),
  );

  /// Reintenta todo lo pendiente ya, sin esperar a su turno. Al arrancar y
  /// al volver a primer plano.
  Future<void> enviarPendientes() async {
    // Una sesión acabada que no se pudo encolar sigue en el motor.
    _alCambiarSesion();
    final antes = cola.pendientes.value.length;
    await cola.procesar(forzar: true);
    if (cola.pendientes.value.length < antes) _refrescos.value++;
  }

  /// La pantalla de resultado ya se ha cerrado.
  void soltarResultado() => _resultado.value = null;

  void _alCambiarSesion() {
    final s = motor.sesion.value;
    if (s == null || !s.estado.esFinal || _recogiendo.contains(s.clave)) {
      return;
    }
    _recogiendo.add(s.clave);
    unawaited(_recoger(s).whenComplete(() => _recogiendo.remove(s.clave)));
  }

  Future<void> _recoger(SesionConcentracion s) async {
    final destino = destinoDeDatos(s.datosApp);
    final base = ResultadoSesion(
      sesion: s,
      destino: destino,
      envio: EnvioResultado.enviando,
    );
    final peticion = peticionDeSesion(s);
    if (peticion == null) {
      _resultado.value = base.con(envio: EnvioResultado.noSeEnvia);
      await motor.cerrar();
      return;
    }
    _resultado.value = base;
    final dueno = usuarioDeDatos(s.datosApp) ?? await usuarioActual();
    if (dueno == null) {
      // Sin dueño conocido no se sabe con qué cuenta enviarla: se queda en el
      // motor (persistente) hasta el siguiente login, que vuelve a recogerla.
      _poner(base.con(envio: EnvioResultado.pendiente));
      return;
    }
    bool guardada;
    try {
      guardada = await cola.encolar(
        peticion,
        usuarioId: dueno,
        destino: destino,
      );
    } catch (e) {
      debugPrint('ControladorEnfoque: no se pudo encolar: $e');
      guardada = false;
    }
    if (!guardada) {
      _poner(base.con(envio: EnvioResultado.pendiente));
      return;
    }
    await motor.cerrar();
    unawaited(_enviar(peticion.clave, base));
  }

  Future<void> _enviar(String clave, ResultadoSesion base) async {
    await cola.procesar(forzar: true);
    switch (cola.resultadoDe(clave)) {
      case EnvioAceptado(:final respuesta):
        _poner(base.con(envio: EnvioResultado.enviada, respuesta: respuesta));
        _refrescos.value++;
      case EnvioRechazado(:final mensaje):
        _poner(base.con(envio: EnvioResultado.noAceptada, mensaje: mensaje));
      case EnvioFallido():
      case null:
        _poner(base.con(envio: EnvioResultado.pendiente));
    }
  }

  /// Pone [r] si sigue siendo la sesión que se enseña (nadie la ha soltado).
  void _poner(ResultadoSesion r) {
    if (_resultado.value?.clave == r.clave) _resultado.value = r;
  }

  void dispose() {
    if (_iniciado) motor.sesion.removeListener(_alCambiarSesion);
    _resultado.dispose();
    _refrescos.dispose();
  }
}
