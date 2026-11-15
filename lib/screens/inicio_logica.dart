import '../models/enfoque.dart';
import '../models/enlace_entrada.dart';

/// Las reglas de duración de una sesión (diseño, sección 2): de 10 a 120
/// minutos, de 5 en 5, 25 por defecto. Las mismas que valida el backend.
abstract final class Duraciones {
  static const int minima = 10;
  static const int maxima = 120;
  static const int paso = 5;
  static const int porDefecto = 25;

  /// Los chips de Inicio.
  static const List<int> rapidas = [15, 25, 45, 60];

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
