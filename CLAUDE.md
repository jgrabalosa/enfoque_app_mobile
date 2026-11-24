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
`id`, `nombre`, minutos de hoy y objetivo) y ella los muestra y los manda.
Lo que nombra a Norday Habits (`app_*.arb`): «Crea hábitos en Norday Habits»
(`destinoCrearEnHabits`), el aviso de que no se pudo abrir
(`abrirHabitsError`), los logros nuevos «en Norday Habits»
(`resultadoLogrosEnHabits`), las ayudas del ánimo y de la XP de Nori
(`mascotaAyudaAnimo`, `mascotaAyudaXp`) y la descripción del logro con
destino (`logroConDestinoDesc`). Y el paquete que abre: `com.norday.habitos`,
o `com.norday.habitos.prueba` desde la Focus de prueba (`abrir_habits.dart`).

### Qué vive en el paquete

Sesión de usuario, preferencias, gamificación, tienda, mascota y
notificaciones (`ApiServiceCore`), el motor de la sesión con bloqueo suave
(`MotorSesion`, `SesionConcentracion`, `FuenteReloj`, `FuentePantalla`,
`AvisosSesion`), `AroCuentaAtras`, los servicios genéricos (celebración,
sonido, idioma, zona, permiso y token de avisos), el tema y las identidades,
los fondos, las pantallas genéricas (login, recuperación, elección de
identidad, tienda, mascota, logros, colección, perfil y actualización
obligatoria, `ActualizacionObligatoriaScreen`), `VersionMinimaService`,
`NordayCoreLocalizations` y los assets de animations, sounds y mascota. La
lista completa, en el `CLAUDE.md` del paquete.


**Focus sale sola y tiene que funcionar perfectamente sin Norday Habits**
(Quim, 24-nov-2026): es un producto mínimo independiente, con la misma
cuenta, los mismos puntos y el mismo Nori. Más adelante se enlazan las dos
apps (comparten backend y base de datos). Todo lo nuevo se prueba sin Habits
instalada.

## Antes de tocar…, lee…

Lo que solo importa en una parte del código vive en `docs/`. Antes de tocar
esa parte, léelo.

- Antes de tocar `screens/`, `services/`, `models/`, `widgets/` o lo que la
  app enchufa al core (`destinoTrasLogin`, `TextosApp`, logros, ayudas de
  Nori, `VersionMinimaService`…), lee
  `docs/funcionamiento/estructura-de-la-app.md`.
- Antes de tocar la sesión, `ControladorEnfoque`, la cola de envíos
  (`cola_envios.dart`), el desfase del reloj o las claves `enfoque_*`, lee
  `docs/funcionamiento/sesion-y-cola.md`.
- Antes de tocar el resultado, el premio (`Premio`) o los logros que paga el
  hábito (`separarLogros`), lee `docs/funcionamiento/premio-y-logros.md`.
- Antes de tocar `MainActivity.kt`, el canal `com.norday.enfoque/sistema`,
  el enlace `norday-enfoque://` o los avisos locales
  (`flutter_local_notifications`), lee
  `docs/funcionamiento/parte-nativa-y-avisos.md`.
- Antes de tocar `l10n/`, un `.arb`, cualquier texto con minutos u horas
  (`duracionLegible`) o lo que es «hoy», lee
  `docs/funcionamiento/textos-idioma-y-duraciones.md`.
- Antes de tocar Inicio (`inicio_logica.dart`, las técnicas), las rondas o
  el descanso (`tanda.dart`, `DescansoScreen`), lee
  `docs/funcionamiento/inicio-y-rondas.md`.
- Antes de cambiar el `ref:` de `norday_flutter_core`, el `pubspec.lock` o
  probar una rama del core, lee `docs/procedimientos/tocar-el-paquete.md`.
- Antes de tocar flavors, `lib/entorno.dart`, la cinta «PRUEBA»,
  `google-services.json` o `build.gradle.kts`, lee
  `docs/procedimientos/variantes-y-entornos.md`.
