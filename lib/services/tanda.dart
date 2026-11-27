import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/enfoque.dart';
import 'api_service_enfoque.dart';
import 'controlador_enfoque.dart';

/// El aviso de que se acaba el descanso. En la app, `AvisosDescansoLocales`;
/// en los tests, un falso.
abstract interface class AvisosDescanso {
  Future<void> programarFin(DateTime finUtc);
  Future<void> cancelar();
}

/// Lo que se apunta de cada ronda acabada de una tanda, para el resumen del
/// final (T-085): su sesión ([clave]), los minutos, si cuenta, en qué punto
/// está su envío y, enviada, los puntos y la XP que dio.
@immutable
class RondaHecha {
  const RondaHecha({
    required this.clave,
    required this.n,
    required this.minutos,
    required this.cuenta,
    required this.envio,
    this.monedas = 0,
    this.xp = 0,
  });

  /// La ronda [n] que acabó con [r].
  factory RondaHecha.de(ResultadoSesion r, int n) => RondaHecha(
    clave: r.clave,
    n: n,
    minutos: r.sesion.minutos,
    cuenta: r.sesion.estado.cuenta,
    envio: r.envio,
  ).conEnvio(r.envio, respuesta: r.respuesta);

  final String clave;
  final int n;
  final int minutos;

  /// Si la sesión cuenta (completada o terminada con el mínimo).
  final bool cuenta;
  final EnvioResultado envio;

  /// Los puntos de la ronda: los de la sesión (el premio) y los del hábito
  /// (el aporte). Solo enviada.
  final int monedas;

  /// La XP de Nori que dio la sesión. Solo enviada.
  final int xp;

  /// Pendiente o enviándose: sus puntos aún no se saben.
  bool get sinEnviar =>
      envio == EnvioResultado.enviando || envio == EnvioResultado.pendiente;

  /// La misma ronda con su envío en [envio] y, enviada, lo que pagó.
  RondaHecha conEnvio(EnvioResultado envio, {RespuestaSesion? respuesta}) {
    final enviada = envio == EnvioResultado.enviada;
    final premio = respuesta?.premio ?? Premio.vacio;
    final aporte = respuesta?.aporte ?? Aporte.vacio;
    return RondaHecha(
      clave: clave,
      n: n,
      minutos: minutos,
      cuenta: cuenta,
      envio: envio,
      monedas: enviada ? premio.monedas + aporte.monedas : 0,
      xp: enviada ? premio.xp : 0,
    );
  }

  Map<String, Object?> toJson() => {
    'clave': clave,
    'n': n,
    'minutos': minutos,
    'cuenta': cuenta,
    'envio': envio.name,
    'monedas': monedas,
    'xp': xp,
  };

