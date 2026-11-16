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
- `android/key.properties` y el keystore, sólo para builds de release. La
  clave de subida de Focus es **propia, no la de Habits** (creada el
  15-nov-2026, alias `norday-enfoque`). El keystore y las contraseñas no
  van en ningún repo.

Hay dos variantes (flavors), y **siempre se indica una** con `--flavor`:

| Flavor | Paquete | Nombre | Backend |
|---|---|---|---|
| `produccion` | `com.norday.enfoque` | Norday Focus | Producción (por defecto) |
| `prueba` | `com.norday.enfoque.prueba` | Norday Focus PRUEBA | Staging, con `--dart-define` |

Al arrancar, la app comprueba que el flavor y la URL del backend van juntos
(`lib/entorno.dart`). Si no cuadran, se para en «Entorno incorrecto» sin hacer
ninguna petición.

La de prueba lleva una **cinta «PRUEBA»** arriba a la derecha en todas las
pantallas, también al iniciar sesión: sin cinta, estás en producción. Y nunca
abre Google Play: si falta Norday PRUEBA, «Crea hábitos en Norday Habits» lo
dice en vez de llevar a la ficha, que abre la Habits de producción.

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

Se compiló por primera vez el 15-nov-2026, en debug y con el flavor
`prueba`. El mismo día compiló la primera build de release (AAB con
`--flavor produccion`, que pasa por R8), firmada con la clave de subida.
Aún no se ha probado una release en un móvil.

## Lo que tiene que hacer Quim antes de publicar

Norday Focus sale a la vez que la versión de Norday Habits con hábitos de
minutos. La guía del despliegue conjunto está en `docs/despliegue.md` del
backend (`habitos-app`); aquí, solo lo que toca a esta app.

1. **GitHub**: hecho el 15-nov-2026 (`jgrabalosa/enfoque_app_mobile`, con
   la rama `wip`).
2. **Firebase**: hecho el 15-nov-2026. En `habitos-app-5a054` están
   `com.norday.enfoque.prueba` (SHA-1 de depuración de la máquina de Quim)
   y `com.norday.enfoque`: depuración, clave de subida y las **tres claves
   de firma de apps de Play** (actual, clásica y poscuántica; la app se
   creó con firma híbrida y Play pide registrar las tres). Si se compila en
   otra máquina, añadir su SHA-1 de depuración. Cada vez que cambien las
   huellas o los clientes OAuth, volver a bajar `google-services.json` a
   `android/app/`.
3. **Google Cloud**: hecho el 15-nov-2026. Un cliente OAuth Android por
   paquete y huella («Norday Focus - …» en Google Auth Platform):
   depuración, Release (clave de subida) y las tres de Play para
   `com.norday.enfoque`, y depuración para `com.norday.enfoque.prueba`.
   Firebase no crea estos clientes al añadir huellas (es la lección de
   Habits): sin el de Play, el login con Google falla en la app de Play
   aunque funcione en una build local. Una release de `prueba` necesitaría
   además su cliente con la clave de subida.
4. **Primer build**: hecho el 15-nov-2026, en debug y con el flavor
   `prueba`. En el móvil ya funcionan el login, Inicio y el enlace de
   entrada desde Habits. Los avisos de gracia y de fin están hechos, pero
   sin probar en el móvil. La release compila (ver «Toolchain de
   Android»); probarla en el móvil va después de desplegar el backend
   `wip-enfoque` en producción, porque el flavor `produccion` solo habla
   con producción.
5. **Tag del core**: hecho el 15-nov-2026. El core va fijado por `v0.55.0` y el `pubspec.lock` está versionado.
6. **Icono, splash y gráficos de Play**: Norday Focus no tiene aún ni icono
   ni símbolo. Hoy lleva el icono por defecto de Flutter y el splash pinta a
   Nori sobre Azul Noche. Cuando los haya, en `store/` y
   `assets/branding/`, con `flutter_launcher_icons` y
   `flutter_native_splash` como en Habits. El icono pequeño de los avisos
   es un vector propio y genérico (`res/drawable/ic_stat_enfoque.xml`, un
   aro con aguja): se puede sustituir por el definitivo con el mismo nombre
   (silueta blanca sobre transparente).
7. **Política de privacidad y URL de borrado de cuenta**: la ficha de Play
   pide las dos. Son las de `norday.app` (`privacidad.html` y
   `eliminar-cuenta.html`, en el backend), ampliadas a Norday Focus en
   `wip-enfoque` el 15-nov-2026: valen en cuanto ese backend esté en
   producción.
8. **Prueba cerrada**: obligatoria. La cuenta de desarrollador es personal
   y de 2026: hacen falta 12 testers apuntados durante 14 días seguidos
   antes de pedir el acceso a Producción. La app existe en Play Console
   desde el 15-nov-2026 («Norday Focus», sin coste, firma de apps
   gestionada por Google).
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
