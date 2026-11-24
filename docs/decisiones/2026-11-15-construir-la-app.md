# Decisiones tomadas al construir la app

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

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
- **Compilado por primera vez el 15-nov-2026**, en debug y con el flavor
  `prueba`, en la máquina de Quim. En el móvil, contra staging, funcionan el
  login, Inicio y el enlace desde Norday Habits («Empezar sesión» abre Focus
  con el hábito elegido). **Aún sin probar en el móvil**: los avisos de gracia
  y de fin, una build de release (el primer AAB compila desde el
  15-nov-2026, firmado con la clave de subida propia de Focus) y la prueba
  a fondo de la sesión, que hará Quim.
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
- **Ayudas de la pantalla de Nori** (`ayudaAnimo`, `ayudaXp`): se pasan desde
  el 16-nov-2026, cuando el ánimo pasó a juntar las dos apps (antes no se
  pasaban: explicarlo era hablar solo de hábitos).
- **Sin recorrido de bienvenida** propio.
