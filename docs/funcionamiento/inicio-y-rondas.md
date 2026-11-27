# Inicio, rondas y descanso

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

## Inicio de un solo gesto (17-nov-2026)

Diseño de Focus con Quim (`encargos/focus-diseno.md` del proyecto).

- **El aro de la sesión, ya en Inicio**: el mismo `AroCuentaAtras` (260) con
  Nori (96) que la sesión, lleno y con los minutos de la técnica. Al
  empezar no cambia de sitio.
- **Tres técnicas** (`Tecnica` en `inicio_logica.dart`): Pomodoro (25),
  Profundo (50) y Libre (de 10 a 120, con el selector). La primera vez,
  Pomodoro. Se recuerdan la técnica, las rondas y los minutos de Libre.
- **El destino, en una línea bajo Empezar** («Para: Sin hábito»), que abre
  la lista en una hoja. El enlace desde Habits sigue eligiendo el hábito.
- **Sin las cifras de hoy** (tiempo, sesiones y racha): están en
  Estadísticas.

## Rondas y descanso (17-nov-2026)

- **Pomodoro y Profundo van por rondas**, de 1 a 4, con descanso entre una
  y otra (5 y 10 minutos; después de la última, ninguno). Libre, siempre
  una. Bajo el aro, con más de una ronda: «2 × 25 min, con 5 min de
  descanso · 55 min».
- **Cada ronda es una sesión normal del motor**, con su premio: el core no
  sabe nada de rondas. La ronda va en `datosApp` (`{"ronda": {n, de}}`,
  `rondaDeDatos`), y la sesión y el resultado enseñan «Ronda 1 de 2».
- **`ControladorTanda`** (`services/tanda.dart`) lleva la tanda y la guarda
  en `enfoque_tanda`. Al acabar una ronda, `HomeShell` le pregunta
  (`alAcabar`): si se completó y no era la última, `DescansoScreen`; si no
  (terminada, perdida, rendida o la última), el resultado de siempre y la
  tanda se acaba.
- **El descanso no empieza sola la ronda siguiente**: en el descanso se
  puede salir de la app, y una sesión que empieza con la app fuera se
  perdería en el acto. Avisa (canal `enfoque_descanso`, id fijo 7103,
  `AvisosDescansoLocales`) y la empieza el usuario. Se puede empezar antes
  de que acabe. «Terminar aquí» (y Atrás) dejan la tanda: lo hecho ya
  cuenta.
- **Si se mata la app en el descanso**, al volver `HomeShell` lo abre otra
  vez (sin las líneas del premio, que ya no están). Una tanda que no está en
  descanso y no tiene sesión activa se deja (`limpiarSiHuerfana`).
- **La hora del descanso es la de pared** (`DateTime.now`), no la del reloj
  monótono: es un descanso, no hay nada que proteger.

## El final de la tanda (T-085, 24-nov-2026)

Decisiones 9 y 10 de Quim.

- **La cuenta de las rondas va con la tanda.** `Tanda.hechas` es una lista
  de `RondaHecha` (clave de la sesión, número de ronda, minutos, si cuenta,
  `EnvioResultado` y, enviada, puntos —premio más aporte— y XP). Se guarda
  dentro de `enfoque_tanda`, en `"hechas"`, así que sobrevive a matar la app
  en el descanso. Una tanda guardada antes no lleva `"hechas"` y se lee con
  la lista vacía.
- **Se pone al día sola.** `ControladorTanda` escucha
  `ControladorEnfoque.resultado` (cada cambio de la ronda en curso:
  `enviando` → `enviada`, `pendiente`…) y la cola (`pendientes`): si una
  ronda pendiente se envía después de soltar su resultado (se empezó la
  siguiente antes), `cola.resultadoDe` le pone lo que pagó. `alAcabar`
  también la apunta, por si llega antes que el aviso del resultado.
- **El resumen de la tanda** (`ControladorTanda.resumen`, `ResumenTanda`):
  al acabar la tanda (la última ronda, o cortada al rendirse o terminar),
  la cuenta pasa al resumen, en memoria, hasta que se suelta el resultado o
  empieza otra.
- **El resultado** lo enseña si la sesión es de un resumen con 2 rondas o
  más: «2 rondas · 50 min» (o «1 de 3 rondas · 25 min» si se cortó; cuentan
  las rondas completadas o terminadas con el mínimo, y sus minutos), la
  suma de puntos y XP de las enviadas y, si alguna que cuenta está
  pendiente o enviándose, «Alguna ronda aún no se ha enviado…». Debajo, más
  pequeño, «Ronda 2 de 2» con `LineasResultado(compacta: true)`. Una sesión
  suelta, o una tanda cortada en la primera ronda, se ve como siempre.
- **Nori, vestido, arriba del resultado**, y reacciona al entrar
  (`reaccion`) si la sesión cuenta; perdida o descartada, no.
- **«Otra igual» y «Listo».** `ControladorTanda.ultimaConfiguracion`
  recuerda en memoria con qué se llamó a `empezar` (rondas, minutos,
  descanso y destino). «Otra igual» suelta el resultado, cierra la pantalla
  y llama a `empezar` con eso; si falla, `inicioNoSePudoEmpezar`. Sin
  configuración (una sesión recompuesta tras matar la app), solo «Listo»,
  que hace lo que hacía «Volver».
