# enfoque_app_mobile — Norday Focus

App Android de **Norday Focus**, el temporizador de concentración del
ecosistema **Norday**. Versión en desarrollo: 1.0.0 (1). Aún no está en
Google Play (`com.norday.enfoque`).

## Qué hace

- **Sesiones de concentración con bloqueo suave**: de 10 a 120 minutos, de 5
  en 5 (25 por defecto), sin pausas. Si sales a otra app con la pantalla
  encendida, tienes 10 segundos para volver (con aviso, si hay permiso); si
  no vuelves, la sesión se pierde. Apagar o bloquear la pantalla no cuenta
  como salir.
- **Terminar antes** cuenta con los minutos hechos si son 10 o más; si no, se
  descarta sin castigo. **Rendirse** la pierde.
- **Minutos a un hábito**: una sesión puede ir a un hábito de minutos de
  Norday Habits (cuenta compartida). Los minutos se suman al hábito y es el
  hábito quien paga, con sus reglas. Sin hábito, la sesión cuenta para las
  estadísticas, sin premio.
- **Inicio**: minutos y sesiones de hoy, racha de enfoque, duración y destino
  («Leer · 20 / 30 min»).
- **Resultado** de cada sesión: «+25 min a Leer (30 / 30)», las monedas del
  hábito o el motivo si el hábito no los aceptó.
- **Estadísticas**: minutos por día de la semana, totales de la semana y del
  mes, e historial (incluidas las sesiones pendientes de enviar).
- **Sin conexión**: las sesiones acabadas se guardan en el móvil y se envían
  en cuanto hay red.
- Comparte con Norday Habits la cuenta, las monedas, las tres identidades
  visuales y a Nori. Menú con Nori, tienda, logros, colección y perfil.
- En **español, inglés y portugués**.

Pestañas: Inicio y Estadísticas, más el menú.

## Stack

Flutter 3.44.4 (Dart 3.12) · Android · Firebase (Crashlytics y
notificaciones) · `flutter_local_notifications` 22.3 · Lucide Icons. El backend
es [`habitos-app`](https://github.com/jgrabalosa/habitos-app) (módulo
`enfoque`, `/api/enfoque`).

