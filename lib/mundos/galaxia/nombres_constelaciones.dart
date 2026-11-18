import 'colocador_galaxia.dart';

/// El nombre de cada constelación («La Grulla Errante»), sacado de la semilla.
///
/// **Provisional:** solo en español y solo para el laboratorio. Los nombres
/// definitivos, en es, en y pt, se deciden en MU-5.
abstract final class NombresConstelaciones {
  /// (nombre, femenino).
  static const List<(String, bool)> _figuras = [
    ('Farol', false),
    ('Grulla', true),
    ('Ballena', true),
    ('Arpa', true),
    ('Zorro', false),
    ('Puente', false),
    ('Reloj', false),
    ('Cometa', false),
    ('Lince', false),
    ('Faro', false),
    ('Ancla', true),
    ('Cuervo', false),
    ('Llave', true),
    ('Brújula', true),
    ('Lámpara', true),
    ('Velero', false),
    ('Halcón', false),
    ('Corona', true),
    ('Tortuga', true),
    ('Ciervo', false),
    ('Campana', true),
    ('Medusa', true),
    ('Búho', false),
    ('Cometa de papel', true),
    ('Liebre', true),
    ('Delfín', false),
    ('Tetera', true),
    ('Pluma', true),
    ('Caracol', false),
    ('Mariposa', true),
  ];

  /// (masculino, femenino).
  static const List<(String, String)> _apellidos = [
    ('Errante', 'Errante'),
    ('Dormido', 'Dormida'),
    ('de Plata', 'de Plata'),
    ('del Alba', 'del Alba'),
    ('Pequeño', 'Pequeña'),
    ('del Norte', 'del Norte'),
    ('Silencioso', 'Silenciosa'),
    ('Antiguo', 'Antigua'),
    ('de la Lluvia', 'de la Lluvia'),
    ('Valiente', 'Valiente'),
  ];

  static String de(int semilla, int constelacion) {
    final (figura, femenino) =
        _figuras[(azarGalaxia(semilla, constelacion, 31) * _figuras.length)
            .floor()];
    final articulo = femenino ? 'La' : 'El';
    // Dos de cada tres llevan apellido: así se repiten menos.
    if (azarGalaxia(semilla, constelacion, 32) < 1 / 3) {
      return '$articulo $figura';
    }
    final (m, f) =
        _apellidos[(azarGalaxia(semilla, constelacion, 33) * _apellidos.length)
            .floor()];
    return '$articulo $figura ${femenino ? f : m}';
  }
}
