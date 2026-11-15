import 'dart:io';

import 'package:enfoque_app_mobile/services/avisos_sesion_locales.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _Salida implements SalidaAvisos {
  final List<String> llamadas = [];
  final List<
    ({
      int id,
      String titulo,
      String cuerpo,
      DateTime? cuando,
      NotificationDetails detalles,
    })
  >
  avisos = [];

  @override
  Future<void> mostrar(
    int id,
    String titulo,
    String cuerpo,
    NotificationDetails detalles,
  ) async {
    llamadas.add('mostrar $id');
    avisos.add((
      id: id,
      titulo: titulo,
      cuerpo: cuerpo,
      cuando: null,
      detalles: detalles,
    ));
  }

  @override
  Future<void> programar(
    int id,
    String titulo,
    String cuerpo,
    DateTime cuandoUtc,
    NotificationDetails detalles,
  ) async {
    llamadas.add('programar $id');
    avisos.add((
      id: id,
      titulo: titulo,
      cuerpo: cuerpo,
      cuando: cuandoUtc,
      detalles: detalles,
    ));
  }

  @override
  Future<void> cancelar(int id) async => llamadas.add('cancelar $id');
}

/// Los avisos de la sesión: la gracia caduca sola, el fin es inexacto y todo
/// va con ids fijos (idempotente).
void main() {
  final ahora = DateTime.utc(2026, 11, 16, 9);
  late _Salida salida;
  late AvisosSesionLocales avisos;

  setUp(() {
    salida = _Salida();
    avisos = AvisosSesionLocales(
      salida: salida,
      idioma: () => const Locale('es'),
      ahoraUtc: () => ahora,
    );
  });

  test('gracia: aviso importante que caduca a lo que queda', () async {
    await avisos.avisarGracia(const Duration(milliseconds: 9400));
    final a = salida.avisos.single;
    expect(a.id, AvisosSesionLocales.idGracia);
    expect(a.titulo, 'Vuelve a tu sesión');
    // Los segundos hacia arriba: quedan 9,4 → «10 s».
    expect(a.cuerpo, 'Si no vuelves en 10 s, la pierdes.');
    final android = a.detalles.android!;
    expect(android.timeoutAfter, 9400);
    expect(android.channelId, AvisosSesionLocales.canalGracia);
    expect(android.importance, Importance.high);
    expect(android.channelName, 'Aviso al salir de la sesión');
  });

  test('gracia ya vencida: caduca en el acto, no nunca', () async {
    await avisos.avisarGracia(Duration.zero);
    expect(salida.avisos.single.detalles.android!.timeoutAfter, 1);
  });

  test('fin en el futuro: se programa en UTC, inexacto', () async {
    final fin = ahora.add(const Duration(minutes: 25));
    await avisos.programarFin(fin);
    final a = salida.avisos.single;
    expect(salida.llamadas, ['programar ${AvisosSesionLocales.idFin}']);
    expect(a.cuando, fin);
    expect(a.cuando!.isUtc, isTrue);
    expect(a.titulo, 'Sesión completada');
    expect(a.detalles.android!.channelId, AvisosSesionLocales.canalFin);
    expect(modoProgramacionFin, AndroidScheduleMode.inexactAllowWhileIdle);
  });

  test(
    'fin ya llegado: se muestra ahora (el plugin rechaza el pasado)',
    () async {
      await avisos.programarFin(ahora);
      expect(salida.llamadas, ['mostrar ${AvisosSesionLocales.idFin}']);
      await avisos.programarFin(ahora.subtract(const Duration(minutes: 1)));
      expect(salida.llamadas.last, 'mostrar ${AvisosSesionLocales.idFin}');
    },
  );

  test('cancelar usa los mismos ids', () async {
    await avisos.cancelarGracia();
    await avisos.cancelarFin();
    expect(salida.llamadas, [
      'cancelar ${AvisosSesionLocales.idGracia}',
      'cancelar ${AvisosSesionLocales.idFin}',
    ]);
  });

  test('en inglés y portugués, los textos del core', () async {
    final en = AvisosSesionLocales(
      salida: salida,
      idioma: () => const Locale('en'),
      ahoraUtc: () => ahora,
    );
    await en.avisarGracia(const Duration(seconds: 10));
    final pt = AvisosSesionLocales(
      salida: salida,
      idioma: () => const Locale('pt'),
      ahoraUtc: () => ahora,
    );
    await pt.avisarGracia(const Duration(seconds: 10));
    expect(salida.avisos[0].titulo, isNot(salida.avisos[1].titulo));
    expect(salida.avisos[0].cuerpo, contains('10'));
    expect(salida.avisos[1].cuerpo, contains('10'));
  });

  test('el icono pequeño es el drawable monocromo propio y R8 lo conserva', () {
    expect(iconoAvisos, 'ic_stat_enfoque');
    final icono = File(
      'android/app/src/main/res/drawable/$iconoAvisos.xml',
    ).readAsStringSync();
    expect(icono, contains('<vector'));
    expect(
      File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
      contains('@drawable/$iconoAvisos'),
    );
  });
}
