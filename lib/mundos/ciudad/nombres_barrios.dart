import '../azar.dart';

/// El nombre de cada manzana («Barrio Hikari 3»), sacado de la semilla.
///
/// **Provisional:** solo para el laboratorio. Los nombres definitivos, en es,
/// en y pt, se deciden con el diseño final.
abstract final class NombresBarrios {
  static const List<String> _tipos = ['Barrio', 'Distrito', 'Manzana'];

  /// Palabras japonesas cortas y fáciles de leer: luz, viento, cerezo…
  static const List<String> _palabras = [
    'Hikari',
    'Kaze',
    'Sakura',
    'Yoru',
    'Ame',
    'Hoshi',
    'Kumo',
    'Neko',
    'Tora',
    'Kitsune',
    'Umi',
    'Yuki',
    'Sora',
    'Tsuki',
    'Hana',
    'Mori',
    'Kawa',
    'Hotaru',
    'Kage',
    'Akari',
    'Shizuka',
    'Raijin',
    'Momiji',
    'Kiri',
  ];

  static String de(int semilla, int manzana) {
    final tipo =
        _tipos[(azarMundo(semilla, manzana, 61) * _tipos.length).floor()];
    final palabra =
        _palabras[(azarMundo(semilla, manzana, 62) * _palabras.length).floor()];
    final numero = 1 + (azarMundo(semilla, manzana, 63) * 9).floor();
    return '$tipo $palabra $numero';
  }
}
