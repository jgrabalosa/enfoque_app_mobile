# La notificación en curso: un servicio en primer plano `specialUse`

_T-090, 27-nov-2026. Lo pidió Quim el 24-nov-2026 (decisión 6): mientras
hay sesión, una notificación fija con el tiempo, la ronda y tocar para
volver._

## Contexto

- Quim quiere la notificación **siempre** que haya sesión.
- Con la pantalla apagada, Android puede congelar la app y la sesión deja
  de contar a su hora (el aviso de `focus/FOCUS.md` §7). Un servicio en
  primer plano lo evita.
- Una notificación `ongoing` sola no evita que congelen la app; la de un
  servicio en primer plano sí. (Desde Android 13 el usuario puede quitar
  las dos deslizando; el servicio sigue igual.)
- `flutter_local_notifications` se queda en la 22.3.3 (ver
  `2026-11-15-construir-la-app.md`), que ya trae
  `AndroidFlutterLocalNotificationsPlugin.startForegroundService` y su
  `ForegroundService`. No hace falta ningún paquete más.
- Desde Android 14 cada servicio en primer plano declara un tipo, con su
  permiso, y Play pide justificarlo en Play Console.

## Decisión

- **El tipo es `specialUse`**, con la propiedad
  `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` explicando el uso (un temporizador de
  concentración que el usuario ha empezado, visible mientras dura). El
  texto va en inglés porque lo lee el equipo de revisión de Play.
- **La notificación**: canal `enfoque_en_curso`, id 7104 (detrás de 7101,
  7102 y 7103), importancia baja (sin sonido, sin vibración y sin asomar
  encima), `ongoing`, `onlyAlertOnce` y el cronómetro de Android hacia atrás
  hasta el fin (`usesChronometer`, `chronometerCountDown`, `when` = fin).
  La cuenta la lleva el sistema: la app no se despierta cada segundo para
  pintarla.
- **Textos**: el título es `appNombre` («Norday Focus») y el texto,
  `sesionRonda` («Ronda 1 de 2») si es una ronda; si no, sin texto. Del
  `.arb` de la app, como los del descanso (los de gracia y fin vienen del
  core porque los genera el motor). **El destino no sale**: se ve con el
  móvil bloqueado. Por eso es pública en la pantalla bloqueada.
- **Dónde**: `AvisoEnCurso` (interfaz, con un falso en los tests) cuelga de
  `ControladorEnfoque`, que ya conoce la ronda (`datosApp`). Escucha
  `MotorSesion.sesion`: la arranca cuando una sesión pasa a activa (empieza o
  se recompone) y la para cuando deja de estarlo (completada, terminada,
  descartada, perdida, o cerrada). El descanso va después de una ronda
  acabada, así que en él está parada. La primera vez, sin sesión activa, la
  para igual por si quedó colgada. `main()` la engancha tras
  `MotorSesion.iniciar()`, para que funcione aunque la app abra en el login.
- **`START_NOT_STICKY` y `stopWithTask="true"`**: si Android mata el proceso,
  no recrea el servicio (sin la app no hay sesión que contar, y el
  `ForegroundService` de la 22.3.3 lee su intent sin mirar si es nulo, que es
  como lo recrea un `START_STICKY`). Quitar la app de Recientes se lleva el
  servicio: la sesión se pierde igual.
- **Si el plugin falla** (Android 13+ sin permiso de avisos, el sistema no
  deja arrancar el servicio…), se apunta en el log y la sesión sigue igual.
  Sin el permiso concedido el servicio arranca, solo que la notificación no
  sale en el cajón.

## Alternativas descartadas

- **`mediaPlayback`**: es para reproducir audio o vídeo. Encajará cuando el
  sonido de la sesión siga con la pantalla apagada (T-091); hoy Play lo
  rechazaría porque no suena nada.
- **`shortService`**: se corta a los 3 minutos; una sesión dura 25 o más.
- **`dataSync`**: no sincroniza nada, y desde Android 15 tiene un límite de
  6 horas al día.
- **Una notificación normal con `ongoing`, sin servicio**: no evita que
  Android congele la app.
- **Colgarla junto a `AvisosSesion`** (que el motor llame a arrancar y
  parar): el motor no sabe de rondas, y sus llamadas no coinciden con «hay
  sesión» (en la gracia cancela el aviso de fin, pero la sesión sigue). Y
  el motor vive en el core, que no se toca.
- **Pintar «Quedan 23:41» en el texto, actualizándolo cada segundo**:
  despierta la app cada segundo, gasta batería y con la pantalla apagada no
  serviría de nada. El cronómetro del sistema hace lo mismo sin la app.

## Consecuencias

- **Antes de publicar**, Play Console pide declarar el servicio en primer
  plano (tipo `specialUse`, para qué sirve y un vídeo corto de cómo se usa).
- **Al aprobar**, hay que compilar la APK de prueba y mirar con la pantalla
  apagada 5 minutos que la sesión sigue contando y que la notificación
  cuenta bien. Aquí no se puede: el servidor no compila Android.
- Cuando llegue el sonido (T-091), el servicio puede necesitar también
  `mediaPlayback` en el manifiesto y en `foregroundServiceTypes`.
- Si el cronómetro llega a cero antes de que la app marque la sesión como
  completada (no debería: el servicio evita que la congelen), Android lo
  enseña en negativo hasta que la app lo para.
