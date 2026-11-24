# La parte nativa y los avisos locales

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

## La parte nativa (`MainActivity.kt`)

Un solo canal, `com.norday.enfoque/sistema`, en los dos sentidos:

| Sentido | Método | Qué |
|---|---|---|
| Dart → Android | `monotonicoMs` | `SystemClock.elapsedRealtime()` |
| Dart → Android | `encendidaYDesbloqueada` | `PowerManager.isInteractive && !KeyguardManager.isKeyguardLocked` |
| Dart → Android | `abrir` | `{enlace?, paquete?}`: con enlace, `ACTION_VIEW` (+`setPackage`); sin enlace, `getLaunchIntentForPackage(paquete)`. `FLAG_ACTIVITY_NEW_TASK`. Devuelve si se abrió |
| Dart → Android | `enlaceInicial` | el enlace de arranque, una sola vez |
| Android → Dart | `desbloqueo` | `ACTION_USER_PRESENT` |
| Android → Dart | `enlace` | un enlace con la app abierta (`onNewIntent`) |

- **El receptor de `ACTION_USER_PRESENT` se registra en tiempo de ejecución**
  (en `onCreate`, se suelta en `onDestroy`), no en el manifest: Android 8+
  no entrega broadcasts implícitos a receptores de manifest y este no está
  entre las excepciones. Va con `RECEIVER_EXPORTED` en Android 13+ (es un
  broadcast protegido del sistema).
- **El enlace de entrada** `norday-enfoque://sesion?destino=habito&id=N`:
  intent-filter `VIEW`+`DEFAULT`+`BROWSABLE`, actividad `singleTop` y
  exportada. `flutter_deeplinking_enabled = false`: si no, Flutter empujaría
  la ruta del enlace en un Navigator sin rutas con nombre. El destino se
  aplica en Inicio en cuanto hay lista; si no está en ella, aviso y «Sin
  hábito». Si la app se abre desde Recientes
  (`FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`), el enlace del intent original se
  ignora.
- `<queries>` con `com.norday.habitos` y `com.norday.habitos.prueba`. La Focus
  de prueba abre la Habits de prueba.

Cada API va comentada en Kotlin con su URL de developer.android.com.

## Avisos locales

`flutter_local_notifications` 22.3.x (`">=22.3.3 <23.0.0"`), aquí y no en
el core (decisión del core del 15-nov-2026: en el core rompería el build de
Habits).

- Gracia: canal `enfoque_gracia`, importancia alta, `timeoutAfter = quedan`
  (caduca sola al vencer la gracia). Id fijo 7101.
- Fin: canal `enfoque_fin`, programado en UTC con
  `AndroidScheduleMode.inexactAllowWhileIdle`, sin alarmas exactas. Id fijo
  7102. Si el fin ya ha llegado, se muestra en el acto (el plugin rechaza
  fechas pasadas).
- Sin `SCHEDULE_EXACT_ALARM`, sin `RECEIVE_BOOT_COMPLETED` ni el receptor de
  arranque del plugin: tras un reinicio la sesión está perdida y no hay fin
  que avisar. Sí `ScheduledNotificationReceiver`.
- **El toolchain es el de Habits** (`compileSdk = flutter.compileSdkVersion`,
  AGP 9.0.1, Gradle 9.1.0). Lo único que añade: desugaring con
  `desugar_jdk_libs:2.1.4` y `multiDexEnabled`, que pide la 22.3.3 en su
  README.
- El icono pequeño es `res/drawable/ic_stat_enfoque.xml`: un aro con una
  aguja, blanco sobre transparente, genérico y provisional. Protegido de R8
  en `res/raw/keep.xml`. Se sustituye por el definitivo cuando haya icono.
