import 'package:enfoque_app_mobile/models/enlace_entrada.dart';
import 'package:flutter_test/flutter_test.dart';

/// El enlace de entrada que manda Norday Habits:
/// norday-enfoque://sesion?destino=habito&id=N.
void main() {
  test('el enlace de Norday Habits', () {
    expect(
      destinoDeEnlace('norday-enfoque://sesion?destino=habito&id=16'),
      const DestinoPedido('habito', 16),
    );
  });

  test('es el que construye abrir_enfoque.dart de Habits (Uri con query)', () {
    final uri = Uri(
      scheme: 'norday-enfoque',
      host: 'sesion',
      queryParameters: {'destino': 'habito', 'id': '7'},
    );
    expect(destinoDeEnlace(uri.toString()), const DestinoPedido('habito', 7));
  });

  test('el orden de los parámetros da igual', () {
    expect(
      destinoDeEnlace('norday-enfoque://sesion?id=3&destino=habito'),
      const DestinoPedido('habito', 3),
    );
  });

  test('lo que no vale, null', () {
    for (final malo in [
      null,
      '',
      'https://norday.app/sesion?destino=habito&id=1',
      'norday-enfoque://otra?destino=habito&id=1',
      'norday-enfoque://sesion?destino=habito',
      'norday-enfoque://sesion?id=1',
      'norday-enfoque://sesion?destino=&id=1',
      'norday-enfoque://sesion?destino=habito&id=0',
      'norday-enfoque://sesion?destino=habito&id=-4',
      'norday-enfoque://sesion?destino=habito&id=abc',
      'norday-enfoque://sesion?destino=habito&id=1.5',
    ]) {
      expect(destinoDeEnlace(malo), isNull, reason: '$malo');
    }
  });
}
