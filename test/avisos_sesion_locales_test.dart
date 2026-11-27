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

class _SalidaEnCurso implements SalidaEnCurso {
  final List<
    ({
      int id,
      String titulo,
      String? cuerpo,
      AndroidNotificationDetails detalles,
    })
  >
  arrancadas = [];
  int paradas = 0;

  @override
  Future<void> arrancarServicio(
    int id,
    String titulo,
    String? cuerpo,
    AndroidNotificationDetails detalles,
  ) async => arrancadas.add((
    id: id,
    titulo: titulo,
    cuerpo: cuerpo,
    detalles: detalles,
  ));

  @override
  Future<void> pararServicio() async => paradas++;
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

  group('notificación en curso', () {
    late _SalidaEnCurso enCurso;
    final fin = ahora.add(const Duration(minutes: 25));

    setUp(() => enCurso = _SalidaEnCurso());

    AvisoEnCursoLocal aviso([String idioma = 'es']) =>
        AvisoEnCursoLocal(salida: enCurso, idioma: () => Locale(idioma));

    test('fija, callada y con la cuenta atrás hasta el fin', () async {
      await aviso().arrancar(fin, null);
      final a = enCurso.arrancadas.single;
      expect(a.id, AvisoEnCursoLocal.idEnCurso);
      expect(a.id, isNot(anyOf(7101, 7102, 7103)));
      expect(a.titulo, 'Norday Focus');
      expect(a.cuerpo, isNull);
      final d = a.detalles;
      expect(d.channelId, 'enfoque_en_curso');
      expect(d.channelName, 'Sesión en curso');
      expect(d.importance, Importance.low);
      expect(d.playSound, isFalse);
      expect(d.enableVibration, isFalse);
      expect(d.ongoing, isTrue);
      expect(d.onlyAlertOnce, isTrue);
      expect(d.usesChronometer, isTrue);
      expect(d.chronometerCountDown, isTrue);
      expect(d.showWhen, isTrue);
      expect(d.when, fin.millisecondsSinceEpoch);
      expect(d.icon, iconoAvisos);
    });

    test('con ronda, la ronda en el texto; en inglés también', () async {
      await aviso().arrancar(fin, (n: 1, de: 2));
      await aviso('en').arrancar(fin, (n: 2, de: 3));
      expect(enCurso.arrancadas[0].cuerpo, 'Ronda 1 de 2');
      expect(enCurso.arrancadas[1].cuerpo, 'Round 2 of 3');
      expect(enCurso.arrancadas[1].titulo, 'Norday Focus');
    });

    test('parar quita el servicio', () async {
      await aviso().parar();
      expect(enCurso.paradas, 1);
    });

    test('el manifiesto declara el servicio specialUse con sus permisos', () {
      final manifiesto = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifiesto, contains('android.permission.FOREGROUND_SERVICE"'));
      expect(
        manifiesto,
        contains('android.permission.FOREGROUND_SERVICE_SPECIAL_USE'),
      );
      expect(
        manifiesto,
        contains('com.dexterous.flutterlocalnotifications.ForegroundService'),
      );
      expect(
        manifiesto,
        contains('android:foregroundServiceType="specialUse"'),
      );
      expect(
        manifiesto,
        contains('android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE'),
      );
    });
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