- Antes de cambiar una decisión de cómo se construyó la app (la versión de
  `flutter_local_notifications`, qué es definitivo en la cola, el permiso de
  avisos…), lee `docs/decisiones/2026-11-15-construir-la-app.md`.
- Antes de escribir un test, lee `docs/lecciones/flutter-y-tests.md`; antes
  de dar cifras, escribir un prompt o un script de PowerShell, lee
  `docs/lecciones/metodo-de-trabajo.md`.

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


## Textos

Ninguna pantalla lleva literales. Lo de enfoque, en `lib/l10n/app_*.arb`
(`AppLocalizations.of(context)!`; `es` es la plantilla y `pt` es portugués
europeo); lo genérico, en los `core_*.arb` del paquete, sin duplicar claves.
Los `app_localizations*.dart` no se versionan: tras tocar un ARB,
`flutter gen-l10n`. **En pantalla, «puntos»** (en el código y el backend,
`monedas`); Nori es chico. Las duraciones, siempre con `duracionLegible`.

## Tocar el paquete y compilar

- **Core fijado por `v0.62.0`** (`resolved-ref` en el `pubspec.lock`, que se
  versiona). Cambiarlo es un procedimiento:
  `docs/procedimientos/tocar-el-paquete.md`. `pubspec_overrides.yaml` (rama
  del core sin tag) no se commitea.
- **`--flavor` siempre.** `produccion` es `com.norday.enfoque`; `prueba` es
  `com.norday.enfoque.prueba`, «Norday Focus PRUEBA», con cinta «PRUEBA» y
  contra staging (`--dart-define=NORDAY_API_URL=https://staging-api.norday.app/api`).
- **`lib/entorno.dart` para la app al arrancar** si el flavor y la URL no
  cuadran. No se quita ni se salta.
- **La de prueba nunca abre Google Play** (`AperturaHabits.faltaPrueba`).
- **`flutter_local_notifications` por debajo de la 23** (`">=22.3.3 <23.0.0"`):
  subirla es subir antes el toolchain de las dos apps.
- El servidor del robot no compila Android: aquí se prueba con `analyze` y
  `test`; la APK la compila Quim.

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
- **Desde el 24-nov-2026 hay `main`**, la rama por defecto: todo entra por
  PR (Claude en `wip-<tema>`, el robot en `robot/T-…`), y a `main` solo con
  el sí de Quim. `wip` queda retirada.
- **`CHANGELOG.md`**: lo que nota el usuario va en «Sin publicar», al final
  del fichero (como Habits). Al publicar, Quim la renombra con la versión.

## Git

- **`git diff` y `git log` abren paginador**: `git --no-pager`.
- **Antes de `git tag`, `git --no-pager log -1`.** Un tag anotado resuelve a
  su commit: `git rev-parse <tag>^{commit}`.

## Lecciones aprendidas

Errores que ya se cometieron una vez. No se vuelven a cometer. Las de red,
Flutter y tests, en `docs/lecciones/flutter-y-tests.md`; las de método, en
`docs/lecciones/metodo-de-trabajo.md`. Las que valen en cada sesión:

- **Test en rojo antes del arreglo.** Si el test nuevo pasa contra el código
  sin arreglar, no demuestra nada: parar.
- **Ningún test depende de la fecha de hoy.** Lo que mira el reloj recibe uno
  falso en los tests (la cola, `ahora: reloj.ahoraUtc`): el 23-nov-2026, 22
  tests empezaron a fallar solos porque sus sesiones del 16-nov pasaron a
  tener más de 7 días.
- **El fondo de la identidad y Nori se animan sin fin**: nada de
  `pumpAndSettle` en pantallas que los llevan; `pump` con duración.
- **Las cifras de verificación se cuentan contra el repositorio**, nunca se
  copian del roadmap. Cifras exactas, no adjetivos.
- **Un filtro que no encuentra nada no es un resultado.** Ante una salida
  vacía, mirar la fuente completa antes de concluir.
