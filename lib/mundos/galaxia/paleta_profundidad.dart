import 'dart:ui';

/// Los colores de la galaxia. Son los de la identidad Profundidad (fondo
/// `#070D19` y amarillo `#FFB020`), fijos: el mundo de Profundidad se ve igual
/// aunque lleves puesta otra identidad.
///
/// Las estrellas van en tonos cálidos, del crema al ámbar, para que jueguen
/// con el amarillo de la identidad (Quim, 18-nov). La de hoy sigue siendo el
/// amarillo de verdad, más saturado que todas las demás.
abstract final class PaletaProfundidad {
  static const Color fondo = Color(0xFF070D19);
  static const Color amarillo = Color(0xFFFFB020);

  /// Los tonos de las estrellas normales, por variante: crema, oro pálido,
  /// ámbar, blanca cálida, doble (crema) y con destello (oro pálido).
  static const List<Color> estrellas = [
    Color(0xFFFFF1D6),
    Color(0xFFFFE2A6),
    Color(0xFFFFC978),
    Color(0xFFFFF8EC),
    Color(0xFFFFF1D6),
    Color(0xFFFFE7B8),
  ];

  /// Las líneas de las constelaciones: oro apagado.
  static const Color linea = Color(0xFFD9B77A);
}
