# Estructura de la app y conexión con el core

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

### Qué vive aquí

- `screens/` — `HomeShell` (Inicio, Estadísticas y el menú; y qué se pone
  encima: la sesión, el descanso o el resultado), `InicioScreen` e
  `inicio_logica.dart` (técnicas, rondas, duraciones y destino pedido, sin
  widgets), `SesionScreen`, `DescansoScreen` (`descanso_screen.dart`, el
  descanso entre rondas), `ResultadoScreen`, `EstadisticasScreen` y
  `estadisticas_logica.dart` (fechas de la semana y del mes),
  `ComoFuncionaScreen` (`como_funciona_screen.dart`, «Cómo funciona»: cinco
  apartados desplegables en `SuperficieIdentidad` sobre `FondoIdentidad`; el
  último lleva el botón «Escribir a Norday»). El menú tiene, entre Perfil y
  Cerrar sesión, «Cómo funciona» y «Escribir a Norday»; las dos usan
  `escribirANordayDesdeApp` (en ese fichero): llama a `escribirANorday` del
  core con `hola@norday.app` y el asunto `correoAsunto`, y si devuelve
  `false`, un `SnackBar` (`correoNoHayApp`). El core no exporta
  `escribirANorday` en su barril: se importa
  `package:norday_flutter_core/services/escribir_a_norday.dart`. Los textos
  de los apartados no llevan cifras de puntos (las decide el backend). No se
  importa nada de Habits.
- `services/`:
  - `api_service_enfoque.dart` — `ApiEnfoque` (interfaz) y
    `ApiServiceEnfoque`: `/api/enfoque/destinos`, `sesiones` (POST y
    historial) y `resumen`. Se apoya en la tubería del core
    (`enviar`/`verificar`/`parsear`).
  - `cola_envios.dart` — la cola persistente de sesiones acabadas y el
    historial local de las no aceptadas.
  - `desfase_servidor.dart` — cuánto va el reloj del servidor por delante
    del móvil (cabecera `Date`), para corregir el inicio al encolar.
  - `controlador_enfoque.dart` — junta el motor del core y la cola:
    empieza sesiones con su destino, recoge cada sesión acabada, la encola,
    la envía y la cierra en el motor.
  - `tanda.dart` — `ControladorTanda`: las rondas y el descanso (ver
    «Rondas y descanso»).
  - `mascota_enfoque.dart` — la fase y el ánimo de Nori, del backend, para
    el aro de Inicio, de la sesión y del descanso.
  - `canal_sistema.dart` — el canal con `MainActivity.kt`: `RelojSistema`
    (`FuenteReloj`), `PantallaSistema` (`FuentePantalla`),
    `LanzadorSistema` y `EventosSistema` (desbloqueos y enlaces).
  - `avisos_sesion_locales.dart` — `AvisosSesion` con
    `flutter_local_notifications`.
  - `abrir_habits.dart` — «Crea hábitos en Norday Habits».
  - `servicios_enfoque.dart` — `ServiciosEnfoque` y `AmbitoEnfoque`: lo que
    las pantallas necesitan de fuera, inyectable en los tests.
  - `postal_sesion.dart` — `PostalSesion` (T-086): «Compartir» del resultado
    de una sesión que cuenta. Pinta `TarjetaSesion` (`widgets/`) fuera de
    pantalla en un `OverlayEntry` (`RepaintBoundary` a la izquierda de la
    pantalla), la captura a 1080 × 1350 (pixelRatio 1), cierra la entrada y
    abre el menú con `share_plus` (`^13.3.1`, la misma que Habits) con la
    frase `postalSesionTexto` y, debajo, `enlaceFichaFocus` (la ficha de Play
    de `com.norday.enfoque`, también desde la de prueba: es solo texto). Mide
    `sesion_compartida` (`identidad`, `minutos`) con `AnalyticsCore` solo si
    el menú no se cancela, y nunca lanza (si falla, `false`). Seams de test
    (`menu`, `medir`, `espera`) en el constructor, que `ResultadoScreen`
    recibe como `postal`. Modelo: `postal_cierre.dart` de Habits, sin
    importar nada de allí.
    **La tarjeta** no lleva puntos, XP ni el nombre del hábito (privado):
    fondo de la identidad equipada (`FondoIdentidad`), el aro lleno
    (`AnilloIdentidad`, el dibujo de la sesión) de 640 con Nori vestido de
    420 dentro, la duración (`duracionLegible`; en una tanda, el total, y
    debajo `inicioRondas`) y la marca `postalSesionMarca`. La letra son los
    roles del tema con `textScaler` ×3 fijo (la tarjeta mide 1080 de ancho),
    sin `fontSize` a mano. El botón (`LucideIcons.share2`) sale debajo de
    «Otra igual»/«Listo» solo si `estado.cuenta`.
  - `al_volver.dart`, `identidad_al_volver.dart` (copiado de Habits) y
    `crashlytics_service.dart` (copiado de Habits).
