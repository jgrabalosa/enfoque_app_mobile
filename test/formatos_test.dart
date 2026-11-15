import 'package:enfoque_app_mobile/l10n/app_localizations.dart';
import 'package:enfoque_app_mobile/l10n/formatos.dart';
import 'package:enfoque_app_mobile/models/enfoque.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'datos_prueba.dart';

/// Los textos con cifras del diseño: «Leer · 20 / 30 min» y «+25 min a Leer
/// (30 / 30)», en los tres idiomas.
void main() {
  Future<AppLocalizations> l(String idioma) =>
      AppLocalizations.delegate.load(Locale(idioma));

  test('duraciones: menos de 60 en min; desde 60, en h y min', () async {
    const esperado = {
      0: '0 min',
      1: '1 min',
      59: '59 min',
      60: '1 h',
      61: '1 h 1 min',
      90: '1 h 30 min',
      120: '2 h',
      125: '2 h 5 min',
    };
    for (final idioma in ['es', 'en', 'pt']) {
      final t = await l(idioma);
      esperado.forEach((minutos, texto) {
        expect(duracionLegible(t, minutos), texto, reason: '$idioma, $minutos');
      });
    }
  });

  test('una duración negativa se enseña como 0 min', () async {
    expect(duracionLegible(await l('es'), -5), '0 min');
  });

  test('destino con su progreso: «Leer · 20 / 30 min»', () async {
    expect(textoDestino(await l('es'), destinoLeer), 'Leer · 20 / 30 min');
    expect(textoDestino(await l('en'), destinoLeer), 'Leer · 20 / 30 min');
    expect(textoDestino(await l('pt'), destinoLeer), 'Leer · 20 / 30 min');
  });

  test('un destino sin nombre se llama «Hábito»', () async {
    const sinNombre = DestinoDisponible(
      tipo: 'habito',
      id: 1,
      nombre: '  ',
      minutosDia: 0,
      minutosObjetivo: 15,
    );
    expect(textoDestino(await l('es'), sinNombre), 'Hábito · 0 / 15 min');
    expect(textoDestino(await l('en'), sinNombre), 'Habit · 0 / 15 min');
  });

  test('resultado: «+25 min a Leer (30 / 30)»', () async {
    expect(
      (await l('es')).resultadoAporteAceptado(25, 'Leer', 30, 30),
      '+25 min a Leer (30 / 30)',
    );
    expect(
      (await l('en')).resultadoAporteAceptado(25, 'Leer', 30, 30),
      '+25 min to Leer (30 / 30)',
    );
    expect(
      (await l('pt')).resultadoAporteAceptado(25, 'Leer', 30, 30),
      '+25 min para Leer (30 / 30)',
    );
  });

  test('el nombre de la app es el mismo en los tres idiomas', () async {
    for (final idioma in ['es', 'en', 'pt']) {
      expect((await l(idioma)).appNombre, 'Norday Focus');
    }
  });

  test('plurales', () async {
    final es = await l('es');
    expect(es.inicioRachaDias(1), '1 día');
    expect(es.inicioRachaDias(3), '3 días');
    expect(es.resultadoMonedas(1), '+1 moneda');
    expect(es.resultadoMonedas(10), '+10 monedas');
    expect(es.resultadoMinutos(1), '1 minuto');
  });

  test('los textos compuestos de Estadísticas salen del ARB', () async {
    for (final idioma in ['es', 'en', 'pt']) {
      final t = await l(idioma);
      expect(
        t.estTotalEtiqueta(t.estSemana, '40 min'),
        '${t.estSemana}: 40 min',
      );
      expect(
        t.filaSesionCuandoEstado('16 nov 09:00', t.estadoCompletada),
        '16 nov 09:00 · ${t.estadoCompletada}',
      );
    }
  });
}
