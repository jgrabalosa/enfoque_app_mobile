/// Las fechas de Estadísticas, sin widgets ni red.
///
/// La semana empieza en lunes, como en Norday Habits y en el backend.
abstract final class FechasEstadisticas {
  /// El lunes de la semana de [hoy].
  static DateTime lunes(DateTime hoy) {
    final d = DateTime(hoy.year, hoy.month, hoy.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  /// El día 1 del mes de [hoy].
  static DateTime primeroDeMes(DateTime hoy) => DateTime(hoy.year, hoy.month);

  /// Desde dónde pedir el resumen para tener la semana y el mes: lo que
  /// llegue antes, el lunes o el día 1. Como mucho 37 días, por debajo del
  /// tope de 62 del backend.
  static DateTime desde(DateTime hoy) {
    final a = lunes(hoy);
    final b = primeroDeMes(hoy);
    return a.isBefore(b) ? a : b;
  }

  /// Los siete días de la semana de [hoy], de lunes a domingo. Se construyen
  /// con el constructor de fecha y no sumando 24 horas, para que un cambio
  /// de hora no repita ni salte un día.
  static List<DateTime> semana(DateTime hoy) {
    final l = lunes(hoy);
    return [for (var i = 0; i < 7; i++) DateTime(l.year, l.month, l.day + i)];
  }
}
