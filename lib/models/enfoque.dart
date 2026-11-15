// Los modelos del contrato de /api/enfoque (habitos-app, módulo `enfoque`,
// EnfoqueController). El parseo es tolerante: un campo que falta o llega con
// otro tipo cae en un valor neutro en vez de romper la pantalla, salvo los
// que identifican algo (la clave, el id de un destino), que son obligatorios.

/// Un entero de un JSON que puede llegar como `int`, como `double` o como
/// texto. `null` si no es nada de eso.
int? enteroDe(Object? v) => switch (v) {
  int() => v,
  double() => v.toInt(),
  String() => int.tryParse(v),
  _ => null,
};

String? textoDe(Object? v) => v is String ? v : null;

bool? boolDe(Object? v) => v is bool ? v : null;

Map<String, Object?>? mapaDe(Object? v) =>
    v is Map ? v.cast<String, Object?>() : null;

List<Object?> listaDe(Object? v) => v is List ? v : const [];

/// Un día `YYYY-MM-DD` como fecha local a medianoche, o `null`.
DateTime? diaDe(Object? v) {
  final t = textoDe(v);
  if (t == null) return null;
  final d = DateTime.tryParse(t);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// `YYYY-MM-DD` de [dia].
String textoDia(DateTime dia) =>
    '${dia.year.toString().padLeft(4, '0')}-'
    '${dia.month.toString().padLeft(2, '0')}-'
    '${dia.day.toString().padLeft(2, '0')}';

/// A dónde pueden ir los minutos de una sesión: hoy, un hábito de minutos.
/// `GET /api/enfoque/destinos` →
/// `{"destinos":[{"tipo":"habito","id":16,"nombre":"Leer","minutosDia":25,"minutosObjetivo":30}]}`.
class DestinoDisponible {
  final String tipo;
  final int id;
  final String nombre;

  /// Minutos ya llevados hoy.
  final int minutosDia;

  /// Minutos objetivo de hoy.
  final int minutosObjetivo;

  const DestinoDisponible({
    required this.tipo,
    required this.id,
    required this.nombre,
    required this.minutosDia,
    required this.minutosObjetivo,
  });

  /// `null` si falta el tipo o el id: sin ellos no se puede enviar.
  static DestinoDisponible? fromJson(Object? json) {
    final m = mapaDe(json);
    if (m == null) return null;
    final tipo = textoDe(m['tipo']);
    final id = enteroDe(m['id']);
    if (tipo == null || tipo.isEmpty || id == null || id <= 0) return null;
    return DestinoDisponible(
      tipo: tipo,
      id: id,
      nombre: textoDe(m['nombre']) ?? '',
      minutosDia: enteroDe(m['minutosDia']) ?? 0,
      minutosObjetivo: enteroDe(m['minutosObjetivo']) ?? 0,
    );
  }

  /// Lo que se guarda con la sesión (`datosApp`), para pintarla y enviarla
  /// aunque el proceso muera.
  Map<String, Object?> toJson() => {
    'tipo': tipo,
    'id': id,
    'nombre': nombre,
    'minutosDia': minutosDia,
    'minutosObjetivo': minutosObjetivo,
  };

  /// El mismo destino con otro progreso.
  DestinoDisponible conProgreso(int minutosDia, int minutosObjetivo) =>
      DestinoDisponible(
        tipo: tipo,
        id: id,
        nombre: nombre,
        minutosDia: minutosDia,
        minutosObjetivo: minutosObjetivo,
      );

  /// Es el mismo destino (tipo e id), tenga el progreso que tenga.
  bool esElMismo(DestinoDisponible otro) => otro.tipo == tipo && otro.id == id;
}

/// La lista de `GET /api/enfoque/destinos`. Lo que no se entiende se salta.
List<DestinoDisponible> destinosDe(Object? json) => [
  for (final d in listaDe(mapaDe(json)?['destinos']))
    ?DestinoDisponible.fromJson(d),
];

/// Cómo acabó una sesión, tal como la entiende el backend.
enum EstadoEnvio {
  completada('COMPLETADA'),
  terminada('TERMINADA'),
  perdida('PERDIDA');

  const EstadoEnvio(this.codigo);
  final String codigo;

  static EstadoEnvio? deCodigo(Object? codigo) {
    for (final e in values) {
      if (e.codigo == codigo) return e;
    }
    return null;
  }

  /// Suma minutos.
  bool get cuenta => this != perdida;
}

/// El cuerpo de `POST /api/enfoque/sesiones`. Se guarda tal cual en la cola:
/// un reintento manda exactamente el mismo cuerpo con la misma clave.
class PeticionSesion {
  /// UUID canónico, generado al empezar la sesión.
  final String clave;

  /// Instante de inicio en UTC.
  final DateTime inicioUtc;
  final int duracionSeg;
  final int duracionObjetivoMin;
  final EstadoEnvio estado;

  /// `{tipo, id}`, o `null` sin destino.
  final String? destinoTipo;
  final int? destinoId;

  const PeticionSesion({
    required this.clave,
    required this.inicioUtc,
    required this.duracionSeg,
    required this.duracionObjetivoMin,
    required this.estado,
    this.destinoTipo,
    this.destinoId,
  });

  bool get conDestino => destinoTipo != null && destinoId != null;

  Map<String, Object?> toJson() => {
    'clave': clave,
    // toIso8601String de un DateTime en UTC acaba en Z: lo que pide el
    // contrato («ISO-8601 UTC con Z»).
    'inicioUtc': inicioUtc.toUtc().toIso8601String(),
    'duracionSeg': duracionSeg,
    'duracionObjetivoMin': duracionObjetivoMin,
    'estado': estado.codigo,
    'destino': conDestino ? {'tipo': destinoTipo, 'id': destinoId} : null,
  };

  /// `null` si no se entiende (cola escrita por otra versión, datos rotos).
  static PeticionSesion? fromJson(Object? json) {
    final m = mapaDe(json);
    if (m == null) return null;
    final clave = textoDe(m['clave']);
    final inicio = DateTime.tryParse(textoDe(m['inicioUtc']) ?? '');
    final duracion = enteroDe(m['duracionSeg']);
    final objetivo = enteroDe(m['duracionObjetivoMin']);
    final estado = EstadoEnvio.deCodigo(m['estado']);
    if (clave == null ||
        inicio == null ||
        duracion == null ||
        objetivo == null ||
        estado == null) {
      return null;
    }
    final destino = mapaDe(m['destino']);
    return PeticionSesion(
      clave: clave,
      inicioUtc: inicio.toUtc(),
      duracionSeg: duracion,
      duracionObjetivoMin: objetivo,
      estado: estado,
      destinoTipo: textoDe(destino?['tipo']),
      destinoId: enteroDe(destino?['id']),
    );
  }

  /// Minutos que suma: enteros hacia abajo, solo si cuenta.
  int get minutos => estado.cuenta ? duracionSeg ~/ 60 : 0;
}

/// Qué pasó con los minutos de una sesión en su destino.
enum EstadoAporte {
  sinDestino('SIN_DESTINO'),
  pendiente('PENDIENTE'),
  aceptado('ACEPTADO'),
  repetido('REPETIDO'),
  rechazado('RECHAZADO'),

  /// Un estado que esta versión de la app no conoce.
  desconocido('');

  const EstadoAporte(this.codigo);
  final String codigo;

  static EstadoAporte deCodigo(Object? codigo) {
    for (final e in values) {
      if (e != desconocido && e.codigo == codigo) return e;
    }
    return desconocido;
  }
}

/// El `aporte` de la respuesta de `POST /api/enfoque/sesiones` (o, con menos
/// campos, de cada sesión del historial).
class Aporte {
  final EstadoAporte estado;

  /// Clave del motivo de rechazo (p. ej. `enfoque.aporte.sesion.perdida`).
  final String? motivo;

  /// El motivo ya traducido por el backend al idioma del usuario.
  final String? motivoTexto;
  final int minutos;
  final int monedas;
  final int xp;
  final int? minutosDia;
  final int? minutosObjetivo;
  final bool? diaHecho;

  /// Códigos de los logros que desbloqueó el destino.
  final List<String> logros;

  const Aporte({
    required this.estado,
    this.motivo,
    this.motivoTexto,
    this.minutos = 0,
    this.monedas = 0,
    this.xp = 0,
    this.minutosDia,
    this.minutosObjetivo,
    this.diaHecho,
    this.logros = const [],
  });

  static const Aporte vacio = Aporte(estado: EstadoAporte.desconocido);

  factory Aporte.fromJson(Object? json) {
    final m = mapaDe(json);
    if (m == null) return vacio;
    return Aporte(
      estado: EstadoAporte.deCodigo(m['estado']),
      motivo: textoDe(m['motivo']),
      motivoTexto: textoDe(m['motivoTexto']),
      minutos: enteroDe(m['minutos']) ?? 0,
      monedas: enteroDe(m['monedas']) ?? 0,
      xp: enteroDe(m['xp']) ?? 0,
      minutosDia: enteroDe(m['minutosDia']),
      minutosObjetivo: enteroDe(m['minutosObjetivo']),
      diaHecho: boolDe(m['diaHecho']),
      logros: [
        for (final l in listaDe(m['logros']))
          if (l is String && l.isNotEmpty) l,
      ],
    );
  }
}

/// Una sesión guardada en el backend (`sesion` de la respuesta, o cada
/// elemento del historial).
class SesionServidor {
  final String clave;
  final DateTime? inicioUtc;
  final int duracionSeg;
  final int duracionObjetivoMin;

  /// `null` si el backend manda un estado que esta versión no conoce.
  final EstadoEnvio? estado;

  /// El día de la sesión en la zona del usuario.
  final DateTime? dia;
  final int minutos;
  final String? destinoTipo;
  final int? destinoId;
  final Aporte aporte;

  const SesionServidor({
    required this.clave,
    this.inicioUtc,
    this.duracionSeg = 0,
    this.duracionObjetivoMin = 0,
    this.estado,
    this.dia,
    this.minutos = 0,
    this.destinoTipo,
    this.destinoId,
    this.aporte = Aporte.vacio,
  });

  static SesionServidor? fromJson(Object? json, {Object? aporte}) {
    final m = mapaDe(json);
    if (m == null) return null;
    final clave = textoDe(m['clave']);
    if (clave == null) return null;
    final destino = mapaDe(m['destino']);
    final inicio = DateTime.tryParse(textoDe(m['inicioUtc']) ?? '');
    return SesionServidor(
      clave: clave,
      inicioUtc: inicio?.toUtc(),
      duracionSeg: enteroDe(m['duracionSeg']) ?? 0,
      duracionObjetivoMin: enteroDe(m['duracionObjetivoMin']) ?? 0,
      estado: EstadoEnvio.deCodigo(m['estado']),
      dia: diaDe(m['dia']),
      minutos: enteroDe(m['minutos']) ?? 0,
      destinoTipo: textoDe(destino?['tipo']),
      destinoId: enteroDe(destino?['id']),
      aporte: Aporte.fromJson(aporte ?? m['aporte']),
    );
  }
}

/// `201`/`200` de `POST /api/enfoque/sesiones`: `{sesion, aporte}`.
class RespuestaSesion {
  final SesionServidor? sesion;
  final Aporte aporte;

  const RespuestaSesion({this.sesion, this.aporte = Aporte.vacio});

  factory RespuestaSesion.fromJson(Object? json) {
    final m = mapaDe(json);
    return RespuestaSesion(
      sesion: SesionServidor.fromJson(m?['sesion'], aporte: m?['aporte']),
      aporte: Aporte.fromJson(m?['aporte']),
    );
  }
}

/// Un día del resumen.
class DiaResumen {
  final DateTime dia;
  final int minutos;
  final int sesiones;

  const DiaResumen({
    required this.dia,
    required this.minutos,
    required this.sesiones,
  });
}

/// `GET /api/enfoque/resumen?desde=&hasta=`. Solo cuentan COMPLETADA y
/// TERMINADA.
class ResumenEnfoque {
  final List<DiaResumen> dias;
  final int totalMinutos;
  final int totalSesiones;

  /// Días seguidos con al menos una sesión que cuenta, terminando hoy o ayer.
  final int rachaActual;

  const ResumenEnfoque({
    this.dias = const [],
    this.totalMinutos = 0,
    this.totalSesiones = 0,
    this.rachaActual = 0,
  });

  factory ResumenEnfoque.fromJson(Object? json) {
    final m = mapaDe(json);
    final dias = <DiaResumen>[];
    for (final d in listaDe(m?['dias'])) {
      final dm = mapaDe(d);
      final dia = diaDe(dm?['dia']);
      if (dm == null || dia == null) continue;
      dias.add(
        DiaResumen(
          dia: dia,
          minutos: enteroDe(dm['minutos']) ?? 0,
          sesiones: enteroDe(dm['sesiones']) ?? 0,
        ),
      );
    }
    return ResumenEnfoque(
      dias: dias,
      totalMinutos: enteroDe(m?['totalMinutos']) ?? 0,
      totalSesiones: enteroDe(m?['totalSesiones']) ?? 0,
      rachaActual: enteroDe(m?['rachaActual']) ?? 0,
    );
  }

  /// El día [dia], o uno vacío si el resumen no lo trae.
  DiaResumen delDia(DateTime dia) {
    for (final d in dias) {
      if (d.dia.year == dia.year &&
          d.dia.month == dia.month &&
          d.dia.day == dia.day) {
        return d;
      }
    }
    return DiaResumen(dia: dia, minutos: 0, sesiones: 0);
  }

  /// Minutos de los días entre [desde] y [hasta], ambos incluidos.
  int minutosEntre(DateTime desde, DateTime hasta) {
    final d0 = DateTime(desde.year, desde.month, desde.day);
    final d1 = DateTime(hasta.year, hasta.month, hasta.day);
    return dias
        .where((d) => !d.dia.isBefore(d0) && !d.dia.isAfter(d1))
        .fold(0, (s, d) => s + d.minutos);
  }
}

/// `GET /api/enfoque/sesiones?pagina=&tamano=`.
class PaginaHistorial {
  final List<SesionServidor> sesiones;
  final int pagina;
  final int tamano;
  final int total;
  final bool hayMas;

  const PaginaHistorial({
    this.sesiones = const [],
    this.pagina = 0,
    this.tamano = 0,
    this.total = 0,
    this.hayMas = false,
  });

  factory PaginaHistorial.fromJson(Object? json) {
    final m = mapaDe(json);
    return PaginaHistorial(
      sesiones: [
        for (final s in listaDe(m?['sesiones'])) ?SesionServidor.fromJson(s),
      ],
      pagina: enteroDe(m?['pagina']) ?? 0,
      tamano: enteroDe(m?['tamano']) ?? 0,
      total: enteroDe(m?['total']) ?? 0,
      hayMas: boolDe(m?['hayMas']) ?? false,
    );
  }
}