  /// La ronda guardada, o `null` si no se entiende.
  static RondaHecha? fromJson(Object? json) {
    if (json is! Map) return null;
    final clave = json['clave'];
    final n = json['n'];
    final minutos = json['minutos'];
    final cuenta = json['cuenta'];
    final envio = EnvioResultado.values
        .where((e) => e.name == json['envio'])
        .firstOrNull;
    if (clave is! String || n is! int || minutos is! int) return null;
    if (cuenta is! bool || envio == null) return null;
    final monedas = json['monedas'];
    final xp = json['xp'];
    return RondaHecha(
      clave: clave,
      n: n,
      minutos: minutos,
      cuenta: cuenta,
      envio: envio,
      monedas: monedas is int ? monedas : 0,
      xp: xp is int ? xp : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RondaHecha &&
      other.clave == clave &&
      other.n == n &&
      other.minutos == minutos &&
      other.cuenta == cuenta &&
      other.envio == envio &&
      other.monedas == monedas &&
      other.xp == xp;

  @override
  int get hashCode =>
      Object.hash(clave, n, minutos, cuenta, envio, monedas, xp);
}

/// Lo de toda una tanda acabada (o cortada): las [rondas] que tenía y las
/// que se hicieron ([hechas]). Lo enseña el resultado de la última ronda.
@immutable
class ResumenTanda {
  const ResumenTanda({required this.rondas, required this.hechas});

  final int rondas;
  final List<RondaHecha> hechas;

  /// Las rondas que cuentan (completadas o terminadas con el mínimo).
  int get rondasQueCuentan => hechas.where((h) => h.cuenta).length;

  /// Si se hicieron todas y todas cuentan.
  bool get entera => hechas.length >= rondas && rondasQueCuentan >= rondas;

  /// Los minutos de las rondas que cuentan.
  int get minutos =>
      hechas.where((h) => h.cuenta).fold(0, (s, h) => s + h.minutos);

  /// Los puntos de las rondas enviadas.
  int get monedas => hechas.fold(0, (s, h) => s + h.monedas);

  /// La XP de las rondas enviadas.
  int get xp => hechas.fold(0, (s, h) => s + h.xp);

  /// Si alguna ronda que cuenta aún no está enviada (sus puntos no están en
  /// la suma).
  bool get algunaSinEnviar => hechas.any((h) => h.cuenta && h.sinEnviar);

  bool contiene(String clave) => hechas.any((h) => h.clave == clave);
}

/// La configuración con que se empezó una tanda (o una sesión suelta): lo
/// que repite «Otra igual».
typedef ConfiguracionTanda = ({
  int rondas,
  int minutos,
  int descanso,
  DestinoDisponible? destino,
});

/// Una tanda de rondas en marcha (diseño de Focus, 17-nov-2026): [rondas]
/// sesiones de [minutos] con [descanso] minutos entre una y otra.
///
/// Cada ronda es una sesión normal del motor, con su premio. La tanda
/// recuerda por cuál va, entre rondas cuándo acaba el descanso, y lo que dio
/// cada ronda acabada ([hechas]) para el resumen del final.
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
    this.hechas = const [],
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

  /// Lo que dio cada ronda acabada, por orden.
  final List<RondaHecha> hechas;

  bool get enDescanso => finDescansoUtc != null;
  bool get esLaUltima => ronda >= rondas;

  /// La misma tanda en [ronda] y con ese descanso (o sin él). Las rondas
  /// hechas se quedan.
  Tanda copiar({int? ronda, DateTime? finDescansoUtc, String? claveRonda}) =>
      Tanda(
        rondas: rondas,
        ronda: ronda ?? this.ronda,
        minutos: minutos,
        descanso: descanso,
        destino: destino,
        finDescansoUtc: finDescansoUtc,
        claveRonda: claveRonda,
        hechas: hechas,
      );

  /// La misma tanda, igual en todo, con estas rondas [hechas].
  Tanda conHechas(List<RondaHecha> hechas) => Tanda(
    rondas: rondas,
    ronda: ronda,
    minutos: minutos,
    descanso: descanso,
    destino: destino,
    finDescansoUtc: finDescansoUtc,
    claveRonda: claveRonda,
    hechas: hechas,
  );

  Map<String, Object?> toJson() => {
    'rondas': rondas,
    'ronda': ronda,
    'minutos': minutos,
    'descanso': descanso,
    'destino': ?destino?.toJson(),
    'finDescansoUtc': ?finDescansoUtc?.toUtc().toIso8601String(),
    'claveRonda': ?claveRonda,
    if (hechas.isNotEmpty) 'hechas': [for (final h in hechas) h.toJson()],
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
    final hechas = json['hechas'];
    return Tanda(
      rondas: rondas,
      ronda: ronda,
      minutos: minutos,
      descanso: descanso,
      destino: DestinoDisponible.fromJson(json['destino']),
      finDescansoUtc: fin is String ? DateTime.tryParse(fin)?.toUtc() : null,
      claveRonda: clave is String ? clave : null,
      hechas: [
        if (hechas is List)
          for (final h in hechas) ?RondaHecha.fromJson(h),
      ],
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
  }) : _ahoraUtc = ahoraUtc ?? (() => DateTime.now().toUtc()) {
    controlador.resultado.addListener(_alCambiarResultado);
    controlador.cola.pendientes.addListener(_alCambiarCola);
  }

  final ControladorEnfoque controlador;
  final AvisosDescanso avisos;
  final DateTime Function() _ahoraUtc;

  /// Dónde se guarda la tanda en `SharedPreferences`.
  final String clave;

  final ValueNotifier<Tanda?> _tanda = ValueNotifier(null);
  final ValueNotifier<ResumenTanda?> _resumen = ValueNotifier(null);
  ConfiguracionTanda? _ultimaConfiguracion;

  /// La tanda en marcha, o `null`.
  ValueListenable<Tanda?> get tanda => _tanda;

  /// Lo de toda la tanda que acaba de acabar (o cortarse), desde que acaba
  /// su última ronda hasta que se suelta el resultado o empieza otra. Solo
  /// en memoria: el resultado tampoco sobrevive a reiniciar la app.
  ValueListenable<ResumenTanda?> get resumen => _resumen;

  /// Con qué se empezó lo último (tanda o sesión suelta), para «Otra igual»,
  /// o `null` si en esta ejecución no se ha empezado nada.
  ConfiguracionTanda? get ultimaConfiguracion => _ultimaConfiguracion;

  DateTime ahoraUtc() => _ahoraUtc();

  void _alCambiarResultado() {
    final r = controlador.resultado.value;
    if (r == null) {
      // Se soltó el resultado: el resumen se va con él.
      _resumen.value = null;
      return;
    }
    _apuntar(r);
  }

  /// Apunta la ronda de [r] en la tanda en marcha, si es su ronda en curso,
  /// o la pone al día en el resumen, si ya está en él. Se puede llamar más
  /// de una vez con el mismo resultado: si no cambia nada, no se guarda.
  void _apuntar(ResultadoSesion r) {
    final ronda = rondaDeDatos(r.sesion.datosApp);
    if (ronda == null) return;
    final h = RondaHecha.de(r, ronda.n);
    List<RondaHecha> con(List<RondaHecha> hechas) => [
      for (final x in hechas) x.clave == h.clave ? h : x,
      if (!hechas.any((x) => x.clave == h.clave)) h,
    ];
    final t = _tanda.value;
    if (t != null && ronda.n == t.ronda && ronda.de == t.rondas) {
      _ponerHechas(con(t.hechas));
    } else if (_resumen.value?.contiene(h.clave) ?? false) {
      _ponerHechas(con(_resumen.value!.hechas));
    }
  }

  /// La cola ha cambiado: una ronda que estaba pendiente (o enviándose) y ya
  /// no lo está se pone al día con lo que dijo el backend. Así la suma sigue
  /// bien aunque el resultado de esa ronda ya se haya soltado (se empezó la
  /// siguiente antes de que llegara la respuesta).
  void _alCambiarCola() {
    RondaHecha alDia(RondaHecha h) {
      if (!h.sinEnviar) return h;
      return switch (controlador.cola.resultadoDe(h.clave)) {
        EnvioAceptado(:final respuesta) => h.conEnvio(
          EnvioResultado.enviada,
          respuesta: respuesta,
        ),
        EnvioRechazado() => h.conEnvio(EnvioResultado.noAceptada),
        _ => h,
      };
    }

    if (_tanda.value case final t?) {
      _ponerHechas([for (final h in t.hechas) alDia(h)]);
    } else if (_resumen.value case final res?) {
      _ponerHechas([for (final h in res.hechas) alDia(h)]);
    }
  }

  /// Pone [hechas] en la tanda en marcha (y la guarda) o, sin tanda, en el
  /// resumen. Si no cambia nada, no hace nada.
  void _ponerHechas(List<RondaHecha> hechas) {
    final t = _tanda.value;
    if (t != null) {
      if (listEquals(t.hechas, hechas)) return;
      unawaited(_poner(t.conHechas(List.unmodifiable(hechas))));
      return;
    }
    final res = _resumen.value;
    if (res == null || listEquals(res.hechas, hechas)) return;
    _resumen.value = ResumenTanda(
      rondas: res.rondas,
      hechas: List.unmodifiable(hechas),
    );
  }

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
    _ultimaConfiguracion = (
      rondas: rondas,
      minutos: minutos,
      descanso: descanso,
      destino: destino,
    );
    _resumen.value = null;
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
  /// completó y no era la última. Si no, la tanda se acaba y lo de todas sus
  /// rondas queda en [resumen]. Se puede llamar más de una vez con el mismo
  /// resultado.
  bool alAcabar(ResultadoSesion r) {
    // Por si quien avisa de [r] llega antes que el aviso del resultado.
    _apuntar(r);
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
    _resumen.value = esDeLaTanda
        ? ResumenTanda(rondas: t.rondas, hechas: t.hechas)
        : null;
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
      hechas: t.hechas,
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

  void dispose() {
    controlador.resultado.removeListener(_alCambiarResultado);
    controlador.cola.pendientes.removeListener(_alCambiarCola);
    _tanda.dispose();
    _resumen.dispose();
  }
}
