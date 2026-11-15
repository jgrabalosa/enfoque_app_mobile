import 'dart:io' show HttpDate;

import 'package:enfoque_app_mobile/services/desfase_servidor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El desfase servidor − móvil: de la cabecera Date, con histéresis, y solo
/// corrige por encima del umbral.
void main() {
  final movil = DateTime.utc(2026, 11, 16, 9);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sin medir: la hora del móvil tal cual', () {
    final d = DesfaseServidor();
    expect(d.desfase, isNull);
    expect(d.corregir(movil), movil);
  });

  test('móvil 3 minutos atrasado: se suma', () async {
    final d = DesfaseServidor();
    await d.registrar(movil.add(const Duration(minutes: 3)), movil);
    expect(d.desfase, const Duration(minutes: 3));
    expect(d.corregir(movil), movil.add(const Duration(minutes: 3)));
  });

  test('por debajo del umbral no se corrige', () async {
    final d = DesfaseServidor();
    await d.registrar(movil.add(const Duration(seconds: 2)), movil);
    expect(d.corregir(movil), movil);
  });

  test('histéresis: el ruido de ±1 s no cambia el desfase guardado', () async {
    final d = DesfaseServidor();
    await d.registrar(movil.subtract(const Duration(minutes: 2)), movil);
    await d.registrar(
      movil.subtract(const Duration(minutes: 2, seconds: 1)),
      movil,
    );
    expect(d.desfase, const Duration(minutes: -2));
    // Un salto de verdad (se cambió la hora del móvil) sí lo cambia.
    await d.registrar(movil.add(const Duration(hours: 1)), movil);
    expect(d.desfase, const Duration(hours: 1));
  });

  test('se guarda en el móvil y se lee al arrancar', () async {
    await DesfaseServidor().registrar(
      movil.add(const Duration(minutes: 10)),
      movil,
    );
    final otro = DesfaseServidor();
    await otro.cargar();
    expect(otro.desfase, const Duration(minutes: 10));
  });

  test('cabecera Date: se entiende; si falta o está rota, nada', () async {
    final d = DesfaseServidor();
    await d.registrarCabecera(null, movil);
    await d.registrarCabecera('ayer por la tarde', movil);
    expect(d.desfase, isNull);
    await d.registrarCabecera(
      HttpDate.format(movil.add(const Duration(minutes: 7))),
      movil,
    );
    expect(d.desfase, const Duration(minutes: 7));
  });
}
