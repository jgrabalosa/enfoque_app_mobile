import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../models/enfoque.dart';
import 'api_service_enfoque.dart';
import 'cola_envios.dart';
import 'desfase_servidor.dart';

/// La clave de `datosApp` con el destino elegido al empezar.
const String claveDatosDestino = 'destino';

/// La clave de `datosApp` con el usuario que empezó la sesión: su dueño.
const String claveDatosUsuario = 'usuarioId';

/// La clave de `datosApp` con la ronda de una tanda (`{n, de}`), si la
/// sesión es una ronda.
const String claveDatosRonda = 'ronda';

/// Una ronda de una tanda: la [n] de [de].
typedef Ronda = ({int n, int de});

/// Lo que se guarda con la sesión: el destino, el dueño y la ronda, o nada.
Map<String, Object?>? datosAppDe(
  DestinoDisponible? destino, {
  int? usuarioId,
  Ronda? ronda,
}) {
  if (destino == null && usuarioId == null && ronda == null) return null;
  return {
    claveDatosDestino: ?destino?.toJson(),
    claveDatosUsuario: ?usuarioId,
    if (ronda != null) claveDatosRonda: {'n': ronda.n, 'de': ronda.de},
  };
}

/// La ronda guardada con la sesión, o `null` si no es de una tanda.
Ronda? rondaDeDatos(Map<String, Object?>? datosApp) {
  final r = datosApp?[claveDatosRonda];
  if (r is! Map) return null;
  final n = enteroDe(r['n']);
  final de = enteroDe(r['de']);
  if (n == null || de == null || n < 1 || de < n) return null;
  return (n: n, de: de);
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

/// La notificación fija mientras hay una sesión: un servicio en primer plano
/// con la cuenta atrás hasta [arrancar]`(finUtc)` y la ronda. En la app,
/// `AvisoEnCursoLocal`; en los tests, un falso que apunta las llamadas.
///
/// Las dos llamadas tienen que ser idempotentes: [arrancar] otra vez
/// sustituye la notificación y [parar] sin nada arrancado no hace nada.
abstract interface class AvisoEnCurso {
  /// La sesión acaba a [finUtc]; [ronda], si es una ronda de una tanda.
  Future<void> arrancar(DateTime finUtc, Ronda? ronda);

  Future<void> parar();
}

/// Sin notificación en curso.
class AvisoEnCursoNulo implements AvisoEnCurso {
  const AvisoEnCursoNulo();

  @override
  Future<void> arrancar(DateTime finUtc, Ronda? ronda) async {}

  @override
  Future<void> parar() async {}
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
    this.desfase,
    this.enCurso = const AvisoEnCursoNulo(),
  });

  final MotorSesion motor;
  final ColaEnvios cola;
  final Future<int?> Function() usuarioActual;

  /// El desfase servidor − móvil con que se corrige el inicio al encolar. Sin
  /// él (o sin desfase conocido), la hora del móvil.
  final DesfaseServidor? desfase;

  /// La notificación fija mientras hay sesión. La mueve [vigilarEnCurso].
  final AvisoEnCurso enCurso;

  final ValueNotifier<ResultadoSesion?> _resultado = ValueNotifier(null);
  final ValueNotifier<int> _refrescos = ValueNotifier(0);
  final Set<String> _recogiendo = {};
  bool _iniciado = false;

  bool _vigilandoEnCurso = false;

  /// La clave de la sesión con la notificación arrancada; `null` si está
  /// parada, y [_sinSaber] hasta la primera vez (puede haber quedado una
  /// colgada de otra ejecución).
  String? _claveEnCurso = _sinSaber;
  static const String _sinSaber = '?';

  /// Las llamadas al plugin, una detrás de otra: un [AvisoEnCurso.parar] no
  /// adelanta al [AvisoEnCurso.arrancar] de antes.
  Future<void> _colaEnCurso = Future<void>.value();

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
    vigilarEnCurso();
  }

  /// Arranca la notificación en curso cuando empieza (o se recompone) una
  /// sesión y la para en cuanto deja de estar activa: acabada, terminada,
  /// rendida o perdida. Así también está parada en el descanso, que va
  /// después de una ronda acabada. La primera vez, sin sesión activa, la para
  /// igual: puede haber quedado colgada de una ejecución que murió.
  ///
  /// En `main()`, tras `MotorSesion.iniciar()`, porque el motor vigila la
  /// sesión aunque la app abra en el login; [iniciar] también la llama.
  /// Llamarla más de una vez no hace nada.
  void vigilarEnCurso() {
    if (_vigilandoEnCurso) return;
    _vigilandoEnCurso = true;
    motor.sesion.addListener(_sincronizarEnCurso);
    _sincronizarEnCurso();
  }

  void _sincronizarEnCurso() {
    final s = motor.sesion.value;
    final inicio = s?.inicioUtc;
    if (s != null && s.estado.activa && inicio != null) {
      if (_claveEnCurso == s.clave) return;
      _claveEnCurso = s.clave;
      // La hora de pared del fin, que es la que cuenta el cronómetro de la
      // notificación. Sin pausas: la gracia sigue contando.
      final fin = inicio.add(s.duracionObjetivo);
      final ronda = rondaDeDatos(s.datosApp);
      _enCurso(() => enCurso.arrancar(fin, ronda));
      return;
    }
    if (_claveEnCurso == null) return;
    _claveEnCurso = null;
    _enCurso(enCurso.parar);
  }

  /// Si el plugin falla (sin permiso de avisos, Android que no deja arrancar
  /// el servicio…), la sesión sigue igual.
  void _enCurso(Future<void> Function() llamada) {
    _colaEnCurso = _colaEnCurso.then((_) async {
      try {
        await llamada();
      } catch (e) {
        debugPrint('ControladorEnfoque: notificación en curso fallida: $e');
      }
    });
  }

  /// Empieza una sesión de [duracion] con [destino] (o sin él), a nombre
  /// del usuario conectado. Si es una ronda de una tanda, con su [ronda].
  Future<SesionConcentracion> empezar({
    required Duration duracion,
    DestinoDisponible? destino,
    Ronda? ronda,
  }) async => motor.empezar(
    duracionObjetivo: duracion,
    datosApp: datosAppDe(
      destino,
      usuarioId: await usuarioActual(),
      ronda: ronda,
    ),
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
    // El inicio, en la hora del servidor, UNA vez: si la clave ya está en la
    // cola, encolar no toca lo guardado, y el cuerpo de una clave no cambia
    // nunca (con otro cuerpo, el backend daría 409).
    final corregida = desfase == null
        ? peticion
        : peticion.conInicio(desfase!.corregir(peticion.inicioUtc));
    bool guardada;
    try {
      guardada = await cola.encolar(
        corregida,
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
    if (_vigilandoEnCurso) motor.sesion.removeListener(_sincronizarEnCurso);
    _resultado.dispose();
    _refrescos.dispose();
  }
}
