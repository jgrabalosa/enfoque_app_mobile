import 'dart:ui';

/// Los colores de la galaxia. Son los de la identidad Profundidad (fondo
/// `#070D19` y amarillo `#FFB020`), fijos: el mundo de Profundidad se ve igual
/// aunque lleves puesta otra identidad.
abstract final class PaletaProfundidad {
  static const Color fondo = Color(0xFF070D19);
  static const Color amarillo = Color(0xFFFFB020);

  /// Los tonos de las estrellas normales, por variante: blanca, azulada,
  /// amarilla, rojiza, doble (blanca) y con destello (azulada).
  static const List<Color> estrellas = [
    Color(0xFFF2F5FF),
    Color(0xFFB9D0FF),
    Color(0xFFFFE6B0),
    Color(0xFFFFB9A0),
    Color(0xFFF2F5FF),
    Color(0xFFCFE0FF),
  ];

  /// Las líneas de las constelaciones.
  static const Color linea = Color(0xFF8FB3FF);
}
