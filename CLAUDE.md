# Norday Focus — Contexto del proyecto (Flutter / Mobile)

Ruta en la máquina de Quim: `C:\Dev\Norday\enfoque_app_mobile`.

Norday Focus (el dominio se llama **enfoque** en el código y en el backend)
es la tercera app del ecosistema Norday: un temporizador de concentración
con bloqueo suave. El motor genérico **no vive aquí**: está en el paquete
[norday_flutter_core](https://github.com/jgrabalosa/norday_flutter_core),
que esta app consume como dependencia Git, por tag (`ref: vX.Y.Z`). La
fuente de verdad del producto es el diseño de Norday Enfoque (v1, cerrado el
15-nov-2026). Qué hace la app, para quien no la conozca: ver el `README.md`.

## Regla de arquitectura obligatoria: Motor vs Disparadores

- **Motor** = genérico y reutilizable → vive en `norday_flutter_core`. La
  máquina de estados de la sesión (`SesionConcentracion`), su ciclo de vida
  (`MotorSesion`) y la cuenta atrás (`AroCuentaAtras`) son motor: no saben
  de enfoque ni de hábitos.
- **Disparadores** = específico de «enfoque» → vive aquí.

**Ningún widget o servicio genérico debe conocer conceptos de dominio.**
Antes de escribir algo genérico aquí, para: probablemente va en el paquete.

Esta app **no conoce los hábitos**: el backend le da «destinos» (`tipo`,
`id`, `nombre`, minutos de hoy y objetivo) y ella los muestra y los manda. Lo
único que nombra a Norday Habits es el texto «Crea hábitos en Norday Habits»
y el paquete que abre.

### Qué vive en el paquete

Sesión de usuario, preferencias, gamificación, tienda, mascota y
notificaciones (`ApiServiceCore`), el motor de la sesión con bloqueo suave
(`MotorSesion`, `SesionConcentracion`, `FuenteReloj`, `FuentePantalla`,
`AvisosSesion`), `AroCuentaAtras`, los servicios genéricos (celebración,
sonido, idioma, zona, permiso y token de avisos), el tema y las identidades,
los fondos, las pantallas genéricas (login, recuperación, elección de
identidad, tienda, mascota, logros, colección, perfil),
`NordayCoreLocalizations` y los assets de animations, sounds y mascota. La
lista completa, en el `CLAUDE.md` del paquete.

### Qué vive aquí

- `screens/` — `HomeShell` (Inicio, Estadísticas y el menú; y qué se pone
  encima: la sesión o su resultado), `InicioScreen` e `inicio_logica.dart`
  (duraciones y destino pedido, sin widgets), `SesionScreen`,
  `ResultadoScreen`, `EstadisticasScreen` y `estadisticas_logica.dart`
  (fechas de la semana y del mes).
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
  - `canal_sistema.dart` — el canal con `MainActivity.kt`: `RelojSistema`
    (`FuenteReloj`), `PantallaSistema` (`FuentePantalla`),
    `LanzadorSistema` y `EventosSistema` (desbloqueos y enlaces).
  - `avisos_sesion_locales.dart` — `AvisosSesion` con
    `flutter_local_notifications`.
  - `abrir_habits.dart` — «Crea hábitos en Norday Habits».
  - `servicios_enfoque.dart` — `ServiciosEnfoque` y `AmbitoEnfoque`: lo que
    las pantallas necesitan de fuera, inyectable en los tests.
  - `al_volver.dart`, `identidad_al_volver.dart` (copiado de Habits) y
    `crashlytics_service.dart` (copiado de Habits).
- `models/enfoque.dart` — los modelos del contrato, con parseo tolerante.
  `models/enlace_entrada.dart` — el enlace `norday-enfoque://`.
- `l10n/` — `AppLocalizations` (`app_*.arb`), `textos_enfoque.dart` y
  `formatos.dart` (las duraciones y los textos con cifras: «Leer · 20 /
  30 min», «+1 h 30 min a Leer (1 h 30 min / 2 h)»; ver «Duraciones»).
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

No se usan `CatalogosCore.registrarLogrosDeDominio` (Focus no tiene logros
propios en v1), ni `publicarProgresoDia`, ni el cierre del día.

## La sesión, de principio a fin

1. Inicio → `ControladorEnfoque.empezar(duracion, destino)` →
   `MotorSesion.empezar`. `HomeShell` ve la sesión activa y pone encima
   `SesionScreen`.
2. El motor hace el resto: ciclo de vida, gracia, avisos, persistencia y
   recomposición tras matar la app.
3. Cuando la sesión es final, el controlador la recoge:
   - **descartada** (terminar antes de 10 min): no se envía; resultado
     «descartada» y `MotorSesion.cerrar()`.
   - **completada, terminada o perdida**: `peticionDeSesion` monta el
     cuerpo y se mete en la cola con su dueño (el `usuarioId` de
     `datosApp`). Si `encolar` dice que quedó guardada, se cierra en el
     motor en el acto y el envío va después, sin bloquear. Si no se pudo
     guardar, la sesión se queda en el motor y la recogida se reintenta en
     el siguiente `iniciar()` o `enviarPendientes()` (al volver a primer
     plano).
4. `HomeShell` ve el resultado nuevo y sustituye la sesión por
   `ResultadoScreen`, que se actualiza cuando llega la respuesta.

`MotorSesion.iniciar()` se llama en `main()`, antes de `runApp`: el motor
recompone y vigila la sesión aunque la app abra en el login. La recogida
(`ControladorEnfoque.iniciar()`) la hace cada `HomeShell` al montarse.

**Otra cuenta, o ninguna, al acabar**: la sesión se encola con su dueño
igualmente y la cola solo la envía cuando ese usuario vuelva a estar
conectado. Solo una sesión sin dueño guardado (anterior a guardarlo) y sin
nadie conectado se queda en el motor hasta el siguiente login.

### La cola y el contrato de reintento

El contrato es el de `EnfoqueController` del backend:

- **201/200** → enviada; sale de la cola. Un 2xx con un cuerpo que no se
  entiende también cuenta como enviada (reintentar daría el mismo 200).
- **400 y 409** → definitivos: salen de la cola y quedan en
  `noAceptados` (historial local, los 50 últimos) con el `mensaje` del
  backend. No se reintentan nunca.
- **5xx, sin red, timeout, 401, 404, 429…** → se quedan. Reintento
  automático con espera de 30 s × 2^(intentos − 1), hasta 30 min, y además
  en cuanto se fuerza: al arrancar y al volver a primer plano.
- **Siempre el mismo cuerpo con la misma clave**: se guarda la petición al
  encolar y se reenvía tal cual. El backend devuelve el resultado original
  sin sumar ni pagar dos veces.
- Cada entrada lleva su `usuarioId` y **solo se envía con la sesión de ese
  usuario abierta**, comprobado antes de cada envío (también a mitad de
  pasada): si en el mismo móvil entra otra cuenta, no se mandan sesiones
  ajenas con su token.
- **`encolar` devuelve si quedó guardada** (el `bool` de `setString`; si
  escribir lanza, relanza) y deshace la entrada en memoria si no. Si leer la
  cola falla, no se da por cargada y no se escribe nada: el siguiente
  guardado pisaría lo que hubiera. El almacén es inyectable (`AlmacenCola`).
- Una sola pasada a la vez; lo que se pide durante una pasada se hace al
  acabarla.
- **Más de 7 días sin enviar**: al empezar cada pasada, las que empezaron
  hace más de 7 días (de cualquier usuario) salen de la cola y quedan como
  no enviadas por antigüedad (`antigua`, código 0): el backend las
  rechazaría con un 400.

### El reloj del móvil, desfasado

El backend valida el inicio de cada sesión contra su reloj (que no acabe
más de 2 minutos en el futuro, que no empezara hace más de 7 días, que no se
solape) y saca de él el día. Un móvil que va mal de hora daría 400 o el día
equivocado. Por eso (decisión de la revisión del 15-nov-2026):

- `ApiServiceEnfoque` apunta en `DesfaseServidor` la cabecera `Date` de cada
  respuesta del backend: desfase = servidor − móvil, guardado en
  `enfoque_desfase_servidor_ms`.
- El controlador corrige `inicioUtc` **una sola vez, al encolar**, con el
  desfase conocido entonces. Después el cuerpo no cambia nunca: la misma
  clave con otro cuerpo daría 409. Sin desfase conocido, la hora del móvil.
- `Date` va en segundos y llega con la latencia: ±1 s de ruido. Una medida
  solo sustituye a la guardada si se aparta más de 5 s (histéresis), y
  desfases de menos de 5 s no se corrigen. Si no, dos sesiones seguidas
  corregidas con medidas distintas podrían solaparse un segundo (409).
- La duración no se toca: sale del reloj monótono.
- **Límite**: si el desfase cambia de verdad entre dos sesiones seguidas
  (alguien cambia la hora del móvil), esas dos pueden solaparse.

Claves en `SharedPreferences`: `enfoque_cola_envios`,
`enfoque_envios_no_aceptados` y `enfoque_desfase_servidor_ms`. La sesión en curso la guarda el core en
`sesion_concentracion_actual`.

### Logros que paga el hábito

El aporte devuelve los logros que desbloqueó el hábito. Focus no registra los
logros de hábitos y el backend tampoco se los da en el catálogo
(`X-Norday-App: enfoque` los filtra), así que celebrarlos aquí enseñaría el
código crudo. `separarLogros` celebra solo los que `CatalogosCore` sabe
nombrar (los genéricos del core, como `MASCOTA_CRIA`) y de los demás dice
«Tienes N logros nuevos en Norday Habits».

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

## Identidad de marca (aplicar siempre en UI nueva)

- **Nombre**: **Norday Focus**, en todos los idiomas. **Norday** es la marca
  del ecosistema.
- **Símbolo e icono**: todavía no hay. El launcher lleva el icono por
  defecto de Flutter y el splash pinta a Nori sobre Azul Noche. No inventar
  uno ni reutilizar la brújula de Habits.
- **Nori**: dentro del aro de la sesión y en el menú. Si la cara de Norday es
  la brújula o Nori está por decidir; no dar ninguna como decidida.
- **Identidades**: Profundidad, Neotokyo+ y Dulce. Las superficies son
  `SuperficieIdentidad` (nunca un `Card` a mano), el fondo `FondoIdentidad`,
  el aro `AroCuentaAtras`.
- **Paleta, iconos (Lucide), espaciado (`AppSpacing`, rejilla de 4) y escala
  de letra** (roles de `Theme.of(context).textTheme`, nunca `fontSize` a
  mano): como en el resto del ecosistema.

## Idioma, zona y «hoy»

Idioma y zona son preferencias independientes, en el core
(`IdiomaService`, `ZonaService`), como en Habits.

**Hoy es el día del móvil.** Inicio y Estadísticas piden el resumen con la
fecha local del dispositivo (`DateTime.now()`), porque Dart no da la zona
IANA y el día de cada sesión lo calcula el backend con la zona del usuario.
Si la zona del perfil no es la del móvil, cerca de medianoche «hoy» puede
ser el día de al lado.

## Textos

Ninguna pantalla lleva literales. Dos catálogos y dos clases, como en Habits:

- Lo de enfoque → `lib/l10n/app_*.arb`, con `AppLocalizations.of(context)!`.
  `es` es la plantilla; `pt` es portugués europeo («tu», «ecrã»,
  «telemóvel»).
- Lo genérico → los `core_*.arb` del paquete. Se usan directamente las
  claves del core que ya existen (`tiendaTitulo`, `logrosTitulo`,
  `navColeccion`, `perfilTitulo`, `reintentar`, `sesionAvisoSalir`,
  `sesionAviso*`): ninguna clave está duplicada.

Los `app_localizations*.dart` los genera `flutter gen-l10n` y **no** se
versionan. Los textos que manda el backend (`motivoTexto`, `mensaje`) ya
vienen traducidos al idioma del usuario y se enseñan tal cual.

### Duraciones

Una sola regla para todo lo que enseña minutos al usuario (decisión del
15-nov-2026, la misma que Norday Habits): menos de 60, «{m} min»; desde
60, «{h} h» si no sobran minutos y si no «{h} h {m} min». La aplica
`duracionLegible` (`l10n/formatos.dart`, claves `durMinutos`, `durHoras` y
`durHorasMinutos`). Es de la app, no del core. Se guarda y se envía siempre
en minutos.

- **Pasan por ella**: la cifra de minutos de hoy en Inicio, el progreso del
  destino (Inicio y sesión), «Llevas…» al terminar, la cifra grande y el
  aporte del Resultado, los totales de semana y mes, la cifra de encima de
  cada barra y lo que oye el lector en ella, y el historial.
- **Pares** (lo hecho y su objetivo): si los dos son de menos de una hora,
  la unidad va una vez al final, como siempre («Leer · 20 / 30 min»,
  «(30 / 30)», «25 de 25 min · Leer»); si alguno llega a la hora, cada
  cifra con la regla («Leer · 45 min / 1 h 30 min», «1 h 30 min de 2 h ·
  Leer»). Lo deciden `progresoLegible`, `textoAporte` y `textoFilaSesion`.
- **No pasan por ella**: los chips de duración (15/25/45/60), el selector
  de 10 a 120 (`duracionMinutos`, `duracionEtiqueta`) y la cuenta atrás
  `mm:ss` del core. Siguen en minutos.
- **Ninguna etiqueta dice «minutos» junto a una cifra que puede ir en
  horas**: la de Inicio es «Tiempo hoy» (`inicioTiempoHoy`; en «Time
  today», pt «Tempo hoje»). Los textos con «minutos» que quedan van con
  cifras fijas («menos de 10 minutos») o sin cifra.
- Donde el sitio es estrecho (la cifra de Inicio, encima de las barras) el
  texto se encoge con `FittedBox` en vez de cortarse.

## Tocar el paquete

Un cambio en `norday_flutter_core` no llega solo: se mergea y se tagea
allí, se cambia aquí el `ref:` al tag nuevo y se hace
`flutter pub upgrade norday_flutter_core`. Antes de probar, comprobar el
`resolved-ref` del `pubspec.lock`. Para probar una rama del core sin tag,
`pubspec_overrides.yaml` con `path: ../norday_flutter_core`, que no se
commitea (está en `.gitignore`).

**Pendiente con el core 0.55.0**: el `ref:` ya apunta a `v0.55.0`, pero el
tag no existe todavía y el desarrollo va con el override. Por eso
`pubspec.lock` está **temporalmente** en `.gitignore`. Cuando Quim ponga el
tag `v0.55.0` en el core:

1. Borrar `pubspec_overrides.yaml`.
2. `flutter pub upgrade norday_flutter_core`.
3. Comprobar que el `resolved-ref` del `pubspec.lock` es el commit que da
   `git rev-parse v0.55.0^{commit}` en el core.
4. Quitar la línea `pubspec.lock` (y su comentario) del `.gitignore`.
5. `flutter analyze` y `flutter test`, y commitear el lock.

## Variantes: produccion y prueba

- **`--flavor` siempre.** `produccion` es `com.norday.enfoque`, «Norday
  Focus». `prueba` es `com.norday.enfoque.prueba`, «Norday Focus PRUEBA», y va
  contra staging con
  `--dart-define=NORDAY_API_URL=https://staging-api.norday.app/api`.
- **`lib/entorno.dart` para la app al arrancar** si el flavor y la URL no
  cuadran. No se quita ni se salta.
- **El nombre visible sale de `manifestPlaceholders["appLabel"]`** en
  `android/app/build.gradle.kts`, no del manifest.
- **`google-services.json` lleva las dos apps**, en el mismo proyecto de
  Firebase que Habits. No se versiona (`android/.gitignore`).

## Formato del código

Todo el código Dart va formateado con `dart format`. Antes de cada commit que
toque un `.dart`, desde la raíz: `dart format lib test`.

- Sólo `lib` y `test`. Nunca `dart format .`.
- **Después de formatear, `flutter analyze`.** Si el formateador parte un
  `if` sin llaves y salta `curly_braces_in_flow_control_structures`, se
  ponen llaves.
- Un cambio que sólo reformatea va en su propio commit.
- Tras tocar un ARB, `flutter gen-l10n` antes de `flutter analyze`.

## Estilo de trabajo con el usuario

- Un paso a la vez, confirmar que compila antes de seguir.
- Si algo admite varios diseños o no está claro, preguntar antes de
  decidir — no asumir.
- Trabajo en ramas `wip`; nunca en `main`. Quim hace los merges y los tags.

## Decisiones tomadas al construir la app (15-nov-2026)

Lo que el diseño no decía y se resolvió con la opción más conservadora.

- **CRÍTICA — `flutter_local_notifications` por debajo de la 23**
  (`">=22.3.3 <23.0.0"`, decidido en la revisión del 15-nov-2026). La 23
  pide `compileSdk` 37 y AGP 9.1.1; AGP 9.1.1 exige Gradle ≥ 9.3.1 (el
  wrapper está en 9.1.0) y Flutter 3.44.4 no conoce el SDK 37. Con la 22.3.3
  (mínimos: `compileSdk` 35 y AGP 8.11.1) la app usa exactamente el mismo
  toolchain que Habits. La API que usa esta app (`initialize`, `show`,
  `zonedSchedule`, `cancel`, `timeoutAfter`) es la misma en las dos. Subir a
  la 23 es subir antes el toolchain de las dos apps a la vez.
- **CRÍTICA — no compilado.** Ni el Gradle ni `MainActivity.kt` se han
  compilado: se escribieron sin SDK de Android.
- **La sesión se cierra en el motor en cuanto `encolar` confirma que quedó
  guardada**, antes de enviarla (revisión del 15-nov-2026): la cola guarda
  el cuerpo exacto, y esperar al envío bloquearía empezar otra sesión sin
  red.
- **401 no es definitivo**: la sesión espera en la cola al siguiente login.
  Tampoco lo son los 4xx que no son 400 ni 409.
- **Las sesiones llevan su dueño desde que empiezan** (en `datosApp`) y se
  encolan con él aunque al acabar haya otra cuenta; solo se envían con él.
- **Perdida con destino**: se envía con su destino (el backend la guarda con
  el aporte `RECHAZADO`); el resultado no dice nada del hábito.
- **Logros del hábito**: solo se celebran los que el core sabe nombrar; los
  demás se cuentan («en Norday Habits»).
- **Enlace a un destino que no está en la lista**: aviso y «Sin hábito».
- **Hoy es el día del móvil** (ver arriba).
- **El inicio se corrige con el desfase del servidor** una sola vez, al
  encolar (ver «El reloj del móvil, desfasado»).
- **El permiso de avisos se pide una sola vez**, la primera vez que se pulsa
  Empezar, aunque se deniegue.
- **Atrás en la sesión pregunta si rendirse**; no la abandona.
- **Sin icono ni símbolo**: icono por defecto de Flutter, splash con Nori,
  arranque nativo en Azul Noche. Ni `store/` ni `assets/branding/` hasta que
  haya gráficos.
- **Ayudas de la pantalla de Nori** (`ayudaAnimo`, `ayudaXp`): no se pasan.
  Explicar el ánimo o la XP es hablar de hábitos y no está decidido qué
  decir desde Focus.
- **Sin recorrido de bienvenida** propio.

## Lecciones aprendidas

Errores que ya se cometieron una vez. No se vuelven a cometer.

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

### Método de trabajo (vale para los cuatro repos)

- **La primera línea de un prompt se comprueba, no se recuerda.** Este repo
  está en `C:\Dev\Norday\enfoque_app_mobile`, junto a `habitos-app`,
  `habitos_app_mobile` y `norday_flutter_core`; `conocimiento_app_mobile`
  está en `C:\Dev\Conocimiento\`.
- **Un solo agente por repo a la vez.** Todo lo que haga otro agente se
  revisa en el remoto antes de mergear.
- **Las cifras de verificación se cuentan contra el repositorio**, nunca se
  copian del roadmap. Y son cifras exactas, no adjetivos.
- **Un filtro que no encuentra nada no es un resultado.** Ante una salida
  vacía, mirar la fuente completa antes de concluir.
- **Al sustituir un bloque, incluir el comentario de encima.**
- **Mirar dónde se pega cada bloque.** Un bloque para la máquina local,
  lanzado en el VPS, llegó a `git push` y pidió credenciales.
- **`git diff` y `git log` abren paginador**: `git --no-pager`.
- **Antes de `git tag`, `git --no-pager log -1`.**
- **Un tag anotado resuelve a su commit, no a sí mismo**:
  `git rev-parse <tag>^{commit}`.
- **PowerShell 5.1 lee los `.ps1` sin BOM como ANSI**: scripts sin acentos, o
  guardados con BOM.