- `models/enfoque.dart` — los modelos del contrato, con parseo tolerante.
  `models/enlace_entrada.dart` — el enlace `norday-enfoque://`.
- `l10n/` — `AppLocalizations` (`app_*.arb`), `textos_enfoque.dart`,
  `logros_enfoque.dart` (los 21 logros de Focus) y `formatos.dart` (las
  duraciones y los textos con cifras: «Leer · 20 / 30 min», «+1 h 30 min a Leer (1 h 30 min / 2 h)»; ver «Duraciones»).
- `widgets/` — `barras_semana.dart` y `barra_navegacion.dart` (copiado tal
  cual de `identidad_ui.dart` de Habits).
- `google_fonts/` — las mismas siete familias que Habits, con sus licencias
  OFL.

### Lo que esta app le enchufa al paquete

La app fija `ApiServiceCore.appId = 'enfoque'` antes de `runApp`. Con eso el
backend filtra los catálogos y guarda el token de avisos como de `enfoque`
(`AppNorday.ENFOQUE` en el backend). Los endpoints de `/api/enfoque` no
llevan `X-Norday-App`: el core solo la pone en los catálogos y en el token, y
el backend saca el usuario del JWT.

1. **`destinoTrasLogin`** (en `home_shell.dart`) — a `LoginScreen` y a
   `PerfilScreen`. No hay recorrido de bienvenida propio: el flag
   `mostrarOnboarding` no cambia nada.
2. **`nordayNavigatorKey`** — en el `MaterialApp`.
3. **`EleccionIdentidadScreen.alElegir`** — a `HomeShell`.
4. **`TextosApp.registrar`** — `registrarTextosEnfoque()` en `main()`:
   nombre «Norday Focus» (igual en los tres idiomas), lema del login,
   actualización obligatoria y borrado de cuenta.
5. **La sesión** — `MotorSesion` con `RelojSistema`, `PantallaSistema` y
   `AvisosSesionLocales`. `MotorSesion.avisarDesbloqueo()` desde el receptor
   nativo de `ACTION_USER_PRESENT`. El destino y el dueño van en `datosApp`
   (`{"destino": {tipo, id, nombre, minutosDia, minutosObjetivo},
   "usuarioId": N}`).
6. **`NotificacionesService`** — el permiso `POST_NOTIFICATIONS` se pide al
   pulsar Empezar la primera vez (`pedirYRegistrar`, sin esperarlo: la
   sesión empieza en el acto; se apunta en `enfoque_permiso_avisos_pedido` y
   no se vuelve a pedir). El token se
   registra al arrancar con sesión y al volver a primer plano, como en Habits.
7. **`SplashGenerico`** — sin `rutaImagen`: pinta a Nori (no hay símbolo
   propio todavía).
8. **El grano de papel** — `envolverConGrano` en el `builder` del
   `MaterialApp`, como en Habits.
9. **`CelebracionService`** — solo para los logros que el core sabe nombrar
   (ver «Logros que paga el hábito»).
10. **Los logros propios de Focus** — `registrarLogrosEnfoque()` en `main()`
    (`l10n/logros_enfoque.dart`) llama a
    `CatalogosCore.registrarLogrosDeDominio` con los 21 de Focus
    (`codigosLogrosEnfoque`, los mismos que siembra el backend con
    `origenApp = enfoque` en `LogrosEnfoqueInitializer`, no en una
    migración). Si cambia uno allí, cambia aquí.
11. **`MascotaScreen.ayudaAnimo` y `ayudaXp`** — desde el menú, con los
    textos de Focus (`mascotaAyudaAnimo`, `mascotaAyudaXp`): el ánimo y la XP
    de Nori salen de las dos apps juntas.
12. **`VersionMinimaService`** — `vigilarAlVolver()` en `main()`; el splash
    pregunta con `hayQueActualizar()` y, si toca, `bloquear()`, que abre
    `ActualizacionObligatoriaScreen` del core (con el texto de
    `TextosApp`).

No se usan `publicarProgresoDia` ni el cierre del día.
