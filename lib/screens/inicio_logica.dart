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
/// Pomodoro y Profundo van por rondas (de 1 a [Rondas.maximo]), con un
/// descanso entre una y otra: 5 minutos en Pomodoro y 10 en Profundo. Libre
/// es siempre una sola sesión.
enum Tecnica {
  pomodoro(25, 5),
  profundo(50, 10),
  libre(null, null);

  const Tecnica(this.minutosFijos, this.minutosDescanso);

  /// Los minutos de la técnica, o `null` en Libre (los elige el usuario).
  final int? minutosFijos;

  /// El descanso entre rondas, o `null` si no va por rondas (Libre).
  final int? minutosDescanso;

  /// Si se puede repetir en rondas.
  bool get conRondas => minutosDescanso != null;

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

/// Las rondas de una tanda: de 1 a 4, 1 por defecto.
abstract final class Rondas {
  static const int minimo = 1;
  static const int maximo = 4;
  static const int porDefecto = 1;

  static int ajustar(int rondas) => rondas.clamp(minimo, maximo);
}

/// Dónde se recuerdan las últimas rondas elegidas.
const String claveRondas = 'enfoque_rondas';

/// Los minutos de una tanda entera: las rondas y los descansos de en medio
/// (después de la última no hay descanso).
int minutosTanda({
  required int rondas,
  required int minutos,
  required int descanso,
}) => rondas * minutos + (rondas - 1) * descanso;
