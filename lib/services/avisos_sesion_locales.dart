import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import 'tanda.dart';

/// Lo que los avisos necesitan del plugin. En la app, [SalidaAvisosPlugin];
/// en los tests, un falso que apunta las llamadas.
abstract interface class SalidaAvisos {
  Future<void> mostrar(
    int id,
    String titulo,
    String cuerpo,
    NotificationDetails detalles,
  );

  Future<void> programar(
    int id,
    String titulo,
    String cuerpo,
    DateTime cuandoUtc,
    NotificationDetails detalles,
  );

  Future<void> cancelar(int id);
}

/// [SalidaAvisos] con `flutter_local_notifications`.
class SalidaAvisosPlugin implements SalidaAvisos {
  SalidaAvisosPlugin([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Una vez, en `main()`. Tocar un aviso abre la app, que es lo único que
  /// tiene que hacer: la sesión se recompone sola al volver.
  Future<void> inicializar() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(iconoAvisos),
      ),
    );
  }

  @override
  Future<void> mostrar(
    int id,
    String titulo,
    String cuerpo,
    NotificationDetails detalles,
  ) => _plugin.show(
    id: id,
    title: titulo,
    body: cuerpo,
    notificationDetails: detalles,
  );

  @override
  Future<void> programar(
    int id,
    String titulo,
    String cuerpo,
    DateTime cuandoUtc,
    NotificationDetails detalles,
  ) => _plugin.zonedSchedule(
    id: id,
    title: titulo,
    body: cuerpo,
    // En UTC: así no hace falta saber la zona IANA del móvil (Dart no la da)
    // ni cargar la base de zonas de `timezone`. Un instante es un instante.
    scheduledDate: tz.TZDateTime.from(cuandoUtc.toUtc(), tz.UTC),
    notificationDetails: detalles,
    androidScheduleMode: modoProgramacionFin,
  );

  @override
  Future<void> cancelar(int id) => _plugin.cancel(id: id);
}

/// El icono pequeño de los avisos: `res/drawable/ic_stat_enfoque.xml`, una
/// silueta blanca sobre transparente, como pide Android
/// (https://developer.android.com/develop/ui/views/notifications/custom-notification#icon).
/// El plugin lo busca por nombre entre los drawables; lo protege de R8
/// `res/raw/keep.xml`. Provisional, hasta que haya icono definitivo.
const String iconoAvisos = 'ic_stat_enfoque';

/// Inexacto y que sale aunque el móvil esté en reposo, sin alarma exacta: no
/// pide `SCHEDULE_EXACT_ALARM` y vale para un aviso de fin, que puede llegar
/// algo tarde. https://developer.android.com/develop/background-work/services/alarms
const AndroidScheduleMode modoProgramacionFin =
    AndroidScheduleMode.inexactAllowWhileIdle;

/// Los avisos locales de la sesión: el de gracia al salir y el de fin.
///
/// Ids fijos por tipo, así que todas las llamadas son idempotentes, como
/// pide `AvisosSesion`. Los textos salen del core (`sesionAviso*`) en el
/// idioma activo, sin `BuildContext`; los nombres de los canales, de esta
/// app.
class AvisosSesionLocales implements AvisosSesion {
  AvisosSesionLocales({
    required this.salida,
    Locale Function()? idioma,
    DateTime Function()? ahoraUtc,
  }) : _idioma = idioma ?? (() => IdiomaService.localeNotifier.value),
       _ahoraUtc = ahoraUtc ?? (() => DateTime.now().toUtc());

  final SalidaAvisos salida;
  final Locale Function() _idioma;
  final DateTime Function() _ahoraUtc;

  static const int idGracia = 7101;
  static const int idFin = 7102;

  static const String canalGracia = 'enfoque_gracia';
  static const String canalFin = 'enfoque_fin';

  /// Si el fin cae a menos de esto, se muestra ya en vez de programarlo: el
  /// plugin rechaza una fecha pasada, y el motor llama a `programarFin` con
  /// la hora actual cuando la meta llega dentro de la gracia.
  static const Duration margenInmediato = Duration(seconds: 1);