Todo lo genérico (sesión, motor de la sesión con bloqueo suave, tienda,
mascota, logros, identidades, perfil) vive en el paquete
[`norday_flutter_core`](https://github.com/jgrabalosa/norday_flutter_core),
que esta app consume por tag. Aquí sólo vive lo que sabe de enfoque.

## Compilar

Hace falta, fuera de Git:

- `android/app/google-services.json` (Firebase), con las dos apps de Focus
  dadas de alta en el **mismo proyecto que Norday Habits**
  (`habitos-app-5a054`): `com.norday.enfoque` y `com.norday.enfoque.prueba`.
  Tiene que ser ese proyecto: el login con Google del core usa el cliente
  web de ese proyecto, y los push los manda ese mismo backend.
- `android/key.properties` y el keystore, sólo para builds de release.

Hay dos variantes (flavors), y **siempre se indica una** con `--flavor`:

| Flavor | Paquete | Nombre | Backend |
|---|---|---|---|
| `produccion` | `com.norday.enfoque` | Norday Focus | Producción (por defecto) |
| `prueba` | `com.norday.enfoque.prueba` | Norday Focus PRUEBA | Staging, con `--dart-define` |

Al arrancar, la app comprueba que el flavor y la URL del backend van juntos
(`lib/entorno.dart`). Si no cuadran, se para en «Entorno incorrecto» sin hacer
ninguna petición.

App de prueba contra staging. Se instala junto a la de Play, sin sustituirla:

```powershell
flutter pub get
flutter run --flavor prueba --dart-define=NORDAY_API_URL=https://staging-api.norday.app/api
```

Para dejarla instalada y usarla sin cable:

```powershell
flutter build apk --debug --flavor prueba --dart-define=NORDAY_API_URL=https://staging-api.norday.app/api
adb install -r build\app\outputs\flutter-apk\app-prueba-debug.apk
```

Probar el enlace de entrada (con un hábito de minutos tuyo, id 16):

```powershell
adb shell am start -a android.intent.action.VIEW -d "norday-enfoque://sesion?destino=habito&id=16" com.norday.enfoque.prueba
```

**Nunca se instala `--flavor produccion` en un móvil que tenga la app de
Play** (cuando exista): mismo paquete, otra firma.

Los `app_localizations*.dart` se generan al compilar y no se versionan.

### Toolchain de Android

El mismo que Norday Habits: `compileSdk = flutter.compileSdkVersion` (36 en
Flutter 3.44.4), Android Gradle Plugin 9.0.1 y Gradle 9.1.0. Lo único que
añade, porque lo pide `flutter_local_notifications` 22.3.3, es el
desugaring (`isCoreLibraryDesugaringEnabled` y `desugar_jdk_libs:2.1.4`) y
`multiDexEnabled`.

**Nada del Gradle ni del Kotlin se ha compilado aún**: se escribió en una
máquina sin SDK de Android. El primer `flutter build apk` lo dirá.

## Lo que tiene que hacer Quim antes de publicar

Norday Focus sale a la vez que la versión de Norday Habits con hábitos de
minutos. La guía del despliegue conjunto está en `docs/despliegue.md` del
backend (`habitos-app`); aquí, solo lo que toca a esta app.

1. **GitHub**: crear el repo en GitHub y subir la rama `wip`. Hoy solo existe
   en local, sin remoto: no hay copia fuera de esta máquina ni forma de
   revisar el diff en el remoto.
2. **Firebase**: dar de alta `com.norday.enfoque` y `com.norday.enfoque.prueba`
   en `habitos-app-5a054`, con la huella SHA-1 de depuración de cada máquina
   y la de la clave de subida. Para `com.norday.enfoque`, además, la SHA-1
   de la **clave de firma de apps de Play** (Play Console → Integridad de la
   app → Firma de apps), que solo existe cuando la app está creada en Play:
   la app instalada desde Play va firmada con esa, no con la de subida.
   Bajar `google-services.json` y dejarlo en `android/app/`.
3. **Google Cloud**: un cliente OAuth Android por paquete y huella, incluida
   la de firma de apps de Play (Firebase sola no basta para Google Sign-In;
   es la lección de Habits). Sin ella, el login con Google falla en la app
   de Play aunque funcione en una build local.
4. **Primer build**: nada del Gradle ni del Kotlin se ha compilado nunca (ver
   «Toolchain de Android»). Primero `flutter build apk --debug --flavor
   prueba` con el `--dart-define` de staging, y probar en un móvil la parte
   nativa (`MainActivity.kt`, avisos y el enlace de entrada) antes de pensar
   en un `.aab`.
5. **Tag del core**: poner `v0.55.0` en `norday_flutter_core` y seguir los
   pasos de «Pendiente con el core 0.55.0» de `CLAUDE.md` (quitar el
   override, `flutter pub upgrade norday_flutter_core`, comprobar el
   `resolved-ref` y commitear el `pubspec.lock`).
6. **Icono, splash y gráficos de Play**: Norday Focus no tiene aún ni icono
   ni símbolo. Hoy lleva el icono por defecto de Flutter y el splash pinta a
   Nori sobre Azul Noche. Cuando los haya, en `store/` y
   `assets/branding/`, con `flutter_launcher_icons` y
   `flutter_native_splash` como en Habits. El icono pequeño de los avisos
   es un vector propio y genérico (`res/drawable/ic_stat_enfoque.xml`, un
   aro con aguja): se puede sustituir por el definitivo con el mismo nombre
   (silueta blanca sobre transparente).
7. **Política de privacidad y URL de borrado de cuenta**: la ficha de Play
   pide las dos. Las de `norday.app` (`privacidad.html` y
   `eliminar-cuenta.html`, en el backend) hoy solo hablan de Norday Habits.
   **A decidir**: ampliarlas a Norday Focus o hacer unas propias.
8. **Prueba cerrada**: comprobar en Play Console si la cuenta exige una
   prueba cerrada antes de que una app nueva pueda salir a Producción, y
   contar con ese plazo.
9. **Orden de salida con Norday Habits**: Norday Habits con «Empezar sesión»
   no sale a Producción hasta que Norday Focus sea visible en Producción (o
   salen a la vez): sin ella, el botón lleva a una ficha que no existe. En
   prueba cerrada solo vale si los testers de Habits también lo son de
   Focus.
10. **Backend**: desplegar `wip-enfoque` (módulo `enfoque`, `AppNorday`
    con `enfoque`, `version_app` V25) antes de que nadie use la app.

## Documentación

- [`CLAUDE.md`](CLAUDE.md) — arquitectura, reglas obligatorias, decisiones y
  lecciones aprendidas.
