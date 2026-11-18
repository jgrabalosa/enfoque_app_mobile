import '../azar.dart';

/// El nombre de cada parterre («Rincón de las Abejas»), sacado de la
/// semilla. Se escribe a mano, a lápiz, junto al parterre.
///
/// **Provisional:** solo para el laboratorio. Los nombres definitivos, en es,
/// en y pt, se deciden con el diseño final.
abstract final class NombresParterres {
  static const List<String> _tipos = ['Parterre', 'Rincón', 'Macizo', 'Bancal'];

  static const List<String> _de = [
    'las Abejas',
    'la Brisa',
    'las Mariposas',
    'la Lluvia',
    'los Gorriones',
    'la Siesta',
    'las Luciérnagas',
    'el Rocío',
    'la Tarde',
    'los Secretos',
    'la Abuela',
    'las Cartas',
    'el Té',
    'las Nubes',
    'el Verano',
    'la Luna',
    'los Domingos',
    'las Cometas',
    'la Merienda',
    'los Caracoles',
  ];

  static String de(int semilla, int parterre) {
    final tipo =
        _tipos[(azarMundo(semilla, parterre, 61) * _tipos.length).floor()];
    final de = _de[(azarMundo(semilla, parterre, 62) * _de.length).floor()];
    return '$tipo de $de';
  }
}
