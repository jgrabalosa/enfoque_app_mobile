import 'dart:ui';

import 'flores.dart';

/// Los colores del jardín de Dulce: el papel de la identidad y una caja de
/// lápices de colores, con el rosa como color principal.
abstract final class PaletaDulce {
  /// El papel: el fondo de Dulce (`#FFFCF5`).
  static const Color papel = Color(0xFFFFFCF5);

  /// El grafito del boceto.
  static const Color grafito = Color(0xFF5A5560);

  /// La caja de lápices. Tonos de lápiz de color de verdad: algo menos
  /// saturados que los de una pantalla.
  static const List<Color> lapices = [
    Color(0xFFE85A8A), // 0 rosa (el de Dulce)
    Color(0xFFF29BBF), // 1 rosa claro
    Color(0xFFC2367A), // 2 magenta
    Color(0xFFD9473A), // 3 rojo
    Color(0xFFF07A5A), // 4 coral
    Color(0xFFF0943A), // 5 naranja
    Color(0xFFF2C230), // 6 amarillo
    Color(0xFF9C7BD0), // 7 lila
    Color(0xFF6F8FD6), // 8 azul
    Color(0xFFE6D3DF), // 9 blanco (su sombra, algo rosada)
  ];

  /// Qué colores puede tener cada flor. El rosa sale en casi todas.
  static const Map<EspecieFlor, List<int>> coloresDe = {
    EspecieFlor.margarita: [9, 9, 1, 6],
    EspecieFlor.cosmos: [0, 1, 1, 2, 9],
    EspecieFlor.amapola: [3, 4, 5, 0],
    EspecieFlor.rosa: [0, 0, 2, 3, 6, 1],
    EspecieFlor.hortensia: [7, 8, 1],
  };

  /// El centro de cada flor.
  static const Map<EspecieFlor, Color> centroDe = {
    EspecieFlor.margarita: Color(0xFFF2B630),
    EspecieFlor.cosmos: Color(0xFFF2C230),
    EspecieFlor.amapola: Color(0xFF3A2A40),
    EspecieFlor.rosa: Color(0xFFB0306A),
    EspecieFlor.hortensia: Color(0xFFF7E9A0),
  };

  static const List<Color> verdes = [
    Color(0xFF5E9A4A),
    Color(0xFF4E8A50),
    Color(0xFF78A84E),
  ];

  /// La grava de los caminos y la tierra.
  static const Color grava = Color(0xFFB8A48A);
  static const Color tierra = Color(0xFF9A7A5E);

  /// El agua de la fuente y del estanque.
  static const Color agua = Color(0xFF6FA8D6);

  /// La madera de la pérgola, el banco y el puente.
  static const Color madera = Color(0xFFA9774E);
}
