/// Una pieza del mundo de una identidad: lo que deja cada sesión completada.
///
/// Lleva lo mismo que guardará el backend (`encargos/focus-mundos.md` §7): el
/// número dentro de ese mundo, la identidad, de qué app sale y cuándo. **No
/// lleva posición:** el sitio de cada pieza se calcula a partir del número y
/// de la semilla del usuario, así que el dibujo se puede mejorar sin tocar
/// datos. Tampoco lleva tamaño: todas las piezas valen igual.
class PiezaMundo {
  const PiezaMundo({
    required this.numero,
    required this.identidad,
    required this.origenApp,
    required this.creadaEn,
  });

  /// Desde 0: la primera pieza de ese mundo es la 0.
  final int numero;

  /// El código de la identidad (`profundidad`, `neotokyo`, `dulce`).
  final String identidad;

  /// `enfoque` (y, más adelante, `habitos`).
  final String origenApp;

  final DateTime creadaEn;
}

/// De dónde salen las piezas de un mundo. Hoy, [FuenteFalsa]; cuando exista
/// la tabla del backend (MU-6), una fuente que las pida a la API.
abstract interface class FuenteMundo {
  Future<List<PiezaMundo>> piezas(String identidad);
}

/// Piezas inventadas en el móvil, para el laboratorio: [cantidad] piezas, una
/// por día hacia atrás desde [hasta].
class FuenteFalsa implements FuenteMundo {
  FuenteFalsa(this.cantidad, {DateTime? hasta})
    : hasta = hasta ?? DateTime.now();

  final int cantidad;
  final DateTime hasta;

  @override
  Future<List<PiezaMundo>> piezas(String identidad) async => [
    for (var n = 0; n < cantidad; n++)
      PiezaMundo(
        numero: n,
        identidad: identidad,
        origenApp: 'enfoque',
        creadaEn: hasta.subtract(Duration(days: cantidad - 1 - n)),
      ),
  ];
}
