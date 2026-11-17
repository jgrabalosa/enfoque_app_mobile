import '../models/enfoque.dart';
import '../models/enlace_entrada.dart';

/// Las reglas de duración de una sesión (diseño, sección 2): de 10 a 120
/// minutos, de 5 en 5, 25 por defecto. Las mismas que valida el backend.
/// Las usa la técnica Libre.
abstract final class Duraciones {
  static const int minima = 10;
  static const int maxima = 120;
  static const int paso = 5;
  static const int porDefecto = 25;

  /// Cinco más, sin pasar de [maxima].
  static int subir(int minutos) => ajustar(minutos + paso);

  /// Cinco menos, sin bajar de [minima].
  static int bajar(int minutos) => ajustar(minutos - paso);

  /// [minutos] dentro del rango y en un múltiplo de [paso] (hacia abajo).
  static int ajustar(int minutos) {
    final enRango = minutos.clamp(minima, maxima);
    return enRango - (enRango % paso);
  }
}

/// El destino de [destinos] que pide [pedido], o `null` si no está (no es un
/// hábito de minutos, no es del usuario o ya no existe).
DestinoDisponible? destinoPedidoEn(
  List<DestinoDisponible> destinos,
  DestinoPedido pedido,
) {
  for (final d in destinos) {
    if (d.tipo == pedido.tipo && d.id == pedido.id) return d;
  }
  return null;
}

/// El destino elegido tras recargar la lista: el mismo (con el progreso
/// nuevo) si sigue estando, o «sin hábito» si ya no.
DestinoDisponible? elegidoTrasRecargar(
  DestinoDisponible? elegido,
  List<DestinoDisponible> destinos,
) {
  if (elegido == null) return null;
  for (final d in destinos) {
    if (d.esElMismo(elegido)) return d;
  }
  return null;
}

/// Las técnicas de Inicio (diseño de Focus, 17-nov-2026): Pomodoro (25 min),
/// Profundo (50 min) y Libre (los minutos los elige el usuario, de 10 a 120).
///
/// Por ahora cada técnica es una sola sesión, sin descanso: las rondas y el
/// descanso llegan después (F-2).
enum Tecnica {
  pomodoro(25),
  profundo(50),
  libre(null);

  const Tecnica(this.minutosFijos);

  /// Los minutos de la técnica, o `null` en Libre (los elige el usuario).
  final int? minutosFijos;

  /// La de la primera vez.
  static const Tecnica porDefecto = Tecnica.pomodoro;

  /// La técnica guardada con [clave] ([Tecnica.name]), o [porDefecto] si no
  /// hay ninguna o no se entiende.
  static Tecnica deClave(String? clave) {
    for (final t in values) {
      if (t.name == clave) return t;
    }
    return porDefecto;
  }

  /// Los minutos de la sesión con esta técnica; en Libre, [minutosLibre]
  /// dentro de las reglas de [Duraciones].
  int minutos(int minutosLibre) =>
      minutosFijos ?? Duraciones.ajustar(minutosLibre);
}

/// Dónde se recuerda la última técnica elegida en Inicio.
const String claveTecnica = 'enfoque_tecnica';

/// Dónde se recuerdan los últimos minutos de Libre.
const String claveMinutosLibre = 'enfoque_minutos_libre';
