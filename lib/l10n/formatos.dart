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
/// va una vez al final, como siempre: «20 / 30 min». Si alguno llega a la
/// hora, cada cifra con [duracionLegible]: «45 min / 1 h 30 min».
String progresoLegible(AppLocalizations l, int hecho, int objetivo) =>
    hecho < 60 && objetivo < 60
    ? l.progresoMinutos(hecho < 0 ? 0 : hecho, objetivo < 0 ? 0 : objetivo)
    : l.progresoDuraciones(
        duracionLegible(l, hecho),
        duracionLegible(l, objetivo),
      );

/// Un destino con su progreso de hoy: «Leer · 20 / 30 min»,
/// «Leer · 1 h / 1 h 30 min».
String textoDestino(AppLocalizations l, DestinoDisponible d) =>
    l.destinoProgreso(
      nombreDestino(l, d),
      progresoLegible(l, d.minutosDia, d.minutosObjetivo),
    );