  NordayCoreLocalizations get _core => lookupNordayCoreLocalizations(_idioma());
  AppLocalizations get _app => lookupAppLocalizations(_idioma());

  /// El aviso de gracia: importante (sale encima de la otra app) y caduca
  /// solo a [quedan] con `timeoutAfter`, porque pasada la gracia ya no dice
  /// la verdad
  /// (https://developer.android.com/reference/androidx/core/app/NotificationCompat.Builder#setTimeoutAfter(long)).
  static NotificationDetails detallesGracia(
    Duration quedan,
    AppLocalizations l,
  ) => NotificationDetails(
    android: AndroidNotificationDetails(
      canalGracia,
      l.canalGraciaNombre,
      channelDescription: l.canalGraciaDescripcion,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      timeoutAfter: quedan.inMilliseconds <= 0 ? 1 : quedan.inMilliseconds,
      onlyAlertOnce: true,
    ),
  );

  /// El aviso de fin: normal, se queda hasta que el usuario lo toca.
  static NotificationDetails detallesFin(AppLocalizations l) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          canalFin,
          l.canalFinNombre,
          channelDescription: l.canalFinDescripcion,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.status,
        ),
      );

  @override
  Future<void> avisarGracia(Duration quedan) {
    // Los segundos hacia arriba: «Si no vuelves en 10 s» y no en 9 cuando
    // quedan 9,6.
    final ms = quedan.inMilliseconds;
    final segundos = ms <= 0 ? 0 : (ms + 999) ~/ 1000;
    return salida.mostrar(
      idGracia,
      _core.sesionAvisoGraciaTitulo,
      _core.sesionAvisoGraciaCuerpo(segundos),
      detallesGracia(quedan, _app),
    );
  }

  @override
  Future<void> cancelarGracia() => salida.cancelar(idGracia);

  @override
  Future<void> programarFin(DateTime finUtc) {
    final titulo = _core.sesionAvisoFinTitulo;
    final cuerpo = _core.sesionAvisoFinCuerpo;
    final detalles = detallesFin(_app);
    if (!finUtc.toUtc().isAfter(_ahoraUtc().add(margenInmediato))) {
      return salida.mostrar(idFin, titulo, cuerpo, detalles);
    }
    return salida.programar(idFin, titulo, cuerpo, finUtc.toUtc(), detalles);
  }

  @override
  Future<void> cancelarFin() => salida.cancelar(idFin);
}

/// El aviso de que se acaba el descanso entre rondas, en su propio canal
/// (`enfoque_descanso`) e id fijo (7103): programarlo otra vez lo sustituye.
class AvisosDescansoLocales implements AvisosDescanso {
  AvisosDescansoLocales({
    required this.salida,
    Locale Function()? idioma,
    DateTime Function()? ahoraUtc,
  }) : _idioma = idioma ?? (() => IdiomaService.localeNotifier.value),
       _ahoraUtc = ahoraUtc ?? (() => DateTime.now().toUtc());

  final SalidaAvisos salida;
  final Locale Function() _idioma;
  final DateTime Function() _ahoraUtc;

  static const int idDescanso = 7103;
  static const String canalDescanso = 'enfoque_descanso';

  AppLocalizations get _app => lookupAppLocalizations(_idioma());

  /// Como el de fin: normal, se queda hasta que el usuario lo toca.
  static NotificationDetails detallesDescanso(AppLocalizations l) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          canalDescanso,
          l.canalDescansoNombre,
          channelDescription: l.canalDescansoDescripcion,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
        ),
      );

  @override
  Future<void> programarFin(DateTime finUtc) {
    final l = _app;
    final detalles = detallesDescanso(l);
    if (!finUtc.toUtc().isAfter(
      _ahoraUtc().add(AvisosSesionLocales.margenInmediato),
    )) {
      return salida.mostrar(
        idDescanso,
        l.avisoDescansoTitulo,
        l.avisoDescansoCuerpo,
        detalles,
      );
    }
    return salida.programar(
      idDescanso,
      l.avisoDescansoTitulo,
      l.avisoDescansoCuerpo,
      finUtc.toUtc(),
      detalles,
    );
  }

  @override
  Future<void> cancelar() => salida.cancelar(idDescanso);
}
