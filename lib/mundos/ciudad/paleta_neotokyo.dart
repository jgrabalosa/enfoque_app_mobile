import 'dart:ui';

/// Los colores de la ciudad: los de la identidad Neotokyo+ (fondo
/// `#090614`, rosa `#FF2E88`, cian `#00E5FF`, amarillo `#FFE347`), más un
/// violeta para el cuarto neón. Fijos: la ciudad de Neotokyo+ se ve igual
/// lleves la identidad que lleves.
abstract final class PaletaNeotokyo {
  static const Color fondo = Color(0xFF090614);
  static const Color superficie = Color(0xFF110B21);
  static const Color rosa = Color(0xFFFF2E88);
  static const Color cian = Color(0xFF00E5FF);
  static const Color amarillo = Color(0xFFFFE347);
  static const Color violeta = Color(0xFFA06BFF);
  static const Color texto = Color(0xFFF5EEFF);

  /// Los neones de los edificios, por [Edificio.neon].
  static const List<Color> neones = [rosa, cian, amarillo, violeta];

  /// Las fachadas: oscuras y frías abajo, algo más claras arriba.
  static const Color fachadaAbajo = Color(0xFF5A4C7A);
  static const Color fachadaArriba = Color(0xFFE6DCFF);

  /// Los tejados.
  static const Color tejado = Color(0xFF2A2045);
}
