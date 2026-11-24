# Lecciones: red, Flutter y tests

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

### Red

- **`Response.body` de `http` decodifica en latin1 si falta
  `Content-Type: application/json`.** Un 409 con «sesión» llegaba como
  «sesiÃ³n». Aquí se lee siempre `utf8.decode(r.bodyBytes)` (`cuerpoDe`).
  Encontrado con un test en rojo antes del arreglo.

### Flutter y tests

- **En `testWidgets`, `ApiServiceCore.getUsuarioLocal()` no vuelve nunca**:
  `flutter_secure_storage` no contesta y la pantalla se queda cargando. Por
  eso `HomeShell` pide el usuario a `ServiciosEnfoque.usuarioActual`, que en
  los tests es un falso.
- **`SkeletonCard` del core necesita al menos 66 de alto** (14 de relleno y
  dos barras): con 56 desborda.
- **El fondo de la identidad y Nori se animan sin fin**: nada de
  `pumpAndSettle` en pantallas que los llevan; `pump` con duración.
- **Un `MotorSesion` en un test se desecha al acabar** (`addTearDown`), y la
  sesión activa se termina antes, o quedan temporizadores vivos.
- **El ciclo de vida en tests va paso a paso** (`inactive` → `hidden` →
  `paused` y vuelta por `hidden` → `inactive` → `resumed`):
  `AppLifecycleListener` rechaza saltos como `paused` → `resumed`.
- **En `flutter test` Firebase no está inicializado**: acceder a
  `FirebaseAnalytics.instance` lanza `[core/no-app]`.
- **`MaterialApp` interpola el tema con `AnimatedTheme`**: en tests que
  cambian de identidad, esperar a que acabe.
- **Tras editar un ARB, `flutter analyze` no regenera las traducciones**:
  `flutter gen-l10n` antes.
- **Test en rojo antes del arreglo.** Si el test nuevo pasa contra el código
  sin arreglar, no demuestra nada: parar.

### El reloj

- **Ningún test depende de la fecha de hoy.** Lo que mira el reloj recibe uno
  falso en los tests (`ColaEnvios(ahora: reloj.ahoraUtc, …)`). El
  23-nov-2026, 22 tests empezaron a fallar sin tocar nada: sus sesiones
  empezaban el 16-nov y la cola, que miraba `DateTime.now`, las dio por
  antiguas (más de 7 días) y las tiró (enfoque#9).
