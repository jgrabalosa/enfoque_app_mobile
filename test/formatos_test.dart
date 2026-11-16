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

  test('destino desde una hora: cada cifra en horas y minutos', () async {
    DestinoDisponible leer(int dia, int objetivo) =>
        destinoLeer.conProgreso(dia, objetivo);
    for (final idioma in ['es', 'en', 'pt']) {
      final t = await l(idioma);
      expect(textoDestino(t, destinoLeerLargo), 'Leer · 1 h / 1 h 30 min');
      expect(textoDestino(t, leer(59, 59)), 'Leer · 59 / 59 min');
      expect(textoDestino(t, leer(45, 60)), 'Leer · 45 min / 1 h');
      expect(textoDestino(t, leer(61, 120)), 'Leer · 1 h 1 min / 2 h');
      expect(textoDestino(t, leer(0, 90)), 'Leer · 0 min / 1 h 30 min');
    }
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
    const a = Aporte(
      estado: EstadoAporte.aceptado,
      minutos: 25,
      minutosDia: 30,
      minutosObjetivo: 30,
    );
    expect(textoAporte(await l('es'), a, 'Leer'), '+25 min a Leer (30 / 30)');
    expect(textoAporte(await l('en'), a, 'Leer'), '+25 min to Leer (30 / 30)');
    expect(
      textoAporte(await l('pt'), a, 'Leer'),
      '+25 min para Leer (30 / 30)',
    );
  });

  test('resultado desde una hora: en horas y minutos', () async {
    const largo = Aporte(
      estado: EstadoAporte.aceptado,
      minutos: 90,
      minutosDia: 90,
      minutosObjetivo: 120,
    );
    const borde = Aporte(
      estado: EstadoAporte.aceptado,
      minutos: 59,
      minutosDia: 59,
      minutosObjetivo: 60,
    );
    const sinProgreso = Aporte(estado: EstadoAporte.aceptado, minutos: 60);
    final es = await l('es');
    expect(
      textoAporte(es, largo, 'Leer'),
      '+1 h 30 min a Leer (1 h 30 min / 2 h)',
    );
    expect(textoAporte(es, borde, 'Leer'), '+59 min a Leer (59 min / 1 h)');
    expect(textoAporte(es, sinProgreso, 'Leer'), '+1 h a Leer');
    expect(
      textoAporte(await l('en'), largo, 'Leer'),
      '+1 h 30 min to Leer (1 h 30 min / 2 h)',
    );
    expect(textoAporte(await l('pt'), sinProgreso, 'Leer'), '+1 h para Leer');
  });

  test(
    'fila del historial: «25 de 25 min» y, desde una hora, en horas',
    () async {
      final es = await l('es');
      expect(textoFilaSesion(es, 25, 25, 'Leer'), '25 de 25 min · Leer');
      expect(textoFilaSesion(es, 59, 59, 'Leer'), '59 de 59 min · Leer');
      expect(textoFilaSesion(es, 45, 60, 'Leer'), '45 min de 1 h · Leer');
      expect(textoFilaSesion(es, 61, 120, 'Leer'), '1 h 1 min de 2 h · Leer');
      expect(
        textoFilaSesion(await l('en'), 90, 120, 'Leer'),
        '1 h 30 min of 2 h · Leer',
      );
      expect(
        textoFilaSesion(await l('pt'), 90, 120, 'Leer'),
        '1 h 30 min de 2 h · Leer',
      );
    },
  );

  test(
    'la cifra de hoy se llama «tiempo», no «minutos»: puede ir en horas',
    () async {
      expect((await l('es')).inicioTiempoHoy, 'Tiempo hoy');
      expect((await l('en')).inicioTiempoHoy, 'Time today');
      expect((await l('pt')).inicioTiempoHoy, 'Tempo hoje');
    },
  );

  test('el nombre de la app es el mismo en los tres idiomas', () async {
    for (final idioma in ['es', 'en', 'pt']) {
      expect((await l(idioma)).appNombre, 'Norday Focus');
    }
  });

  test('plurales', () async {
    final es = await l('es');
    expect(es.inicioRachaDias(1), '1 día');
    expect(es.inicioRachaDias(3), '3 días');
    expect(es.resultadoMonedas(1), '+1 punto');
    expect(es.resultadoMonedas(10), '+10 puntos');
  });

  test('los textos compuestos de Estadísticas salen del ARB', () async {
    for (final idioma in ['es', 'en', 'pt']) {
      final t = await l(idioma);
      expect(
        t.estTotalEtiqueta(t.estSemana, duracionLegible(t, 40)),
        '${t.estSemana}: 40 min',
      );
      expect(
        t.filaSesionCuandoEstado('16 nov 09:00', t.estadoCompletada),
        '16 nov 09:00 · ${t.estadoCompletada}',
      );
    }
  });
}
