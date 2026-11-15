import '../models/enfoque.dart';
import 'app_localizations.dart';

/// [minutos] en horas y minutos: «45 min», «1 h», «1 h 30 min». La única
/// regla de duración de la app: menos de 60, en minutos; desde 60, en horas
/// y los minutos que sobren. Se guarda y se envía siempre en minutos; los
/// chips, el selector de duración y la cuenta atrás no pasan por aquí.
String duracionLegible(AppLocalizations l, int minutos) {
  final total = minutos < 0 ? 0 : minutos;
  final horas = total ~/ 60;
  final resto = total % 60;
  if (horas == 0) return l.durMinutos(resto);
  if (resto == 0) return l.durHoras(horas);
  return l.durHorasMinutos(horas, resto);
}

/// El nombre de un destino, o «Hábito» si el backend no mandó ninguno.
String nombreDestino(AppLocalizations l, DestinoDisponible d) =>
    d.nombre.trim().isEmpty ? l.filaSesionHabito : d.nombre;

/// Lo hecho de un objetivo. Si los dos son de menos de una hora, la unidad
/// va una vez al final, como siempre: «20 / 30 min» (o sin ella si
/// [conUnidad] es false, porque ya va delante: «30 / 30»). Si alguno llega a
/// la hora, cada cifra con [duracionLegible]: «45 min / 1 h 30 min».
String progresoLegible(
  AppLocalizations l,
  int hecho,
  int objetivo, {
  bool conUnidad = true,
}) {
  if (hecho < 60 && objetivo < 60) {
    final h = hecho < 0 ? 0 : hecho;
    final o = objetivo < 0 ? 0 : objetivo;
    return conUnidad ? l.progresoMinutos(h, o) : l.progresoCifras(h, o);
  }
  return l.progresoDuraciones(
    duracionLegible(l, hecho),
    duracionLegible(l, objetivo),
  );
}

/// Un destino con su progreso de hoy: «Leer · 20 / 30 min»,
/// «Leer · 1 h / 1 h 30 min».
String textoDestino(AppLocalizations l, DestinoDisponible d) =>
    l.destinoProgreso(
      nombreDestino(l, d),
      progresoLegible(l, d.minutosDia, d.minutosObjetivo),
    );

/// Lo que la sesión llevó al hábito: «+25 min a Leer (30 / 30)»,
/// «+1 h 30 min a Leer (1 h 30 min / 2 h)», o «+25 min a Leer» si no llega
/// su progreso.
String textoAporte(AppLocalizations l, Aporte a, String nombre) {
  final duracion = duracionLegible(l, a.minutos);
  final dia = a.minutosDia;
  final objetivo = a.minutosObjetivo;
  if (dia == null || objetivo == null) {
    return l.resultadoAporteSinProgreso(duracion, nombre);
  }
  return l.resultadoAporteAceptado(
    duracion,
    nombre,
    progresoLegible(l, dia, objetivo, conUnidad: false),
  );
}
